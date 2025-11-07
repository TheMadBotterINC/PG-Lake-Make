# Makefile at repo root
MODE ?= minio            # valid: minio, seaweed-fs
FILE := docker-compose-$(MODE).yml
compose := docker compose -f $(FILE)

.PHONY: up
up:
	@echo "🚀 Bringing up pg_lake ($(MODE))..."
	$(compose) up -d --wait

.PHONY: down
down:
	@echo "🧹 Shutting down ($(MODE))..."
	$(compose) down -v

.PHONY: seed
seed:
	@echo "🌱 Seeding Parquet..."
	$(compose) up parquet-seed --no-deps --abort-on-container-exit

.PHONY: ps
ps:
	$(compose) ps

.PHONY: logs
logs:
	$(compose) logs -f --tail=100

.PHONY: psql
psql:
	@docker exec -it $$(docker ps -qf "name=pg_lake-postgres") psql -U postgres
