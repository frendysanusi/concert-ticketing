# Product requirements: Concert Ticketing

Status: proposed implementation baseline  
Date: 2026-10-22  
Related: [Technical plan](TECHNICAL_PLAN.md)

## 1. Product and purpose

Concert Ticketing lets customers reserve assigned seats, pay through hosted checkout, receive tickets, and enter a concert. Staff can manage sales, investigate bookings, process refunds, and validate admission.

The project will demonstrate production engineering through implemented business rules, operational tooling, measured capacity, and documented recovery exercises. A working checkout demo alone does not satisfy the release criteria.

Initial deployment uses Stripe Sandbox and simulated email delivery. Real-money launch is a separate release gate involving merchant eligibility, provider configuration, customer support, privacy, refund policy, and operational staffing.

## 2. Users and responsibilities

| User | Needs |
| --- | --- |
| Customer | Understand prices and availability, reserve seats, pay, retrieve tickets, and see refund status |
| Event operator | Configure performances, inventory, sales windows, and prices; pause sales |
| Support agent | Find bookings, explain payment state, resend delivery, and initiate permitted refunds |
| Entry staff | Validate tickets quickly and see a clear already-used or invalid result |
| System operator | Detect failures, reconcile payments, recover jobs, deploy safely, and restore data |

Staff permissions are separate. Entry staff cannot access payment details or initiate refunds.

## 3. First-release scope

Included:

- Multiple concerts and performances, each with an assigned-seat inventory.
- A seeded venue layout and staff tooling to configure performances, sales windows, and integer-minor-unit prices.
- One configured currency per performance and one supported currency per initial deployment.
- Authenticated checkout, purchase limits, all-or-nothing seat holds, and a server-controlled countdown.
- Stripe-hosted Checkout in a sandbox, initially restricted to card payments with automatic capture.
- Payment verification, reconciliation, complete-order refunds, and explicit late-payment handling.
- Ticket issuance, customer ticket retrieval, email delivery attempts, and online entry scanning.
- Staff booking investigation, sales pause, audited refund requests, failed-work inspection, and controlled replay.
- Deployment automation, telemetry, failure exercises, and backup restoration.

Deferred:

- General admission, partial-order refunds, ticket resale/transfers, multiple currencies, discounts, and dynamic pricing.
- Organizer payouts, marketplace accounting, offline ticket scanning, and active-active multi-region writes.
- Automated waitlists, a public waiting room, and bulk concert cancellation until core capacity and recovery are proven.

## 4. Product rules

| ID | Rule |
| --- | --- |
| BR-01 | A seat may have only one current owner for a performance: an active hold or confirmed booking. |
| BR-02 | A request for multiple seats reserves all requested seats or none. |
| BR-03 | A hold lasts five minutes from the database-recorded reservation time. Reloading or retrying does not extend it. |
| BR-04 | Allow at most four seats per reservation, four confirmed seats per account per performance, and one active hold per account per performance. These are initial configurable limits. |
| BR-05 | The server snapshots the final price breakdown and currency before payment. Client-supplied prices are ignored. |
| BR-06 | A successful redirect from checkout is not payment proof. Confirmation requires verified provider payment state and matching identifiers, amount, and currency. |
| BR-07 | Payment confirmation must obtain an eligible, unexpired hold in a database transaction. At the expiration boundary, database time and serialized transitions decide the outcome. |
| BR-08 | If successful payment is processed after the hold expires or is cancelled, do not reacquire seats. Record a refund obligation. Explain that payment succeeded but the reservation could not be completed. |
| BR-09 | Every verified successful charge must eventually have either a confirmed booking or a tracked refund obligation. Any additional successful charge for an already-paid booking creates a refund obligation. |
| BR-10 | Repeated checkout requests, provider callbacks, messages, and staff retries must not duplicate financial operations, booking confirmation, or ticket issuance. |
| BR-11 | One active ticket exists per confirmed booking seat. Online admission succeeds once per ticket. |
| BR-12 | For a full-order refund, void tickets transactionally when the request is accepted. Keep seats unavailable pending provider resolution; release them after a successful refund only when sales rules permit. Used tickets cannot enter the normal refund flow. |
| BR-13 | Sales pause stops new holds and new payment-session requests. Existing checkout sessions may finish; verified callbacks, refunds, and reconciliation continue. |
| BR-14 | Paused or closed sales do not extend holds. A customer may cancel an unpaid hold. Customer-requested paid refunds go through support in the first release. |

The five-minute business deadline is independent of Stripe Checkout's supported expiration settings. The system must request provider-session expiration after local expiry and still handle payments that race with that request.

The initial price model has no dynamically calculated taxes or checkout surcharges. All required customer-facing amounts must be in the server-owned price snapshot. Tax handling for a live market remains a launch decision.

## 5. Customer journeys and requirements

### FR-01: Discover a performance

Show venue, start time with timezone, sale window, currency, price breakdown, and seat availability. A displayed available seat is an estimate until the hold succeeds. Show explicit sold-out and sales-paused states.

### FR-02: Reserve seats

Require authentication, enforce limits, validate that every seat belongs to the performance, and create an atomic hold. Return a stable reservation identifier, server time, expiration time, and final amount. Concurrent selection conflicts must explain that the seats are no longer available without exposing another customer's information.

Use idempotency keys for reservation and payment creation. An identical retry returns the existing operation; reuse with different inputs returns a conflict.

### FR-03: Pay

Create or recover one eligible checkout attempt and redirect to hosted checkout. After return, show the application's booking status. Distinguish processing, confirmed, expired, payment failed, and refund pending. Refreshing or closing the browser must not interrupt server-side processing.

After a payment request timeout, show a processing state until reconciliation establishes whether a session or charge exists. Do not invite an unverified duplicate payment.

### FR-04: Receive and retrieve tickets

Issue tickets after confirmation. Display tickets in the authenticated booking page independently of email success. Email delivery failure must not undo the booking or create new tickets. QR credentials must not contain customer or payment information.

### FR-05: Expiration, cancellation, and refunds

Show the original hold deadline, release expired seats, and prevent payment creation against an expired hold. If provider payment arrives too late, show refund pending and a support reference. A refund becomes complete only after provider verification; failed refunds remain visible to staff.

### FR-06: Admission

Authorized staff scan a credential against the correct performance. Return admitted, already used, invalid, voided, or wrong performance. Concurrent scans must produce one successful admission. If the service is unavailable, show an unavailable result; offline admission is outside release scope.

### FR-07: Support and operations

Staff can search by booking ID or provider reference, inspect a timestamped transition history, resend existing tickets, request a full refund, and see unresolved financial cases. Privileged actions require a reason and an audit record. Failed-message payloads containing sensitive data are restricted.

## 6. Nonfunctional targets

These are engineering targets to validate on a documented environment, not existing service promises.

| Area | Initial target and measurement |
| --- | --- |
| Booking availability | 99.9% monthly for valid requests, including booking writes; conflicts and deliberate admission limits are tracked separately from unexpected errors |
| Reservation latency | p95 below 500 ms at 100 reservation requests/second for 15 minutes, excluding external payment calls; report success/conflict/error mix |
| Contention correctness | 2,000 concurrent attempts against 100 seats, with zero overlapping owners and atomic multi-seat outcomes |
| Confirmation processing | 99% of eligible verified successful payments become confirmed within 10 seconds of durable callback receipt under normal operation |
| Ticket availability | 99% of confirmed bookings have retrievable tickets within 30 seconds under normal operation |
| Expiration | Expired holds are normally released within 10 seconds; authoritative checks reject expired holds immediately |
| Payment recovery | Poll unresolved attempts at least every minute while within provider limits; alert when unresolved for 10 minutes |
| Refund operations | Submit refund obligations within five minutes when dependencies are healthy; track provider completion separately |
| Broker outage recovery | After a 10-minute outage at the stated workload, drain the backlog within 20 minutes without missing committed work or duplicating durable business effects |
| Disaster recovery | Target database RPO at most five minutes and RTO at most 60 minutes, demonstrated by restoration and reconciliation |
| Accessibility | Keyboard-operable seat selection, visible focus, labelled states, and availability conveyed beyond color; target WCAG 2.2 AA for core journeys |

Availability measurement must include customer-visible timeouts and dependency failures. Expected sold-out conflicts are not evidence of booking capacity. Load reports must identify hardware, dataset, versions, traffic distribution, and whether failures were injected.

## 7. Release acceptance scenarios

| ID | Scenario | Required evidence |
| --- | --- | --- |
| AC-01 | Many customers request the same seats | Zero overselling and no partial group reservations |
| AC-02 | Retry identical requests and change a reused idempotency key | Same result for identical input; conflict for changed input |
| AC-03 | Duplicate or reorder provider events | Guarded state transitions; no duplicate active tickets or refund operations |
| AC-04 | Lose a successful provider response or omit a callback | Reconciliation finds the outcome without another charge |
| AC-05 | Race payment success with expiration or cancellation | One serialized decision; expired/cancelled booking produces a tracked refund obligation |
| AC-06 | Kill a worker after its database commit and before acknowledgement | Redelivery preserves committed business state |
| AC-07 | Stop RabbitMQ during reservations and callbacks | Work persists in PostgreSQL; recovery processes the backlog within the measured target |
| AC-08 | Stop notification delivery | Confirmed bookings and customer ticket retrieval remain available |
| AC-09 | Scan a ticket concurrently or after a refund request | Exactly one first admission; voided ticket cannot enter |
| AC-10 | Restart expiration and reconciliation jobs midway | Jobs resume safely and all eligible records are revisited |
| AC-11 | Deploy during checkout and retry old messages | Backward-compatible contracts, graceful shutdown, no abandoned committed work |
| AC-12 | Restore PostgreSQL into a clean environment | Meet measured RPO/RTO; reconcile provider payments and reconstruct pending effects |
| AC-13 | Attempt unauthorized booking access and staff actions | Ownership and role checks reject access and preserve audit evidence |

## 8. Delivery stages

1. **Booking foundation:** identity integration, catalog, seat holds, price snapshots, database constraints, expiration, concurrency tests.
2. **Reliable payments:** Stripe Sandbox, simulator, webhook inbox, transactional outbox, RabbitMQ processing, reconciliation, and refunds.
3. **Tickets and operations:** issuance, retrieval, notifications, entry scanning, staff console, failure inspection and replay.
4. **Release hardening:** load and failure exercises, dashboards and alerts, deployment compatibility, backup restoration, and runbooks.
5. **Advanced features:** waiting room, automated waitlist, and resumable concert cancellation after the earlier gates pass.

## 9. Risks and decisions before implementation or launch

- Validate Stripe sandbox access first. Live merchant eligibility, including Indonesia's current availability, is separate from sandbox access.
- Verify Checkout expiration, card payment states, refunds, and webhook behavior against the pinned API version before payment implementation.
- A strict five-minute hold can refund a customer whose successful payment notification was delayed. This is an intentional first-release policy; measure its frequency and explain it in checkout.
- Account-based purchase limits do not prevent determined users from creating several accounts. Stronger anti-abuse controls require a separate threat and fairness review.
- Cloud provider, budget, region, identity provider, email provider, retention periods, and live customer support coverage remain deployment decisions.
- Freeze prices and seat layout for a performance once sales begin. Later editing needs explicit migration and customer-impact rules.
- Offline gate access, venue connectivity contingencies, and chargeback handling must be resolved before real event operation.

## 10. Definition of done

The release includes functioning customer and staff journeys; automated correctness and security tests; a reproducible deployment; measured load and recovery reports; actionable alerts; audited repair tools; a successful backup restore; and runbooks for payments, refunds, broker failure, database recovery, and compromised ticket credentials.

Open launch decisions must be recorded with owners. Passing sandbox exercises does not authorize a live-money or real-venue launch.
