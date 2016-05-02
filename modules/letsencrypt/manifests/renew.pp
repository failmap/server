class letsencrypt::renew {
    exec { 'letsencrypt renew':
        command     => "${letsencrypt::config_root}/renew.sh",
        refreshonly => true,
    }
}
