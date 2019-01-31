# install tool to manage server using friendly UI
class base::servertool {
  package { 'whiptail': }

  concat::fragment { 'servertool motd':
    target  => '/etc/motd',
    content => "\n\u001B[1mRun `sudo failmap-server-tool` to configure this server.\u001B[0m\n\n",
    order   => '10'
  }

  file {'/usr/local/bin/failmap-server-tool':
    source => 'puppet:///modules/base/servertool.sh',
    mode   => '0755',
  }
}
