BINARY := bin/caldav-free

.PHONY: build test vet fmt run clean docker tls web-deps web-build

web-deps:
	cd web && npm ci

web-build:
	cd web && if [ ! -d node_modules ]; then npm ci; fi
	cd web && npm run build

build: web-build
	go build -trimpath -o $(BINARY) ./cmd/caldav-free

test: web-build
	go test ./...

vet:
	go vet ./...

fmt:
	gofmt -w ./cmd ./internal

run:
	go run ./cmd/caldav-free -data ./data -addr :5232

tls:
	./scripts/gen-local-tls.sh ./data

clean:
	rm -rf bin

docker:
	docker build -t caldav-free:latest .
