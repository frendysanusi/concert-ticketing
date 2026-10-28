.DEFAULT_GOAL := help

GO ?= go
export GOTOOLCHAIN := go$(shell sed -n 's/^go //p' backend/go.mod)
GOOSE_VERSION := v3.29.0
SQLC_VERSION := v1.31.1
TOOL_BIN := $(CURDIR)/.tools/bin
GOOSE := $(TOOL_BIN)/goose-$(GOOSE_VERSION)
SQLC := $(TOOL_BIN)/sqlc-$(SQLC_VERSION)
ENV_FILE ?= .env
COMPOSE := docker compose --env-file "$(ENV_FILE)" -f deploy/compose/compose.yaml --profile core
ROLE ?= api
MIGRATIONS_DIR ?= backend/migrations
SQLC_CONFIG ?= backend/sqlc.yaml

.PHONY: help build run fmt fmt-check check test tools env dev-up dev-down dev-status dev-logs migration migrate migrate-status generate

help:
	@printf '%s\n' \
	  'build / run ROLE=api|worker|maintenance|payment-simulator' \
	  'fmt / fmt-check / check / test / tools' \
	  'env / dev-up / dev-down / dev-status / dev-logs' \
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

tools: $(GOOSE) $(SQLC)

$(GOOSE):
	mkdir -p "$(TOOL_BIN)"
	GOBIN="$(TOOL_BIN)" $(GO) install -tags='no_clickhouse no_libsql no_mssql no_mysql no_sqlite3 no_vertica no_ydb' github.com/pressly/goose/v3/cmd/goose@$(GOOSE_VERSION)
	mv "$(TOOL_BIN)/goose" "$@"

$(SQLC):
	mkdir -p "$(TOOL_BIN)"
	GOBIN="$(TOOL_BIN)" $(GO) install github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)
	mv "$(TOOL_BIN)/sqlc" "$@"

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
