BIN := llmbench

.PHONY: build test fmt fmt-check vet check clean

build:
	v -o $(BIN) .

test:
	v test .

fmt:
	v fmt -w .

fmt-check:
	v fmt -diff .

vet:
	v vet .

check: fmt-check vet test

clean:
	rm -f $(BIN)
