PYTHON ?= PYTHONPATH=. python3

all:
	@echo "Read Makefile?"

clean:
	rm -rf build .coverage .coverage.*
	find . -name '*.pyc' -exec rm '{}' ';'
	find . -name '__pycache__' -exec rm '{}' ';'

.PHONY: test
test:
	$(PYTHON) -m unittest discover tests/

requirements:
	$(PYTHON) -mpip install -r requirements.txt
