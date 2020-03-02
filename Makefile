.PHONY: deploy

host ?= faalkaart.nl

all: code/puppet/vendor/modules

# install all required puppet modules from Puppetfile.lock
code/puppet/vendor/modules: code/puppet/Puppetfile
	$(MAKE) -C code/puppet/ $*

code/puppet/modules/base/files/servertool: $(wildcard code/servertool/*.go)
	cd code/servertool; $(MAKE) $*

apply deploy: fix check code/puppet/vendor/modules code/puppet/modules/base/files/servertool
	scripts/deploy.sh ${host} ${args}

plan: args=--test
plan: check code/puppet/vendor/modules
	scripts/deploy.sh ${host} --noop ${args}

fix:
	$(MAKE) -C code/puppet/ $@

check: | fix
	shellcheck -x install.sh scripts/*.sh
	# all shell scripts should be executable
	find . -name "*.sh" \! -perm -a+x
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

# macOS virtualisation test

multipass: | /usr/local/bin/multipasss
	multipass launch -c 2 -d 20G -m 4G -n failmap ubuntu
	multipass mount . failmap:/opt/websecmap/server
	multipass exec failmap sudo /opt/websecmap/server/scripts/bootstrap.sh
	multipass exec failmap sudo /opt/websecmap/server/scripts/apply.sh


/usr/local/bin/multipass:
	brew cask install multipass