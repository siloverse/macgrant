class keycloak_server {
  $tls_directory   = '/etc/keycloak'
  $tls_certificate = "${tls_directory}/server.crt"
  $tls_private_key = "${tls_directory}/server.key"

  class { 'keycloak':
    hostname         => '192.168.56.10',
    http_enabled     => false,
    https_port       => 8443,
    configs          => {
      'https-certificate-file'     => $tls_certificate,
      'https-certificate-key-file' => $tls_private_key,
    },
    db               => 'postgres',
    db_url_host      => 'localhost',
    db_url_port      => 5432,
    db_url_database  => 'keycloak',
    db_username      => 'keycloak_user',
    db_password      => 'keycloak_password',
    manage_db        => false,
    manage_db_server => false,
    require          => Postgresql::Server::Db['keycloak'],
  }

  file { $tls_directory:
    ensure  => directory,
    owner   => 'root',
    group   => 'keycloak',
    mode    => '0750',
    require => Group['keycloak'],
  }

  file { $tls_certificate:
    ensure  => file,
    owner   => 'root',
    group   => 'keycloak',
    mode    => '0644',
    source  => 'file:///vagrant/.local-certs/keycloak.crt',
    require => File[$tls_directory],
    notify  => Class['keycloak::service'];

    $tls_private_key:
    ensure  => file,
    owner   => 'root',
    group   => 'keycloak',
    mode    => '0640',
    source  => 'file:///vagrant/.local-certs/keycloak.key',
    require => File[$tls_directory],
    notify  => Class['keycloak::service'];
  }
}
