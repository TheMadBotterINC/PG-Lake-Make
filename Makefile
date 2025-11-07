# infra/pg_lake/Makefile
# Simple orchestrator for pg_lake + MinIO sandbox
# Works on any Ubuntu or Linux VM with Docker and docker-compose installed.

PG_LAKE_DIR := $(shell pwd)
COMPOSE_FILES := -f docker-compose.yml -f docker-compose.override.yml

# Shortcut variable for Compose command
compose := docker compose $(COMPOSE_FILES)

# Default target
.PHONY: up
up:
	@echo "🚀 Bringing up pg_lake stack (Postgres + MinIO + pgduck_server)..."
	$(compose) up -d --wait
	@echo "🧩 Seeding Parquet test data..."
	$(compose) up parquet-seed --no-deps --abort-on-container-exit
	@echo "✅ Stack ready! Use 'make psql' or visit MinIO on :9001"

.PHONY: down
down:
	@echo "🧹 Stopping all services and removing volumes..."
	$(compose) down -v

.PHONY: restart
restart:
	@echo "🔁 Restarting stack..."
	$(MAKE) down
	$(MAKE) up

.PHONY: ps
ps:
	$(compose) ps

.PHONY: logs
logs:
	$(compose) logs -f --tail=50

.PHONY: psql
psql:
	@echo "🔗 Connecting to Postgres shell..."
	@docker exec -it $$(docker ps -qf "name=postgres") psql -U postgres

.PHONY: seed
seed:
	@echo "🌱 Regenerating Parquet test data..."
	$(compose) up parquet-seed --no-deps --abort-on-container-exit

.PHONY: shell
shell:
	@docker exec -it $$(docker ps -qf "name=postgres") bash

.PHONY: status
status:
	@echo "📊 Service status:"
	$(compose) ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}"

.PHONY: clean
clean:
	@echo "🧽 Removing all Docker images & volumes related to pg_lake..."
	docker compose down -v --rmi all --remove-orphans
	@echo "✅ Cleanup complete."