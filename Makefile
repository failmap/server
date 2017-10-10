.PHONY: deploy

host = faalserver.faalkaart.nl

all: vendor/modules

vendor/modules Puppetfile.lock: Puppetfile .librarian/puppet/config
	librarian-puppet install --verbose
	touch vendor/modules Puppetfile.lock

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
	ssh ${host} /bin/bash bootstrap.sh

mrproper clean:
	rm -rf vendor

# Docker stuff

# Run test suite using Docker
test:
	docker run -ti \
		--env FACTER_env=docker \
		--env FACTER_fqdn=faalserver.faalkaart.test \
		--env FACTER_ipaddress6=::1 \
		--env DEBIAN_FRONTEND=noninteractive \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--volume $$PWD:/source/ \
		bootstrapped \
		source/scripts/docker_test.sh

test_inspect:
	docker run -p 80:80 -p 443:443 -ti faalkaart /bin/bash
