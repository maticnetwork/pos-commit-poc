PYTHON ?= PYTHONPATH=. python3
SOLC ?= ./solc-static-linux
SOLC_VERSION = 0.5.8
SOLC_OPTS ?= --optimize

all:
	@echo "Read Makefile?"

clean:
	rm -rf build .coverage .coverage.*
	find . -name '*.pyc' -exec rm '{}' ';'
	find . -name '__pycache__' -exec rm '{}' ';'

.PHONY: test
test:
	cd contracts && PYTHONPATH=.. python3 -m unittest discover ../tests/

requirements:
	$(PYTHON) -mpip install -r requirements.txt


# Retrieve static built solidity compiler for Linux (useful...)
solc-static-linux:
	curl -L -o $@ "https://github.com/ethereum/solidity/releases/download/v$(SOLC_VERSION)/solc-static-linux" || rm -f $@
	chmod 755 $@
