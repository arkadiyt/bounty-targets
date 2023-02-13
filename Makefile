build:
	docker build . --tag bounty-targets

deploy:
	fly deploy

%:
	$(MAKE) build
	docker run --rm -v $${PWD}:/app/ -it bounty-targets make -f Makefile.docker $@
