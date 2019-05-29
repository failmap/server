# install tool to manage server using friendly UI
class base::servertool {
  concat::fragment { 'servertool motd':
    target  => '/etc/motd',
    content => "\n\u001B[1mRun `sudo websecmap-server-tool` to configure this server.\u001B[0m\n\n",
    order   => '10'
  }

  file {'/usr/local/bin/websecmap-server-tool':
    source => 'puppet:///modules/base/servertool',
    mode   => '0755',
  }

  file {'/etc/profile.d/servertool.sh':
    content => '! test "$(whoami)" == "root" && [[ $- == *i* ]] && \
                ! test -f $HOME/.no_servertool && sudo /usr/local/bin/websecmap-server-tool'
  }
}
