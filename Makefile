.PHONY: deploy

host = faalserver.faalkaart.nl

Puppetfile.lock: Puppetfile .librarian/puppet/config
	# updating puppet modules, takes a while
	librarian-puppet install --clean
	touch $@

apply deploy: Puppetfile.lock
	scripts/deploy.sh ${host} ${args}

plan: Puppetfile.lock
	scripts/deploy.sh ${host} --noop ${args}

fix:
	puppet-lint --fix manifests
	puppet-lint --fix modules

check:
	puppet-lint manifests
	puppet-lint modules

bootstrap:
	scp scripts/bootstrap.sh ${host}:
	ssh ${host} /bin/bash bootstrap.sh

mrproper clean:
	rm -rf vendor Puppetfile.lock

# Docker stuff

test:
	docker build -t faalkaart .

test_inspect:
	docker run -p 80:80 -p 443:443 -ti faalkaart /bin/bash
