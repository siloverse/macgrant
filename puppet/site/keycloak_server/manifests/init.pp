class keycloak_server {
  class { 'keycloak':
    hostname     => "https://keycloak.${facts['macgrant_domain']}",

    http_enabled => true,
    http_host    => '127.0.0.1',

    configs => {
      'http-port'              => 8443,
      'proxy-headers'          => 'xforwarded',
      'proxy-trusted-addresses' => ['127.0.0.1'],
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

  traefik::http_route { 'keycloak':
    hostname => "keycloak.${facts['macgrant_domain']}",
    target   => 'http://127.0.0.1:8443',
    tls      => true,
  }
}
