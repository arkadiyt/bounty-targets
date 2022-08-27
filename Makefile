build:
	docker build . --tag bounty-targets

%:
	$(MAKE) build
	docker run --rm -v $${PWD}:/app/ -it bounty-targets make -f Makefile.docker $@
