# Common tasks. DATABASE_URL must be set for db commands, e.g.
#   export DATABASE_URL="postgres://ava:ava-dev-password@localhost:5432/ava?sslmode=disable"

CONTENT ?= ../ava_private_content

build:
	go build -o bin/ava-server ./cmd/ava-server

test:
	go vet ./...
	go test ./...

# Database tests need a throwaway database (it is wiped!):
#   AVA_TEST_DATABASE_URL=postgres://...ava_test... make test-db
test-db:
	go test -p 1 ./...

run: build
	./bin/ava-server serve

import: build
	./bin/ava-server import --dir $(CONTENT)

sample: build
	./bin/ava-server import --file testdata/sample_bundle.json
	./bin/ava-server publish --notes "sample content"

publish: build
	./bin/ava-server publish --notes "$(NOTES)"

.PHONY: build test test-db run import sample publish
