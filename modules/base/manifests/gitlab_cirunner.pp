# Custom cirunner class which does not include apt class
# https://github.com/vshn/puppet-gitlab/blob/master/manifests/cirunner.pp
class base::gitlab_cirunner {
  class {'gitlab::cirunner':
    manage_docker => false,
    manage_repo   => false,
  }

  $repo_base_url = 'https://packages.gitlab.com'
  $package_name = 'gitlab-ci-multi-runner'

  ensure_packages('apt-transport-https')

  $distid = downcase($::lsbdistid)

  ::apt::source { 'apt_gitlabci':
    comment  => 'GitlabCI Runner Repo',
    location => "${repo_base_url}/runner/${package_name}/${distid}/",
    release  => $::lsbdistcodename,
    repos    => 'main',
    key      => {
      'id'     => '1A4C919DB987D435939638B914219A96E15E78F4',
      'server' => 'keys.gnupg.net',
    },
    include  => {
      'src' => false,
      'deb' => true,
    }
  }
  Apt::Source['apt_gitlabci'] -> Package[$package_name]
  Exec['apt_update'] -> Package[$package_name]
}
