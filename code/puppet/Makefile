all: vendor/modules

# this is where ruby dependencies (puppet, et al.) hhare installed
GEM_HOME = .gem
# these are the commands used from the local install
puppet = ${GEM_HOME}/bin/puppet
puppet-lint = ${GEM_HOME}/bin/puppet-lint
librarian-puppet = ${GEM_HOME}/bin/librarian-puppet
# put for every ruby command to use the correct environment
env = PATH=.gem/bin:$$PATH GEM_HOME=${GEM_HOME}

# install all required puppet modules from Puppetfile.lock
vendor/modules: Puppetfile.lock .librarian/puppet/config | ${librarian-puppet} ${puppet}
	@# currently broken
	@# https://github.com/voxpupuli/librarian-puppet/issues/52
	@# ${librarian-puppet$} install --verbose
	${env} ${librarian-puppet} install
	touch vendor/modules/

# search and resolve updates for all puppet modules in Puppetfile into Puppetfile.lock
modules_update: Puppetfile.lock
Puppetfile.lock: Puppetfile | ${librarian-puppet} ${puppet}
	${env} ${librarian-puppet} update

fix: | ${puppet-lint}
	${env} ${puppet-lint} --fix modules

check: | ${puppet-lint}
	${env} ${puppet} parser validate modules
	${env} ${puppet-lint} modules

clean:
	rm -rf vendor

mrproper: clean
	rm -rf .gem

${librarian-puppet} ${puppet-lint} ${puppet}:
	${env} gem install librarian-puppet puppet-lint puppet
