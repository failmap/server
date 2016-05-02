.PHONY: deploy

host = faalkaart

Puppetfile.lock: Puppetfile .librarian/puppet/config
	librarian-puppet install
	touch $@

apply deploy: Puppetfile.lock
	scripts/deploy.sh ${host} ${args}

plan: Puppetfile.lock
	scripts/deploy.sh ${host} --noop ${args}

bootstrap:
	scp scripts/bootstrap.sh ${host}:
	ssh ${host} /bin/bash bootstrap.sh

mrproper clean:
	rm -rf vendor Puppetfile.lock
