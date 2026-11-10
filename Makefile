# Shortcuts for the Docker setup (see README.md).

up:            ## start everything (database, API, app, admin panel)
	docker compose up -d --build

backend:       ## only database + API (run Flutter yourself)
	docker compose up -d --build db api

sample:        ## import and publish the made-up sample content (once)
	docker compose run --rm seed

# make admin EMAIL=you@example.com NAME="Your name"   (asks for a password)
admin:         ## create an admin account
	docker compose run --rm api create-user --email "$(EMAIL)" --name "$(NAME)" --role admin

logs:
	docker compose logs -f api

down:          ## stop (data is kept)
	docker compose down

test:          ## run all tests locally (needs Go, Flutter and AVA_TEST_DATABASE_URL)
	cd server && go vet ./... && go test -p 1 ./...
	cd app && flutter analyze && flutter test

help:
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/'

.PHONY: up backend sample admin logs down test help
