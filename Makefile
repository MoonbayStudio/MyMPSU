.PHONY: setup up down logs status test backup restore reset-db

setup:
	@test -f .env || cp .env.example .env
	@echo "Created .env. Replace the example secrets before production use."

up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f api

status:
	docker compose ps

test:
	python -m pytest tests

backup:
	./scripts/db-backup.sh

restore:
	@test -n "$(FILE)" || (echo "Usage: make restore FILE=backups/mympsu-YYYYMMDD-HHMMSS.sql" && exit 1)
	./scripts/db-restore.sh "$(FILE)"

reset-db:
	@echo "This deletes the local database volume. Run: docker compose down --volumes"
