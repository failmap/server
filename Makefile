.PHONY: deploy

host ?= faalserver.faalkaart.nl

all: code/puppet/vendor/modules

# install all required puppet modules from Puppetfile.lock
code/puppet/vendor/modules: code/puppet/Puppetfile
	$(MAKE) -C code/puppet/ $*

apply deploy: code/puppet/vendor/modules
	scripts/deploy.sh ${host} ${args}

plan: args=--test
plan: code/puppet/vendor/modules
	scripts/deploy.sh ${host} --noop ${args}

fix:
	$(MAKE) -C code/puppet/ $@

check:
	shellcheck scripts/*.sh
	$(MAKE) -C code/puppet/ $@

bootstrap:
	scp scripts/bootstrap.sh ${host}:
	ssh ${host} sudo /bin/bash bootstrap.sh

mrproper clean:
	$(MAKE) -C code/puppet/ $@

# Docker stuff

test:
	docker build ${args} -t faalkaart .

test_inspect:
	docker run -p 80:80 -p 443:443 -ti faalkaart /bin/bash
