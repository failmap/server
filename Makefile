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

multipass: multipass_apply multipass_bootstrap

multipass_bootstrap: | /usr/local/bin/multipass
	multipass launch -c 2 -d 20G -m 4G -n failmap ubuntu
	multipass mount . failmap:/opt/websecmap/server
	multipass exec failmap sudo /opt/websecmap/server/scripts/bootstrap.sh

multipass_apply: | /usr/local/bin/multipass
	multipass exec failmap sudo /opt/websecmap/server/scripts/apply.sh

multipass_test: | /usr/local/bin/inspec
	inspec exec tests/ --target ssh://

multipass_delete: | /usr/local/bin/multipass
	multipass delete failmap
	multipass purge

/usr/local/bin/multipass /usr/local/bin/inspec: /usr/local/bin/%
	brew cask install $^