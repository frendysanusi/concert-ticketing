# Backend

Go 1.27.3 is the bootstrap toolchain baseline, recorded in `go.mod`.
The module currently uses only the standard library.

From this directory, build and check all packages:

```sh
go build ./...
go test ./...
go vet ./...
gofmt -l .
```

Run each process entry point:

```sh
go run ./cmd/api
go run ./cmd/worker
go run ./cmd/maintenance
go run ./cmd/payment-simulator
```

Each command prints its role and exits successfully. These are bootstrap entry
points; HTTP serving, background processing, configuration, and graceful shutdown
are implemented in later planned commits. There are no application tests yet.

Domain packages live under `internal/`: catalog, booking, payment, ticketing,
notification, and operations. Each owns its domain tables and mutations; booking
will coordinate payment confirmation and seat ownership. Add shared infrastructure
packages as their first consumers need them.
