BINARY := bin/caldav-free

.PHONY: build test vet fmt run clean docker tls

build:
	go build -trimpath -o $(BINARY) ./cmd/caldav-free

test:
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
