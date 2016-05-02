class letsencrypt(
    $email       = undef,
    $www_root    = '/var/www/letsencrypt',
    $config_root = '/etc/letsencrypt.sh',
    $cert_root   = '/etc/letsencrypt.sh/certs',
    $staging     = false,
){
    include renew

    File {
        owner  => root,
        group  => root,
    }

    file {
        $config_root:
            ensure => directory;

        "${config_root}/letsencrypt.sh":
            ensure => present,
            source => 'puppet:///modules/letsencrypt/letsencrypt.sh',
            mode   => '0755';

        "${config_root}/renew.sh":
            ensure => present,
            source => 'puppet:///modules/letsencrypt/renew.sh',
            mode   => '0755';

        "${config_root}/config.sh":
            ensure  => present,
            content => template('letsencrypt/config.sh.erb');

        $www_root:
            ensure => directory;

        $cert_root:
            ensure => directory;

        "${cert_root}/placeholders/":
            ensure => directory;

        "${cert_root}/placeholders/cert.pem":
            ensure => file,
            source => 'puppet:///modules/letsencrypt/placeholder_cert.pem';

        "${cert_root}/placeholders/key.pem":
            ensure => file,
            source => 'puppet:///modules/letsencrypt/placeholder_key.pem';
    }

    concat { "${config_root}/domains.txt":
        ensure         => present,
        ensure_newline => true,
    } ~> Class['renew']

    cron { 'letsencrypt-renew':
        command => "${config_root}/renew.sh >/dev/null",
        special => weekly,
    }

    File["${config_root}/config.sh"] ~> Class['renew']
}
