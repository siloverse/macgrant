# @summary Configures Keycloak behind the shared Traefik HTTP route.
class profile::keycloak (
  Stdlib::Host $hostname,
  Stdlib::IP::Address $http_host,
  Stdlib::Port $http_port,
  String[1] $admin_user,
  String[1] $admin_password,
  String[1] $db_user,
  String[1] $db_password,
  Stdlib::Host $db_host,
  Stdlib::Port $db_port,
  String[1] $db_name,
) {
  class { 'keycloak':
    hostname              => "https://${hostname}",
    http_enabled          => true,
    http_host             => $http_host,
    http_port             => $http_port,
    admin_user            => $admin_user,
    admin_user_password   => $admin_password,
    proxy_headers         => 'xforwarded',
    custom_config_content => epp('profile/keycloak.conf.epp', {
      'hostname'    => $hostname,
      'http_host'   => $http_host,
      'http_port'   => $http_port,
      'db_host'     => $db_host,
      'db_port'     => $db_port,
      'db_name'     => $db_name,
      'db_user'     => $db_user,
      'db_password' => $db_password,
    }),
    configs               => {
      'proxy-trusted-addresses' => [$http_host],
    },
    db                    => 'postgres',
    db_url_host           => $db_host,
    db_url_port           => $db_port,
    db_url_database       => $db_name,
    db_username           => $db_user,
    db_password           => $db_password,
    manage_db             => false,
    manage_db_server      => false,
    require               => Postgresql::Server::Db['keycloak'],
  }

  contain keycloak

  traefik::http_route { 'keycloak':
    hostname => $hostname,
    target   => "http://${http_host}:${http_port}",
    tls      => true,
  }

  Class['keycloak'] -> Traefik::Http_route['keycloak']
}
