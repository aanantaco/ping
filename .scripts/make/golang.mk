
BASE_IMAGE		    := scratch

GOLANG_BUILD_IMAGE	?= golang:1.24.2-bullseye
GOLANG_LINT_IMAGE	:= golangci/golangci-lint:v2.0.2
SQLC_IMAGE		    := sqlc/sqlc:1.29.0

APP					:= ping

#
# golang
#
# goals fmt, lint, test, build & publish (prefixed with 'go-')
#

.PHONY: go-mod
go-mod: ## Runs `go mod download` within a docker container
	@echo "+++ $$(date) - Running 'go mod download'"

ifeq ($(ENVIRONMENT),local)
	go mod download
else

	DOCKER_BUILDKIT=1 \
	docker run --rm \
	-v $(PWD):/usr/src/app \
	-w /usr/src/app \
	--user $(shell echo `id -u`:`id -g`) \
	--entrypoint "/bin/bash" \
	$(GOLANG_BUILD_IMAGE) \
	-c "cd /usr/src/app && go mod download; chmod -R a+rw .gocache/"

endif

.PHONY: go-generate
go-generate: ## Runs `go generate` within a docker container
	@echo "+++ $$(date) - Running 'go generate'"

ifeq ($(ENVIRONMENT),local)
	go generate ./...
else
	DOCKER_BUILDKIT=1 \
	docker run --rm \
	-v $(PWD):/usr/src/app \
	-w /usr/src/app \
	--entrypoint "/bin/bash" \
	$(GOLANG_BUILD_IMAGE) \
	-c "cd /usr/src/app && go generate ./..."
endif

	@echo "$$(date) - Completed 'go generate'"

.PHONY: go-fmt
go-fmt: ## Runs `go fmt` within a docker container
	@echo "+++ $$(date) - Running 'go fmt'"

ifeq ($(ENVIRONMENT),local)
	go fmt ./...
else
	DOCKER_BUILDKIT=1 \
	docker run --rm \
	-v $(PWD):/usr/src/app \
	-w /usr/src/app \
	$(GOLANG_BUILD_IMAGE) \
	--entrypoint "/bin/bash" \
	-c "cd /usr/src/app && go fmt ./..."

endif

	@echo "$$(date) - Completed 'go fmt'"

.PHONY: go-lint
go-lint: ## Runs `golangci-lint run` with more than 60 different linters using golangci-lint within a docker container.
	@echo "+++ $$(date) - Running 'golangci-lint run'"

ifeq ($(ENVIRONMENT),local)
	golangci-lint run
else
	DOCKER_BUILDKIT=1 \
	docker run --rm \
	-e GOPACKAGESPRINTGOLISTERRORS=1 \
	-e GO111MODULE=on \
	-e GOGC=100 \
	-v $(PWD):/usr/src/app \
	-w /usr/src/app \
	--entrypoint "/bin/bash" \
	$(GOLANG_LINT_IMAGE) \
	-c "cd /usr/src/app && golangci-lint run"

endif

	@echo "$$(date) - Completed 'golangci-lint run'"

.PHONY: go-test
go-test: ## Runs `go test` within a docker container
	@echo "+++ $$(date) - Running 'go test'"

ifeq ($(ENVIRONMENT),local)
	go test -failfast -cover -coverprofile=coverage.txt -v -p 8 -count=1 ./...
else

	DOCKER_BUILDKIT=1 \
	docker run --rm \
	-v $(PWD):/usr/src/app \
	-w /usr/src/app \
	--entrypoint=bash \
	$(GOLANG_BUILD_IMAGE) \
	-c "go test -failfast -cover -coverprofile=coverage.txt -v -p 8 -count=1 ./..."

endif

	@echo "+++ $$(date) - Completed 'go test'"

.PHONY: go-integration-test
go-integration-test: ## Runs `go test -run integration` within a docker container
	@echo "+++ $$(date) - Running 'go test -integration'"

ifeq ($(ENVIRONMENT),local)
	RUN_TEST="INTEGRATION" \
	go test -failfast -cover -coverprofile=coverage_integration.txt -v -count=1 ./...
else

	DOCKER_BUILDKIT=1 \
	docker run --rm \
	--add-host host.docker.internal:host-gateway \
	-e RUN_TEST="INTEGRATION" \
	-e DB_CON_INTEGRATION="host=host.docker.internal port=54321 user=postgres password=postgres dbname=postgres sslmode=disable pool_max_conns=2" \
	-v $(PWD):/usr/src/app \
	-w /usr/src/app \
	--entrypoint=bash \
	$(GOLANG_BUILD_IMAGE) \
	-c "go install gotest.tools/gotestsum@latest && cd /usr/src/app && gotestsum --junitfile junit.xml --format pkgname-and-test-fails -- -failfast -cover -coverprofile=coverage_integration.txt -v -p 1 -count=1 ./..."

endif

	@echo "+++ $$(date) - Completed 'go test -integration'"

.PHONY: go-build
go-build: check-APP go-generate ## Runs `go build` within a docker container
	@echo "+++ $$(date) - Running 'go build' for all go apps"

ifeq ($(ENVIRONMENT),local)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -v -o $(APP) -ldflags '-s -w -X main.version=${VERSION_HASH}' cmd/$(APP)/main.go
else

	DOCKER_BUILDKIT=1 \
	docker run --rm \
	-v $(PWD):/usr/src/app \
	-w /usr/src/app \
	--entrypoint=bash \
	$(GOLANG_BUILD_IMAGE) \
	-c "CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -v -o $(APP) -ldflags '-s -w -X main.version=$(VERSION_HASH)' cmd/$(APP)/main.go"

endif

	@echo "$$(date) - Completed 'go build'"

.PHONY: go-run-bash
go-run-bash:  ## Returns an interactive shell in the golang docker image - useful for debugging
	DOCKER_BUILDKIT=1 \
	docker run -it --rm \
	--memory=4g \
	-v $(PWD):/usr/src/app \
	-w /usr/src/app \
	--entrypoint "/bin/bash" \
	$(GOLANG_BUILD_IMAGE)


#
#  /end golang
#
