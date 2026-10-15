.PHONY: help setup start stop logs pull update-auth

help:
	@echo "Available commands:"
	@echo "  setup       - Generate registry auth from .env"
	@echo "  start       - Start all services (detached)"
	@echo "  stop        - Stop all services"
	@echo "  logs        - Follow logs"
	@echo "  pull        - Pull latest images"
	@echo "  update-auth - Regenerate registry htpasswd"
	@echo "  status      - Show running containers"

setup:
	./scripts/generate-registry-auth.sh

start:
	docker compose up -d

stop:
	docker compose down

logs:
	docker compose logs -f --tail=50

pull:
	docker compose pull

update-auth:
	./scripts/generate-registry-auth.sh
	@echo "Restarting registry to apply new auth..."
	docker compose restart registry

status:
	docker compose ps
