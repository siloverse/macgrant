class postgres {
  class { 'postgresql::server':
    listen_addresses           => '*',
    ip_mask_deny_postgres_user => '0.0.0.0/32',
    ip_mask_allow_all_users    => '192.168.56.0/24',
    ipv4acls                   => ['host all all 127.0.0.1/32 scram-sha-256'],
    postgres_password          => '123123',
  }

  postgresql::server::db { 'tinyurl':
    user     => 'tinyurl_user',
    password => postgresql::postgresql_password('tinyurl_user', 'tinyurl_password'),
  }

  postgresql::server::db { 'keycloak':
    user     => 'keycloak_user',
    owner    => 'keycloak_user',
    password => postgresql::postgresql_password('keycloak_user', 'keycloak_password'),
  }
}
