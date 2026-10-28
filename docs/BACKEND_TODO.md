# Backend TODO by planned PR and commit

Status: PR-01 commit 1 implemented; remaining work not started

Baseline: [PRD](PRD.md) and [technical plan](TECHNICAL_PLAN.md)

## Workflow

- PR labels below are planning IDs, not GitHub issue/PR numbers. Branch names and commit subjects are proposals; no branches, commits, or PRs have been created by this document.
- Create a fresh feature branch from updated `main` once its prerequisites merge. Keep each PR focused on the stated outcome; split oversized changes while preserving task IDs and dependencies.
- Commit in the listed order. Each commit includes its relevant tests, migrations, contract updates, and documentation. A final verification commit adds cross-cutting cases; it does not defer all tests until the end.
- Keep commits buildable. Introduce schemas and reusable adapter methods only as their consumers need them; a broad task may span its planned commits without adding unused scaffolding.
- Use the PR description for resulting behavior, design rationale, validation evidence, and limitations. Add commit bodies for migrations, security fixes, or non-obvious decisions; the subjects below are starting points.
- Self-review the complete diff, pass the gate, then squash merge using the PR title and description. Do not configure required self-approval for this solo workflow.
- Check a task only after its implementation and relevant validation are complete. Close the PR only after its full acceptance gate is met. All 106 original task IDs are preserved once below.
- Track a documented decision or spike as completed only when its evidence exists. A runtime feature flag must prevent partially integrated payment flows from becoming customer-accessible.

## PR sequence

PR-01 through PR-23 deliver the core backend. PR-24 through PR-27 are optional advanced work after the core release. The milestone column refers to the technical plan. Resolve independent prerequisites early, but merge dependent branches against updated `main`.

| Planned PR | Outcome | Requires | Milestone |
| --- | --- | --- | --- |
| PR-01 | Bootstrap backend development | None | 0 |
| PR-02 | Add HTTP and database runtime | PR-01 | 0 |
| PR-03 | Add identity and staff authorization | PR-02 | 1 |
| PR-04 | Verify Stripe sandbox behavior | PR-01 | 0 |
| PR-05 | Add performance catalog and sales controls | PR-03 | 1 |
| PR-06 | Reserve seats atomically | PR-05 | 1 |
| PR-07 | Expire and cancel holds safely | PR-06 | 1 |
| PR-08 | Publish committed events through an outbox | PR-07 | 2 |
| PR-09 | Recover consumers and schedule retries | PR-08 | 2 |
| PR-10 | Add deterministic payment simulator | PR-04, PR-09 | 2 |
| PR-11 | Create and recover Stripe checkout sessions | PR-10 | 2 |
| PR-12 | Process verified payments and late charges | PR-11 | 2 |
| PR-13 | Reconcile payments and execute refunds | PR-12 | 2 |
| PR-14 | Issue and retrieve tickets safely | PR-13 | 3 |
| PR-15 | Deliver existing tickets by email | PR-14 | 3 |
| PR-16 | Coordinate admission with support refunds | PR-14, PR-15 | 3 |
| PR-17 | Expose staff investigation and safe repair | PR-15, PR-16 | 3 |
| PR-18 | Instrument backend workflows | PR-17 | 4 |
| PR-19 | Bound overload and protect retained data | PR-18 | 4 |
| PR-20 | Add and exercise operational alerts | PR-19 | 4 |
| PR-21 | Deploy independent backend process roles | PR-20 | 4 |
| PR-22 | Measure backend load and failure recovery | PR-21 | 4 |
| PR-23 | Prove disaster recovery and release readiness | PR-22 | 4 |
| PR-24 | Design capacity-based waiting-room admission | PR-23 | 5 |
| PR-25 | Offer released seats to the waitlist | PR-23 | 5 |
| PR-26 | Cancel performances with resumable refunds | PR-23 | 5 |
| PR-27 | Tune scaling within downstream budgets | PR-23 | 5 |

## PR-01: Bootstrap backend development

Branch: `chore/backend-bootstrap`  
Requires: None  
Technical-plan milestone: 0

### Commit 1

```text
build: bootstrap Go process roles
```

- [x] B00.1: Initialize `backend/go.mod`, pin a supported Go toolchain, and create executable entry points for API, worker, maintenance, and payment simulator.
- [x] B00.2: Establish module boundaries for catalog, booking, payment, ticketing, notification, and operations; add shared infrastructure packages only as needed.

### Commit 2

```text
build: add local development tools
```

- [ ] B00.3: Add reproducible commands for build, run, formatting, checks, migrations, SQL generation, and tests. Document required tools and pin their versions.
- [ ] B00.4: Add a core Docker Compose profile with PostgreSQL, RabbitMQ, local mail catcher, and the selected local identity setup; provide a secret-free environment example.

### Commit 3

```text
ci: add backend checks
```

- [ ] B00.7: Add Go CI checks, integration-test dependency startup, vulnerability checks, and generated-code drift checks. Run the race detector for concurrency-sensitive packages as they are introduced.

Acceptance gate: A clean checkout builds the process roles, starts core dependencies, and runs CI smoke checks. Add richer checks as features land.

## PR-02: Add HTTP and database runtime

Branch: `feat/backend-runtime`  
Requires: PR-01  
Technical-plan milestone: 0

### Commit 1

```text
feat(runtime): add bounded HTTP lifecycle
```

- [ ] B01.1: Implement validated configuration, structured `slog` output, signal handling, request deadlines, and graceful shutdown for each process role.
- [ ] B01.3: Add HTTP middleware for correlation, panic recovery, bounded request bodies, safe errors, access logging, and CSRF protection for cookie-authenticated mutations.
- [ ] B01.4: Implement role-specific liveness/readiness endpoints; keep API liveness independent of broker availability. Define shutdown behavior for in-flight work.

### Commit 2

```text
build(db): add migrations and typed SQL
```

- [ ] B01.2: Configure `pgxpool`, explicit transaction handling, SQL timeouts, and Goose migrations. Add `sqlc` generation inside owning modules.
- [ ] B01.9: Add Testcontainers fixtures for PostgreSQL and RabbitMQ with isolated state, real migrations, and reliable cleanup.

### Commit 3

```text
docs(api): define backend contracts
```

- [ ] B00.8: Create initial OpenAPI and event-schema files; define the common error shape, status codes, correlation IDs, pagination conventions, and idempotency-key contract.

Acceptance gate: Start and stop the API cleanly, migrate an empty PostgreSQL database, and run real-dependency smoke tests. CSRF middleware is wired to authenticated sessions in PR-03.

## PR-03: Add identity and staff authorization

Branch: `feat/identity`  
Requires: PR-02  
Technical-plan milestone: 1

### Commit 1

```text
docs(auth): select OIDC provider
```

- [ ] B00.5: Select an OIDC provider and record local/deployed configuration, staff MFA support, and integration assumptions in an architecture decision.

### Commit 2

```text
feat(auth): add OIDC and server sessions
```

- [ ] B01.5: Implement OIDC login/callback/logout with state, nonce, PKCE, issuer/audience validation, and stable issuer/subject mapping.
- [ ] B01.6: Add PostgreSQL-backed opaque sessions with hashed tokens, expiration, rotation, revocation, and Secure/HttpOnly/SameSite cookie configuration.

### Commit 3

```text
feat(auth): enforce roles and audit actions
```

- [ ] B01.7: Implement ownership checks and distinct operator, support, entry-staff, and system-operator permissions. Enforce staff MFA through the identity policy.
- [ ] B01.8: Add an audit-writing path for privileged actions with actor, target, reason, timestamp, and safe change references.
- [ ] B01.10: Verify authentication failures, session revocation, CSRF rejection, cross-customer access denial, and staff-role separation. Trace to AC-13.

Acceptance gate: Verify login/logout, session rotation/revocation, CSRF, ownership denial, staff MFA policy, and role separation. AC-13.

## PR-04: Verify Stripe sandbox behavior

Branch: `docs/stripe-spike`  
Requires: PR-01  
Technical-plan milestone: 0

### Commit 1

```text
docs(payment): verify sandbox checkout
```

- [ ] B00.6: Verify Stripe Sandbox access, chosen currency, hosted card checkout, status retrieval, webhook forwarding, refunds, and session expiration behavior. Pin the API and SDK versions and document the five-minute hold integration.

Acceptance gate: Record reproducible sandbox evidence for checkout, currency, signed callbacks, expiration, refunds, and API version. No application checkout is enabled by this spike.

## PR-05: Add performance catalog and sales controls

Branch: `feat/performance-catalog`  
Requires: PR-03  
Technical-plan milestone: 1

### Commit 1

```text
feat(catalog): add inventory and seed data
```

- [ ] B02.1: Add concert, performance, venue-seat, and performance-seat schema with keys, ownership checks, prices, currency, timezone, sales window, and pause state.
- [ ] B02.2: Add repeatable development seed data with multiple performances, price sections, and a realistic assigned-seat layout.

### Commit 2

```text
feat(catalog): expose sales and seat APIs
```

- [ ] B02.3: Implement performance listing and seat-availability APIs with pagination/size limits and server-time metadata.
- [ ] B02.4: Add authorized performance configuration and sales-pause operations. Freeze seat layout and prices once sales begin; audit changes.

Acceptance gate: Browse seeded performances and seats; verify permissions, sale windows, pause behavior, and post-sale price/layout immutability.

## PR-06: Reserve seats atomically

Branch: `feat/seat-reservations`  
Requires: PR-05  
Technical-plan milestone: 1

### Commit 1

```text
feat(booking): add holds and request keys
```

- [ ] B02.5: Add booking, booking-seat, per-account quota coordination, transition history, and request-idempotency schema.
- [ ] B02.6: Implement scoped idempotency keys, canonical request hashes, concurrent duplicate coordination, stored result references, and changed-input rejection.

### Commit 2

```text
feat(booking): reserve seats atomically
```

- [ ] B02.7: Define and document the global lock order shared by reservation, confirmation, expiry, cancellation, refund, and admission. Validate bounded deadlock retry behavior.
- [ ] B02.8: Implement atomic multi-seat reservation with server-owned price snapshots, database-time five-minute expiry, current ownership validation, and all-or-nothing rollback.
- [ ] B02.9: Enforce at most four seats per reservation, four confirmed seats per account/performance, and one active hold per account/performance. Include held seats when checking remaining purchase capacity.

### Commit 3

```text
feat(booking): expose owned booking status
```

- [ ] B02.10: Implement owned-booking retrieval with explicit booking/payment state, amount, server time, and the unchanged original deadline.

Acceptance gate: Real PostgreSQL tests demonstrate atomic groups, purchase limits, stable idempotent results, and no overlapping ownership. Include feature tests in these commits; AC-01, AC-02, AC-13. Expiry/reclamation races are completed in PR-07.

## PR-07: Expire and cancel holds safely

Branch: `feat/hold-expiration`  
Requires: PR-06  
Technical-plan milestone: 1

### Commit 1

```text
feat(booking): expire and reclaim holds
```

- [ ] B02.11: Implement unpaid cancellation and bounded expiry batches. Release only seats still owned by the affected booking.
- [ ] B02.12: Handle expired seat owners during a new reservation using the common lock order; re-read ownership after acquiring the complete lock set.

### Commit 2

```text
test(booking): verify reservation races
```

- [ ] B02.13: Verify duplicate seats, wrong-performance seats, sale-window boundaries, pause races, quota races, cancellation races, and expiry after lock waits.
- [ ] B02.14: Run real PostgreSQL contention tests for identical seats, overlapping groups, and retries. Assert no overselling or partial groups and unchanged deadlines on retries. Trace to AC-01, AC-02, AC-10, and AC-13.

Acceptance gate: Verify cancellation, sweeper restart, expired-owner reclamation, post-lock deadline checks, and all seat/quota/pause races. AC-01, AC-02, AC-10, AC-13.

## PR-08: Publish committed events through an outbox

Branch: `feat/outbox-publisher`  
Requires: PR-07  
Technical-plan milestone: 2

### Commit 1

```text
feat(events): persist transactional outbox
```

- [ ] B03.1: Add outbox, consumer-inbox, and failed-work schema, including stable IDs, scheduled availability, claim leases, attempts, and indexes for due work.
- [ ] B03.2: Insert booking events in the same transactions as their state changes; define versioned event envelopes and minimal payloads.

### Commit 2

```text
feat(mq): publish confirmed routed events
```

- [ ] B03.3: Declare durable events/tasks exchanges, queues, bindings, and dead-letter policies from version-controlled configuration. Keep topology bounded by consumer role.
- [ ] B03.4: Implement concurrent outbox claiming with expiring leases and publication outside database locks.
- [ ] B03.5: Implement persistent publishing, publisher confirms, mandatory returns, negative acknowledgements, and uncertain-publication recovery. Mark published only after acceptance and route checks.

Acceptance gate: Verify committed booking events persist through broker loss, claims recover after lease expiry, and returned/uncertain publications remain retryable. Provision initial bound routes before marking events published. AC-07.

## PR-09: Recover consumers and schedule retries

Branch: `feat/message-recovery`  
Requires: PR-08  
Technical-plan milestone: 2

### Commit 1

```text
feat(mq): add idempotent worker processing
```

- [ ] B03.6: Implement manual-ack consumers, configurable prefetch/concurrency, atomic inbox deduplication with business effects, and graceful intake shutdown.
- [ ] B03.7: Implement durable scheduled retries with exponential backoff/jitter and bounded attempts. Persist retry/quarantine outcomes before acknowledging the original delivery.

### Commit 2

```text
feat(mq): recover connections and queues
```

- [ ] B03.8: Configure connection/channel recovery, heartbeat, topology recovery, consumer registration, and recovery of interrupted confirms using the pinned client's supported features.
- [ ] B03.9: Configure quorum queues in the resilience profile, queue bounds, overflow rejection, delivery limits, and explicit at-least-once dead-letter transfer where required.

### Commit 3

```text
test(mq): verify publish and worker crashes
```

- [ ] B03.10: Verify worker termination after commit/before acknowledgement, publisher termination after broker acceptance/before outbox update, unroutable confirmed messages, lease expiry, and broker reconnect. Trace to AC-06 and AC-07.

Acceptance gate: Verify durable retry/quarantine, quorum policies, reconnection, mandatory returns, and crash boundaries around database commit and acknowledgement. AC-06, AC-07.

## PR-10: Add deterministic payment simulator

Branch: `feat/payment-simulator`  
Requires: PR-04, PR-09  
Technical-plan milestone: 2

### Commit 1

```text
feat(payment): add fault-driven simulator
```

- [ ] B04.12: Implement the simulator's matching provider interface and signed events, including duplicate, reordered, missing, delayed, and timeout-after-accept outcomes.

Acceptance gate: Demonstrate create/retrieve/expire/refund and signed-event fixtures for duplicate, reordered, missing, delayed, and timeout-after-accept outcomes. Define the narrow shared adapter contract here; complete the Stripe implementation in PR-11.

## PR-11: Create and recover Stripe checkout sessions

Branch: `feat/stripe-checkout`  
Requires: PR-10  
Technical-plan milestone: 2

### Commit 1

```text
feat(payment): add Stripe payment attempts
```

- [ ] B04.1: Add payment-attempt schema with stable operation keys, provider identifiers, request parameters, amount/currency, state, and reconciliation scheduling.
- [ ] B04.2: Implement a narrow payment-provider interface and Stripe adapter for create/retrieve/expire checkout, verify events, and submit/retrieve refunds.

### Commit 2

```text
feat(payment): create idempotent checkout
```

- [ ] B04.3: Persist attempts before provider calls; implement create/recover checkout using stable provider idempotency keys without holding inventory locks.
- [ ] B04.4: Validate booking ownership, sale state, hold eligibility, and useful remaining time before checkout. Recheck after provider response; expire sessions created too late.
- [ ] B04.5: Use server-owned line items and metadata; restrict checkout to supported card payments and automatic capture. Validate all provider amount/currency/identity facts before confirmation.

### Commit 3

```text
feat(payment): recover uncertain checkout
```

- [ ] B04.10: Handle timeout-after-accept as unresolved, not failed. Block unsafe new payment attempts while the existing outcome is unknown.
- [ ] B04.11: Queue provider-session expiration after local expiry/cancellation; tolerate already-completed sessions and failed expiration calls.

Acceptance gate: Verify persisted attempts, supported provider deadlines, price integrity, timeout recovery, and post-response hold checks against simulator and Stripe Sandbox. Keep the route disabled outside integration environments until PR-13 provides callback/refund recovery. AC-02, AC-04, AC-05.

## PR-12: Process verified payments and late charges

Branch: `feat/payment-confirmation`  
Requires: PR-11  
Technical-plan milestone: 2

### Commit 1

```text
feat(payment): persist verified callbacks
```

- [ ] B04.6: Add the signed webhook endpoint and webhook-inbox schema. Verify the bounded original body; commit the event and processing task before returning success. Treat duplicates safely.
- [ ] B04.7: Process events idempotently and tolerate reordering and callbacks arriving before the create response is saved. Retrieve current provider state when necessary.

### Commit 2

```text
feat(payment): track refund obligations
```

- [ ] B05.4: Add refund schema and guarded transitions for requested, submitting, pending, unknown, successful, and failed operations.

### Commit 3

```text
feat(payment): confirm eligible bookings
```

- [ ] B04.8: Implement atomic payment confirmation, booking confirmation, seat sale, and outbox insertion with the shared lock order and post-lock database-time checks.
- [ ] B04.9: For expired/cancelled bookings and additional successful charges, record the payment fact and a unique refund obligation; never revive the old hold.
- [ ] B04.13: Verify redirect spoofing cannot confirm a booking, invalid signatures cannot change state, mismatched payments are quarantined, and duplicate/reordered callbacks preserve invariants. Trace to AC-03, AC-04, AC-05, and AC-13.

Acceptance gate: Verify durable callback receipt, duplicate/out-of-order handling, amount/currency/identity checks, and payment-versus-expiry races. Every late/extra charge creates a unique refund obligation. AC-03, AC-04, AC-05, AC-13.

## PR-13: Reconcile payments and execute refunds

Branch: `feat/payment-reconciliation`  
Requires: PR-12  
Technical-plan milestone: 2

### Commit 1

```text
feat(payment): reconcile unknown outcomes
```

- [ ] B05.1: Implement leased, restartable reconciliation batches for unresolved attempts, missing callbacks, unmatched successful payments, and pending/unknown refunds.
- [ ] B05.2: Define retry/poll budgets, provider rate-limit handling, durable next-run times, age limits, and escalation for unresolved cases.
- [ ] B05.3: Respect provider idempotency retention limits; require lookup or manual investigation before repeating operations whose outcome remains uncertain beyond the supported window.

### Commit 2

```text
feat(payment): execute recoverable refunds
```

- [ ] B05.6: Submit refunds idempotently outside database transactions; recover lost provider responses and verify completion instead of equating submission with success.
- [ ] B05.7: Release refunded seats only after verified refund success and permitted sale conditions. Pending/failed refunds must not silently reactivate tickets or release inventory.
- [ ] B05.8: Expose safe payment/refund status and support references on owned-booking responses; make unresolved cases searchable by authorized staff.

### Commit 3

```text
test(payment): verify financial recovery
```

- [ ] B05.9: Verify missing callbacks, extra successful charges, provider outages, refund response loss, concurrent refund requests, and reconciliation restarts. Trace to AC-03, AC-04, AC-05, and AC-10.

Acceptance gate: Account for missing callbacks and extra charges, recover lost refund responses, and resume reconciliation after restart. Staff search wiring is finished in PR-17. Customer-requested support refunds are not exposed until PR-16. AC-03, AC-04, AC-05, AC-10.

## PR-14: Issue and retrieve tickets safely

Branch: `feat/ticket-issuance`  
Requires: PR-13  
Technical-plan milestone: 3

### Commit 1

```text
feat(ticketing): protect ticket credentials
```

- [ ] B06.1: Add tickets with a unique booking-seat constraint, random opaque credentials, verification hashes, and protected recoverable credential storage. Document key management and rotation.

### Commit 2

```text
feat(ticketing): issue tickets idempotently
```

- [ ] B06.2: Implement issuance from booking-confirmed events, locking/rechecking booking eligibility and inserting ticket records plus subsequent events atomically.
- [ ] B06.3: Reject stale issuance events after refund initiation; replay must reuse existing tickets rather than generating new credentials.

### Commit 3

```text
feat(ticketing): expose owned tickets
```

- [ ] B06.4: Implement authorized ticket retrieval independently of email delivery. Keep credentials out of URLs, logs, event payloads, and tracing attributes.

Acceptance gate: Verify one ticket per booking seat, protected retrieval, duplicate events, and rejection of issuance after refund initiation. AC-03, AC-13.

## PR-15: Deliver existing tickets by email

Branch: `feat/ticket-notifications`  
Requires: PR-14  
Technical-plan milestone: 3

### Commit 1

```text
feat(notification): deliver existing tickets
```

- [ ] B06.5: Add notification attempts, a local email adapter, retry policy, and delivery status. Staff resend must reference existing tickets. Document potential duplicate email delivery when the provider lacks idempotency.

Acceptance gate: Stop and restart mail delivery; booking confirmation and ticket retrieval continue, retry/resend reuses existing tickets, and possible email duplication is documented. AC-08.

## PR-16: Coordinate admission with support refunds

Branch: `feat/admission-refunds`  
Requires: PR-14, PR-15  
Technical-plan milestone: 3

### Commit 1

```text
feat(ticketing): validate online admission
```

- [ ] B06.6: Add admissions with a unique ticket constraint and atomic used-state transition; validate performance, booking eligibility, credential, and scanner permission.

### Commit 2

```text
feat(refund): coordinate refunds and entry
```

- [ ] B05.5: Implement full-order support refunds with permission/reason checks, booking locks, used-ticket rejection, transactional ticket invalidation, audit history, and a durable refund task. Expose the endpoint only with the ticket/admission checks delivered together in PR-16.
- [ ] B06.7: Coordinate admission and refund locks; reject normal refunds for used tickets and reject admission after refund acceptance.

### Commit 3

```text
test(ticketing): verify ticket lifecycle races
```

- [ ] B06.8: Verify notification outage, duplicate issuance, refund-before-issuance, concurrent scans, wrong performance, invalid credentials, and admission/refund races. Trace to AC-03, AC-08, AC-09, and AC-13.

Acceptance gate: Verify exactly one admission, wrong-performance/voided rejection, refund-before-issuance, and concurrent admission/refund. AC-03, AC-08, AC-09, AC-13.

## PR-17: Expose staff investigation and safe repair

Branch: `feat/staff-operations`  
Requires: PR-15, PR-16  
Technical-plan milestone: 3

### Commit 1

```text
feat(ops): expose booking support actions
```

- [ ] B07.1: Add paginated booking search by booking ID/provider reference and a unified transition timeline with sensitive fields redacted.
- [ ] B07.2: Expose role-protected performance configuration, sales pause/resume, full refund, and existing-ticket resend endpoints with audit records.
- [ ] B07.5: Add unresolved-payment/refund views and actions that trigger safe reconciliation rather than issuing blind repeat charges/refunds.

### Commit 2

```text
feat(ops): inspect and replay failed work
```

- [ ] B07.3: Add restricted failed-work inspection, failure reasons, original correlation IDs, attempts, and safe payload views.
- [ ] B07.4: Implement controlled replay preserving original identity for unprocessed work. Reject unsafe replay of already-completed effects; require an explicit audited repair operation instead.

### Commit 3

```text
test(ops): verify privileged repair access
```

- [ ] B07.7: Verify support, operator, entry-staff, and system-operator permission boundaries, replay abuse resistance, and complete privileged-action audit history. Trace to AC-13.

Acceptance gate: Support can diagnose booking/payment/refund history; authorized repair never blindly repeats charges or completed effects. Verify every privileged action is permission-checked and audited. AC-13.

## PR-18: Instrument backend workflows

Branch: `feat/backend-telemetry`  
Requires: PR-17  
Technical-plan milestone: 4

### Commit 1

```text
feat(telemetry): trace backend workflows
```

- [ ] B08.1: Instrument HTTP, pool waits, transaction duration/lock waits, provider calls, publisher confirms/returns, consumer processing, and maintenance batches with OpenTelemetry.
- [ ] B08.2: Propagate trace/correlation context through outbox messages. Keep high-cardinality business IDs in traces/logs rather than metric labels.

### Commit 2

```text
feat(metrics): add operational dashboards
```

- [ ] B08.3: Build dashboards for reservation latency/conflicts, oldest outbox age, queue age, redelivery, uncertain payments, pending refunds, ticket issuance delay, and job heartbeat.

Acceptance gate: Follow one booking across HTTP, SQL, outbox, workers, and provider calls; inspect bounded-cardinality metrics and dashboards. Baseline request/error metrics should already accompany earlier features.

## PR-19: Bound overload and protect retained data

Branch: `feat/backend-hardening`  
Requires: PR-18  
Technical-plan milestone: 4

### Commit 1

```text
feat(runtime): bound overload and intake
```

- [ ] B08.5: Bound HTTP resources, database pools, worker concurrency, and provider requests; add API/edge rate limits and safe overload responses.
- [ ] B08.6: Implement configurable backlog-age admission limits for new payable holds; preserve status queries, durable webhook ingestion, refunds, and recovery paths under degraded conditions.

### Commit 2

```text
feat(data): enforce retention policies
```

- [ ] B07.6: Define retention and cleanup jobs for sessions, idempotency records, inbox/outbox, webhook payloads, and failed work without removing needed financial/support evidence.

### Commit 3

```text
test(security): verify deployed controls
```

- [ ] B08.7: Verify secret handling, least-privilege database/broker users, private management access, TLS, cookie settings, payload redaction, retention policy, and staff MFA configuration.

Acceptance gate: Verify bounded resources and degraded-mode intake without blocking callbacks/refunds/status; validate retention, redaction, TLS, secret handling, and role policies.

## PR-20: Add and exercise operational alerts

Branch: `feat/operational-alerts`  
Requires: PR-19  
Technical-plan milestone: 4

### Commit 1

```text
feat(alerts): detect stalled backend work
```

- [ ] B08.4: Add actionable alerts for stale financial cases, callback backlog, expired leases, failed work, database saturation, and broker disk/memory/quorum health.

### Commit 2

```text
docs(ops): exercise alert response
```

- [ ] B08.8: Exercise alerts and document the first diagnostic and recovery action for each. Do not mark an alert complete merely because a rule exists.

Acceptance gate: Inject each alert condition and record detection plus the first recovery action. Financial stalls, broker health, and database saturation are observable.

## PR-21: Deploy independent backend process roles

Branch: `build/backend-deployment`  
Requires: PR-20  
Technical-plan milestone: 4

### Commit 1

```text
build: package backend process roles
```

- [ ] B09.1: Build pinned, minimal OCI images for independently selectable API, worker, and maintenance roles; configure runtime permissions and secret injection.

### Commit 2

```text
build(infra): provision backend services
```

- [ ] B09.2: Define infrastructure as code for TLS routing, private services, HA PostgreSQL/PITR, RabbitMQ across failure domains, telemetry, and identity integration.

### Commit 3

```text
build(release): verify compatible rollouts
```

- [ ] B09.3: Implement controlled migration jobs and expand/migrate/contract changes. Verify old/new workers and event readers can coexist during rollout.
- [ ] B09.4: Exercise graceful shutdown and rollback while requests and messages are in flight. Trace to AC-11.

Acceptance gate: Choose budget/region/provider before provisioning; demonstrate controlled migrations, old/new contract compatibility, graceful shutdown, and rollback during checkout. AC-11.

## PR-22: Measure backend load and failure recovery

Branch: `test/backend-capacity`  
Requires: PR-21  
Technical-plan milestone: 4

### Commit 1

```text
test(load): measure reservation capacity
```

- [ ] B09.5: Run the 2,000-concurrent-attempt/100-seat correctness exercise and mixed workloads; assert database invariants after every run. Trace to AC-01.
- [ ] B09.6: Measure p95 reservation latency at 100 reservation requests/second for 15 minutes, plus ordinary, hot-seat, spike, and sustained workloads. Report successes, conflicts, rate limits, and unexpected failures separately.

### Commit 2

```text
test(recovery): verify outage handling
```

- [ ] B09.7: Verify payment processing, ticket issuance, expiry, and refund-submission targets from the PRD under documented normal conditions.
- [ ] B09.8: Inject a 10-minute broker outage and verify backlog drains within the PRD's 20-minute recovery target without losing committed work. Trace to AC-06 and AC-07.
- [ ] B09.9: Run process-kill, network-loss, maintenance-restart, and provider-timeout exercises; record reproducible scenarios and invariant checks. Trace to AC-03 through AC-10.

### Commit 3

```text
docs(reports): record capacity evidence
```

- [ ] B09.13: Publish capacity and recovery reports with versions, hardware, limits, traffic distribution, seeds, commands, observed results, and unresolved gaps. Do not run load tests against Stripe Sandbox.

Acceptance gate: Publish reproducible correctness, latency, and recovery measurements with gaps. Exercise a 10-minute broker outage and the 20-minute drain target against the local simulator, not Stripe load. AC-01, AC-03 through AC-10.

## PR-23: Prove disaster recovery and release readiness

Branch: `test/backend-disaster-recovery`  
Requires: PR-22  
Technical-plan milestone: 4

### Commit 1

```text
test(dr): restore and reconcile state
```

- [ ] B09.10: Restore PostgreSQL into an isolated environment and measure the five-minute RPO/60-minute RTO targets. Reconcile external payments and reconstruct pending durable effects. Trace to AC-12.
- [ ] B09.11: Verify admission is paused during disaster recovery until restored admission/ticket state is reconciled; document the limitation of database recovery point loss.

### Commit 2

```text
docs(ops): exercise recovery runbooks
```

- [ ] B09.12: Write and exercise runbooks for sales pause, uncertain payments, late payments, failed refunds, message replay, broker outage, database recovery, ticket credential exposure, and rollout rollback.

### Commit 3

```text
docs(release): review backend readiness
```

- [ ] B09.14: Complete a backend release review against AC-01 through AC-13; record remaining live-money/venue requirements separately from sandbox readiness.

Acceptance gate: Measure RPO/RTO, reconcile provider reality, document admission recovery, and review every AC-01 through AC-13 with evidence. Record live-money/venue requirements separately. AC-12.

## PR-24: Design capacity-based waiting-room admission

Branch: `feat/waiting-room`  
Requires: PR-23  
Technical-plan milestone: 5

### Commit 1

```text
docs(admission): define waiting-room policy
```

- [ ] B10.1: Design a customer waiting room with a documented fairness policy, signed short-lived admission tokens, reconnect handling, and capacity-based intake. Keep its customer state separate from RabbitMQ work queues.

Acceptance gate: Record feature acceptance criteria, fairness and reconnect policy, signed-token design, and capacity-based intake rules. Add concrete implementation PRs/commits once the design is reviewed; this documentation PR does not deliver a working waiting room.

## PR-25: Offer released seats to the waitlist

Branch: `feat/seat-waitlist`  
Requires: PR-23  
Technical-plan milestone: 5

### Commit 1

```text
feat(waitlist): offer released seats
```

- [ ] B10.2: Add waitlist offers that allocate through the existing seat transaction, expire predictably, and respect purchase limits.

Acceptance gate: Define feature acceptance criteria first; verify expiring offers, concurrent acceptance, account limits, and allocation through the existing seat transaction.

## PR-26: Cancel performances with resumable refunds

Branch: `feat/performance-cancellation`  
Requires: PR-23  
Technical-plan milestone: 5

### Commit 1

```text
feat(ops): cancel performances safely
```

- [ ] B10.3: Implement resumable concert cancellation with sales pause, ticket invalidation, batched refund obligations, restart safety, and an operator completion report.

Acceptance gate: Define feature acceptance criteria first; restart cancellation mid-batch and account for every invalidated ticket and refund obligation.

## PR-27: Tune scaling within downstream budgets

Branch: `perf/backend-scaling`  
Requires: PR-23  
Technical-plan milestone: 5

### Commit 1

```text
perf(workers): evaluate bounded scaling
```

- [ ] B10.4: Evaluate queue-age-based scaling within database/provider budgets using measured workloads.

### Commit 2

```text
docs(cache): evaluate shared-state needs
```

- [ ] B10.5: Evaluate Redis only when measurements justify shared admission state or caching; preserve PostgreSQL as the authority for seat ownership.

Acceptance gate: Publish comparative measurements before changing worker counts or adding Redis; seat ownership remains authoritative in PostgreSQL.

## First implementation branch

Start with PR-01 (`chore/backend-bootstrap`). The existing planning documents may be captured in a separate documentation baseline commit/PR before implementation; that administrative step is not backend functionality and does not complete any task above.

Cloud provisioning, live-money launch, and advanced-feature scope remain explicit decisions. Passing a sandbox/backend gate does not establish frontend completion or live venue readiness.
