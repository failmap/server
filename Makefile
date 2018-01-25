.PHONY: deploy

host ?= faalserver.faalkaart.nl

all: vendor/modules

# install all required puppet modules from Puppetfile.lock
vendor/modules Puppetfile.lock: Puppetfile .librarian/puppet/config
	# currently broken
	# https://github.com/voxpupuli/librarian-puppet/issues/52
	# librarian-puppet install --verbose
	librarian-puppet install
	touch vendor/modules Puppetfile.lock

# search and resolve updates for all puppet modules in Puppetfile into Puppetfile.lock
modules_update:
	librarian-puppet update

apply deploy: vendor/modules
	scripts/deploy.sh ${host} ${args}

plan: args=--test
plan: Puppetfile.lock
	scripts/deploy.sh ${host} --noop ${args}

fix:
	puppet-lint --fix manifests
	puppet-lint --fix modules

check:
	shellcheck scripts/*.sh
	puppet-lint manifests
	puppet-lint modules

bootstrap:
	scp scripts/bootstrap.sh ${host}:
	ssh ${host} sudo /bin/bash bootstrap.sh

mrproper clean:
	rm -rf vendor

# Docker stuff

test:
	docker build ${args} -t faalkaart .

test_inspect:
	docker run -p 80:80 -p 443:443 -ti faalkaart /bin/bash
