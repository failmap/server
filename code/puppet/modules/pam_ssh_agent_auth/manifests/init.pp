# allow sudo authentication based on ssh authorized keys in /etc/sudo_ssh_authorized_keys
class pam_ssh_agent_auth (
  $key_dir='/etc/sudo_ssh_authorized_keys',
){
  file { '/var/tmp/pam-ssh-agent-auth_0.10.2-0ubuntu0ppa1_amd64.deb':
    source => 'puppet:///modules/pam_ssh_agent_auth/pam-ssh-agent-auth_0.10.2-0ubuntu0ppa1_amd64.deb',
  }
  -> package { 'pam-ssh-agent-auth':
    ensure   => latest,
    source   => '/var/tmp/pam-ssh-agent-auth_0.10.2-0ubuntu0ppa1_amd64.deb',
    provider => dpkg,
  }

  file { '/etc/pam.d/sudo':
    source => 'puppet:///modules/pam_ssh_agent_auth/sudo.pam',
    owner  => root,
    group  => root,
    mode   => '0644',
  }

  sudo::conf { 'ssh-agent propagation for pam sudo':
    priority => 10,
    content  => 'Defaults    env_keep += "SSH_AUTH_SOCK"',
  }

  file { $key_dir:
    ensure => directory,
  }
}
