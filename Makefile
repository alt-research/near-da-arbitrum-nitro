#
# Copyright 2020, Offchain Labs, Inc. All rights reserved.
#

precompile_names = AddressTable Aggregator BLS Debug FunctionTable GasInfo Info osTest Owner RetryableTx Statistics Sys
precompiles = $(patsubst %,./solgen/generated/%.go, $(precompile_names))

repo_dirs = arbos arbnode arbstate cmd precompiles solgen system_tests wavmio
go_source = $(wildcard $(patsubst %,%/*.go, $(repo_dirs)) $(patsubst %,%/*/*.go, $(repo_dirs)))

color_pink = "\e[38;5;161;1m"
color_reset = "\e[0;0m"

done = "%bdone!%b\n" $(color_pink) $(color_reset)


# user targets

.make/all: always .make/solgen .make/solidity .make/test .make/arbitrator-exec
	@printf "%bdone building %s%b\n" $(color_pink) $$(expr $$(echo $? | wc -w) - 1) $(color_reset)
	@touch .make/all

build: $(go_source) .make/solgen .make/solidity .make/arbitrator-build
	@printf $(done)

contracts: .make/solgen
	@printf $(done)

format fmt: .make/fmt
	@printf $(done)

lint: .make/lint
	@printf $(done)

test: .make/test
	gotestsum --format short-verbose
	@printf $(done)

validation: arbitrator/target/env/lib/replay.wasm .make/arbitrator-exec
	@printf $(done)

push: .make/push
	@printf "%bready for push!%b\n" $(color_pink) $(color_reset)

clean:
	go clean -testcache
	@rm -rf solgen/artifacts solgen/cache solgen/go/
	@rm -f .make/*

docker:
	docker build -t nitro-node .

# regular build rules

arbitrator/target/env/lib/replay.wasm: $(go_source)
	GOOS=js GOARCH=wasm go build -o $@ ./cmd/replay/...

# strategic rules to minimize dependency building
.make/arbitrator-build: .make arbitrator/prover/** arbitrator/Makefile | .make
	$(MAKE) -C arbitrator/ build-env
	@touch .make/arbitrator

.make/arbitrator-exec: .make .make/arbitrator-build arbitrator/wasm-libraries/** | .make
	$(MAKE) -C arbitrator/ exec-env
	@touch .make/arbitrator

.make/push: .make/lint .make/test | .make
	@touch .make/push

.make/lint: .golangci.yml $(go_source) .make/solgen | .make
	golangci-lint run --fix
	@touch .make/lint

.make/fmt: .golangci.yml $(go_source) .make/solgen | .make
	golangci-lint run --disable-all -E gofmt --fix
	@touch .make/fmt

.make/test: $(go_source) .make/arbitrator-build .make/solgen .make/solidity | .make
	export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${PWD}/arbitrator/target/env/lib; \
	gotestsum --format short-verbose
	@touch .make/test

.make/solgen: solgen/gen.go .make/solidity | .make
	mkdir -p solgen/go/
	go run solgen/gen.go
	@touch .make/solgen

.make/solidity: solgen/src/*/*.sol .make/yarndeps | .make
	yarn --cwd solgen build
	@touch .make/solidity

.make/yarndeps: solgen/package.json solgen/yarn.lock | .make
	yarn --cwd solgen install
	@touch .make/yarndeps

.make:
	mkdir .make


# Makefile settings

always:              # use this to force other rules to always build
.DELETE_ON_ERROR:    # causes a failure to delete its target
