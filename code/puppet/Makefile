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

fix:
	puppet-lint --fix manifests
	puppet-lint --fix modules

check:
	puppet-lint manifests
	puppet-lint modules

mrproper clean:
	rm -rf vendor
