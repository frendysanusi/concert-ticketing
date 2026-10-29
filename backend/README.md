# Backend

Go 1.27.3 is the bootstrap toolchain baseline, recorded in `go.mod`.
The application module currently uses only the standard library.

Run development commands from the repository root:

```sh
make build
make check
make test
make fmt
```

`make build` writes the four executables to the ignored `bin/` directory.
`make check` checks formatting without changing files and runs `go vet`.
`make test` runs `go test ./...`; no application tests exist yet.
Use `make help` to list commands.

Run any process entry point:

```sh
make run ROLE=api
make run ROLE=worker
make run ROLE=maintenance
make run ROLE=payment-simulator
```

Each command prints its role and exits successfully. These are bootstrap entry
points; HTTP serving, background processing, configuration, and graceful shutdown
are implemented in later planned commits. The application does not consume `.env`
yet.

Domain packages live under `internal/`: catalog, booking, payment, ticketing,
notification, and operations. Each owns its domain tables and mutations; booking
will coordinate payment confirmation and seat ownership. Add shared infrastructure
packages as their first consumers need them.

## Tools and versions

Install Go, Make, and Docker with the Compose plugin. Host verification used Docker
Engine 29.7.2 and Compose 5.4.0; Compose must support `up --wait`.

| Tool or service | Pinned version | Recorded in |
| --- | --- | --- |
| Go | 1.27.3 | `backend/go.mod`; Make exports the exact `GOTOOLCHAIN` |
| Goose | v3.29.0 | Root `Makefile` |
| sqlc | v1.31.1 | Root `Makefile` |
| govulncheck | v1.9.0 | Root `Makefile` |
| actionlint | v1.7.12 | Root `Makefile` |
| PostgreSQL | 18.6-alpine | `deploy/compose/compose.yaml` |
| RabbitMQ | 4.4.0-management-alpine | `deploy/compose/compose.yaml` |
| Mailpit | v1.32.0 | `deploy/compose/compose.yaml` |
| Keycloak | 26.8.1 | `deploy/compose/compose.yaml` |

`make tools` installs versioned Goose, sqlc, govulncheck, and actionlint binaries
under the ignored `.tools/bin/` directory. Goose is built with only its PostgreSQL
driver. Go's module proxy and checksum database verify tool dependencies without adding them
to the application module. The first run needs network access. Set `GO=/path/to/go`
when Go is installed outside `PATH`.

Container references pin multi-platform image digests as well as release tags.
Review pins monthly and when security fixes are published. Update a tool's version
or an image's tag and digest together, check its release notes, and repeat build,
check, test, dependency startup, and the relevant smoke checks before merging.
Consult the [PostgreSQL releases](https://www.postgresql.org/docs/release/),
[RabbitMQ release information](https://www.rabbitmq.com/release-information),
[Goose releases](https://github.com/pressly/goose/releases),
[sqlc releases](https://github.com/sqlc-dev/sqlc/releases),
[Mailpit releases](https://github.com/axllent/mailpit/releases), and
[Keycloak releases](https://www.keycloak.org/blog.html).

## Local dependencies

With Docker running, one command copies `.env.example` to `.env` if missing and
starts the core profile, waiting for all four services to become healthy:

```sh
make dev-up
make dev-status
make dev-logs
```

All published ports bind to `127.0.0.1`. `.env.example` contains public development
credentials and no real secrets. Keep `.env` untracked and use this stack only for
local development. `make env` never overwrites an existing file. Change host port
variables in `.env` if needed; update `DATABASE_URL`, `AMQP_URL`, or `OIDC_ISSUER`
to match any port/credential changes. Values must also be valid shell assignments
because migration commands load this file. Use `ENV_FILE=path` to select another
local environment file.

| Service | Host endpoint | Local fixture |
| --- | --- | --- |
| PostgreSQL | `127.0.0.1:5432` | Database `concert_ticketing`, user `concert`, password `local-postgres` |
| RabbitMQ | AMQP `127.0.0.1:5672`, UI `http://localhost:15672` | User `concert`, password `local-rabbitmq` |
| Mailpit | SMTP `127.0.0.1:1025`, UI `http://localhost:8025` | Captures mail without forwarding; no SMTP authentication |
| Keycloak | `http://localhost:8081` | Admin `admin` / `local-admin`; customer `customer` / `local-customer` |

PostgreSQL and RabbitMQ use named volumes. `make dev-down` stops the stack while
retaining these volumes. Their initial credentials are only applied when the
volumes are first initialized. Keycloak and captured mail are disposable; the realm
fixture is imported into a fresh development database after recreation.

Keycloak is the local OIDC fixture because it supports discovery and authorization
code flow with S256 PKCE. The imported `concert-ticketing` realm has a public client
of the same name, with password grants and implicit flow disabled. Its single
allowed callback is `http://localhost:8080/api/v1/auth/callback`, reserved for the
future API integration. Discovery is at
`http://localhost:8081/realms/concert-ticketing/.well-known/openid-configuration`.
Use `localhost` consistently for issuer URLs. This development fixture does not
select the deployed identity provider or satisfy PR-03's staff MFA gate.

Basic dependency checks after startup:

```sh
make dev-smoke
```

This checks an authenticated PostgreSQL query, RabbitMQ listener connectivity,
Mailpit readiness, and Keycloak discovery. It reads host endpoints from `.env`
and requires `curl` in addition to Docker. Start dependencies with `make dev-up`
before running it.

## Migrations and typed SQL

The commands are ready for the schemas and queries introduced in PR-02:

```sh
make tools
make migration NAME=create_catalog
make migrate
make migrate-status
make generate
```

`make migration` creates a sequential Goose SQL migration under `backend/migrations`.
`make migrate` applies forward migrations using `DATABASE_URL` from `.env`.
No rollback command runs automatically. `make generate` uses `backend/sqlc.yaml`;
the owning module's configuration must keep generated code inside that module.
Override `MIGRATIONS_DIR` or `SQLC_CONFIG` for isolated tool smoke checks.

There are no application migrations or sqlc configuration yet. Until PR-02 adds
them, `make migrate`, `make migrate-status`, and `make generate` fail with an explicit
message. No placeholder schema or generated application code is needed for bootstrap.

## CI

`.github/workflows/backend.yml` runs on pull requests, pushes to `main`, and manual
dispatch. It runs for every change, including contracts and deployment files.
Actions are pinned to commit SHAs, with read-only repository permissions.

The workflow validates its own syntax with actionlint, checks formatting and vet,
builds all process roles, checks generated output, and scans known Go
vulnerabilities with govulncheck. It then starts the core Compose profile, checks
dependency connectivity, and runs every package's tests with the race detector.
There are no application tests yet; PostgreSQL/RabbitMQ integration fixtures start
in PR-02. Failed runs collect dependency logs, and cleanup runs on success or failure.

Run the same checks locally:

```sh
make workflow-check build check vuln-check
make generate-check
make dev-up dev-smoke test-race
make dev-down
```

`make generate-check` requires a clean backend working tree. It runs Go generators
and sqlc when `backend/sqlc.yaml` exists, then rejects tracked changes and untracked
backend files. Until PR-02 adds sqlc configuration, it reports that SQL generation
is skipped; Go generation and drift detection still run. `make vuln-check` uses the
current Go vulnerability database and needs network access. Race checks require a
C compiler and cgo support, as provided by the Ubuntu 24.04 CI runner.

Local verification on 2026-10-29 (macOS arm64) passed the workflow command sequence
from an isolated checkout. Additional checks rejected tracked/untracked generated
drift and a missing OIDC realm, and exercised sqlc when a fixture configuration was
present. No known reachable Go vulnerabilities were reported. The GitHub-hosted
workflow has not run yet; the PR-01 acceptance gate remains pending that run.
