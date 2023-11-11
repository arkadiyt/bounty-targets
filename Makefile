build:
	docker build . --tag bounty-targets

deploy:
	fly deploy

console:
	fly ssh console

%:
	$(MAKE) build
	docker run --rm -v $${PWD}:/app/ -it bounty-targets make -f Makefile.docker $@
