.DEFAULT_GOAL := help

GO ?= go
export GOTOOLCHAIN := go$(shell sed -n 's/^go //p' backend/go.mod)
GOOSE_VERSION := v3.29.0
SQLC_VERSION := v1.31.1
GOVULNCHECK_VERSION := v1.9.0
ACTIONLINT_VERSION := v1.7.12
TOOL_BIN := $(CURDIR)/.tools/bin
GOOSE := $(TOOL_BIN)/goose-$(GOOSE_VERSION)
SQLC := $(TOOL_BIN)/sqlc-$(SQLC_VERSION)
GOVULNCHECK := $(TOOL_BIN)/govulncheck-$(GOVULNCHECK_VERSION)
ACTIONLINT := $(TOOL_BIN)/actionlint-$(ACTIONLINT_VERSION)
ENV_FILE ?= .env
COMPOSE := docker compose --env-file "$(ENV_FILE)" -f deploy/compose/compose.yaml --profile core
ROLE ?= api
MIGRATIONS_DIR ?= backend/migrations
SQLC_CONFIG ?= backend/sqlc.yaml

.PHONY: help build run fmt fmt-check check test test-race vuln-check workflow-check generate-check tools env dev-up dev-down dev-status dev-logs dev-smoke migration migrate migrate-status generate

help:
	@printf '%s\n' \
	  'build / run ROLE=api|worker|maintenance|payment-simulator' \
	  'fmt / fmt-check / check / test / tools' \
	  'test-race / vuln-check / workflow-check / generate-check' \
	  'env / dev-up / dev-down / dev-status / dev-logs / dev-smoke' \
	  'migration NAME=description / migrate / migrate-status / generate'

build:
	cd backend && $(GO) build -o ../bin/ ./cmd/...

run:
	@case "$(ROLE)" in api|worker|maintenance|payment-simulator) ;; *) printf '%s\n' 'Unknown ROLE' >&2; exit 1 ;; esac
	cd backend && $(GO) run ./cmd/$(ROLE)

fmt:
	cd backend && $(GO) fmt ./...

fmt-check:
	@formatting=$$("$$($(GO) env GOROOT)/bin/gofmt" -l backend) || exit 1; \
	  if [ -n "$$formatting" ]; then printf '%s\n' "$$formatting" >&2; exit 1; fi

check: fmt-check
	cd backend && $(GO) vet ./...

test:
	cd backend && $(GO) test ./...

test-race:
	cd backend && $(GO) test -race ./...

vuln-check: $(GOVULNCHECK)
	cd backend && PATH="$$($(GO) env GOROOT)/bin:$$PATH" "$(GOVULNCHECK)" ./...

workflow-check: $(ACTIONLINT)
	"$(ACTIONLINT)" .github/workflows/*.yml

generate-check:
	cd backend && $(GO) generate ./...
	@if [ -f "$(SQLC_CONFIG)" ]; then $(MAKE) generate; else printf '%s\n' 'Skipping sqlc: no config yet (PR-02).'; fi
	git diff --exit-code -- backend
	@test -z "$$(git ls-files --others --exclude-standard -- backend)" || { git ls-files --others --exclude-standard -- backend; exit 1; }

tools: $(GOOSE) $(SQLC) $(GOVULNCHECK) $(ACTIONLINT)

$(GOOSE):
	mkdir -p "$(TOOL_BIN)"
	GOBIN="$(TOOL_BIN)" $(GO) install -tags='no_clickhouse no_libsql no_mssql no_mysql no_sqlite3 no_vertica no_ydb' github.com/pressly/goose/v3/cmd/goose@$(GOOSE_VERSION)
	mv "$(TOOL_BIN)/goose" "$@"

$(SQLC):
	mkdir -p "$(TOOL_BIN)"
	GOBIN="$(TOOL_BIN)" $(GO) install github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)
	mv "$(TOOL_BIN)/sqlc" "$@"

$(GOVULNCHECK):
	mkdir -p "$(TOOL_BIN)"
	GOBIN="$(TOOL_BIN)" $(GO) install golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION)
	mv "$(TOOL_BIN)/govulncheck" "$@"

$(ACTIONLINT):
	mkdir -p "$(TOOL_BIN)"
	GOBIN="$(TOOL_BIN)" $(GO) install github.com/rhysd/actionlint/cmd/actionlint@$(ACTIONLINT_VERSION)
	mv "$(TOOL_BIN)/actionlint" "$@"

env:
	@test -f "$(ENV_FILE)" || cp .env.example "$(ENV_FILE)"

dev-up: env
	$(COMPOSE) up -d --wait --wait-timeout 180

dev-down: env
	$(COMPOSE) down

dev-status: env
	$(COMPOSE) ps

dev-logs: env
	$(COMPOSE) logs --tail=100

dev-smoke: env
	$(COMPOSE) exec -T postgres sh -ec 'PGPASSWORD="$$POSTGRES_PASSWORD" psql -X -h 127.0.0.1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "SELECT 1"'
	$(COMPOSE) exec -T rabbitmq rabbitmq-diagnostics -q check_port_connectivity
	@set -a; . "$(abspath $(ENV_FILE))"; set +a; \
	  curl --fail --silent --show-error --max-time 10 "http://127.0.0.1:$${MAILPIT_HTTP_PORT:-8025}/readyz" --output /dev/null && \
	  curl --fail --silent --show-error --max-time 10 "$${OIDC_ISSUER:?Set OIDC_ISSUER in $(ENV_FILE)}/.well-known/openid-configuration" --output /dev/null

migration: $(GOOSE)
	@test -n "$(NAME)" || { printf '%s\n' 'Set NAME, e.g. make migration NAME=create_catalog' >&2; exit 1; }
	mkdir -p "$(MIGRATIONS_DIR)"
	"$(GOOSE)" -env=none -dir "$(MIGRATIONS_DIR)" -s create "$(NAME)" sql

migrate migrate-status: env $(GOOSE)
	@test -d "$(MIGRATIONS_DIR)" || { printf '%s\n' 'No migration directory yet; migrations start in PR-02.' >&2; exit 1; }
	@set -a; . "$(abspath $(ENV_FILE))"; set +a; \
	  "$(GOOSE)" -env=none -dir "$(MIGRATIONS_DIR)" postgres "$${DATABASE_URL:?Set DATABASE_URL in $(ENV_FILE)}" $(if $(filter migrate,$@),up,status)

generate: $(SQLC)
	@test -f "$(SQLC_CONFIG)" || { printf '%s\n' 'No sqlc config yet; typed queries start in PR-02.' >&2; exit 1; }
	"$(SQLC)" generate -f "$(SQLC_CONFIG)"
