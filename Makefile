# SPDX-FileCopyrightText: 2020 SAP SE
#
# SPDX-License-Identifier: Apache-2.0

GO ?= go

BINS ?= $(patsubst cmd/%,%,$(wildcard cmd/*))

REUSE_ARGS = --skip-unrecognised --copyright='SAP SE' --license='Apache-2.0'

build: $(BINS)
$(BINS):
	go build -o $@ ./cmd/$@/

generate:
ifeq (x$(TARGET),x)
	grep -r '^// Code generated by ".*"\; DO NOT EDIT.$\' ./ | awk -F: '{ print $$1 }' | xargs --no-run-if-empty rm
	$(GO) generate ./...
	reuse addheader $(REUSE_ARGS) $(shell find . -type f -not -path '*/.git/*')
else
	grep '^// Code generated by ".*"\; DO NOT EDIT.$\' ./$(TARGET)/* | awk -F: '{ print $$1 }' | xargs --no-run-if-empty rm
	$(GO) generate ./$(TARGET)
	reuse addheader $(REUSE_ARGS) $(shell find ./$(TARGET) -type f -not -path '*/.git/*')
endif
	# go generate will also rebuild the go.sum and remove the
	# header. Since generate only targets generated files and
	# licenses the go.sum modification can be reverted.
	[ -d .git ] && git checkout -- go.sum

LINT_IGNORE ?= /cgo \
	      /cmd/cgoase
LINT_IGNORE := $(patsubst %,-e %,$(LINT_IGNORE))
LINT_DO_DIRS = $(shell go list -f '{{.Dir}}' ./... | grep -v $(LINT_IGNORE))

lint:
	golangci-lint run $(LINT_DO_DIRS)

# lint-echo is used by github actions to lint the same files as
# `make lint`.
lint-dirs:
	@echo $(LINT_DO_DIRS)

test: test-cgo test-go
test-cgo:
	$(GO) test -race -cover ./cgo/... ./cmd/cgoase/...
test-go:
	$(GO) test -race -cover ./purego/... ./cmd/goase/... ./libase/...

integration: integration-cgo integration-go
integration-cgo:
	$(GO) test -race -cover ./cgo/... ./examples/cgo/... --tags=integration
integration-go:
	$(GO) test -race -cover ./purego/... ./examples/purego/... --tags=integration

report:
	$(GO) test -race -cover -coverprofile=/tmp/covCmd.out -coverpkg=./... \
		./cmd/...
	$(GO) test -race -cover -coverprofile=/tmp/covUnitLibase.out ./libase/...
	$(GO) test -race -cover -coverprofile=/tmp/covIntCgo.out -coverpkg=./... \
		./cgo/... ./examples/cgo/... --tags=integration
	$(GO) test -race -cover -coverprofile=/tmp/covIntGo.out -coverpkg=./... \
		./purego/... ./examples/purego/... --tags=integration
	# Merge coverprofiles and create summary-html-file
	gocovmerge /tmp/covIntCgo.out /tmp/covIntGo.out /tmp/covCmd.out /tmp/covUnitLibase.out > sumCoverage.out
	$(GO) tool cover -html=sumCoverage.out -o ./sumCoverage.html

GO_EXAMPLES := $(wildcard examples/purego/*)
CGO_EXAMPLES := $(wildcard examples/cgo/*)
EXAMPLES := $(GO_EXAMPLES) $(CGO_EXAMPLES)

examples: $(EXAMPLES)

.PHONY: $(EXAMPLES)
$(EXAMPLES):
	@echo Running example: $@
	$(GO) run ./$@/main.go
