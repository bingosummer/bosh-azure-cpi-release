VERSION ?= $(shell git describe --always --abbrev=7 --dirty)

BASE_IMAGE_NAME      = azure-cpi-dev
MUTABLE_TAG         ?= canary
IMAGE_NAME           = $(BASE_IMAGE_NAME):$(VERSION)
MUTABLE_IMAGE_NAME   = $(BASE_IMAGE_NAME):$(MUTABLE_TAG)

# Checks for the existence of a docker client and prints a nice error message
# if it isn't present
.PHONY: check-docker
check-docker:
	@if [ -z $$(which docker) ]; then \
		echo "Missing \`docker\` client which is required for development"; \
		exit 2; \
	fi

# Checks for the existence of docker-compose and prints a nice error message if
# it isn't present
.PHONY: check-docker-compose
check-docker-compose: check-docker
	@if [ -z $$(which docker-compose) ]; then \
		echo "Missing \`docker-compose\` which is required for development"; \
		exit 2; \
	fi

# Containerized project bootstrapping-- requires docker-compose
# This will (re)build the development environment and populate the vendor/
# directory with dependencies specified by glide.lock
.PHONY: dev-bootstrap
dev-bootstrap: check-docker-compose
	docker-compose build dev

# Allow developers to step into the containerized development environment--
# requires docker-compose
.PHONY: dev
dev: check-docker-compose
	docker-compose run --rm dev bash

.PHONY: test
test: test-unit

# Containerized unit tests-- requires docker-compose
.PHONY: test-unit
test-unit: check-docker-compose
	docker-compose run --rm test bash -c 'go test -tags unit $$(glide nv)'

# Containerized binary build for linux/64 only-- requires docker-compose
.PHONY: build
build: check-docker-compose
	docker-compose run --rm dev \
		go build -o ${BINARY_DIR}/${BINARY_NAME} ./cmd/broker

# Build the Docker image
.PHONY: docker-build
docker-build: check-docker build
	docker build -t $(IMAGE_NAME) .
	docker tag $(IMAGE_NAME) $(MUTABLE_IMAGE_NAME)

# Push the Docker image
.PHONY: docker-push
docker-push: check-docker docker-build
	docker push $(IMAGE_NAME)
	docker push $(MUTABLE_IMAGE_NAME)
