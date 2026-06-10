# @summary Creates a dynamic HTTP route for Traefik.
#
# @param hostname
#   Hostname that the Traefik router matches.
#
# @param target
#   Backend URL to which Traefik forwards requests.
#
# @param tls
#   Whether TLS is enabled for the route.
#
# @param insecure_skip_verify
#   Whether certificate verification is disabled for the backend service.
define traefik::http_route (
  String $hostname,
  String $target,
  Boolean $tls                  = true,
  Boolean $insecure_skip_verify = false,
) {
  $route_name = regsubst(
    $title,
    '[^a-zA-Z0-9-]',
    '-',
    'G',
  )

  $entry_point = $tls ? {
    true    => 'websecure',
    default => 'web',
  }

  file { "${traefik::dynamic_config_dir}/${route_name}.yml":
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    content => epp('traefik/http_route.yml.epp', {
      'route_name'           => $route_name,
      'hostname'             => $hostname,
      'target'               => $target,
      'entry_point'          => $entry_point,
      'tls'                  => $tls,
      'insecure_skip_verify' => $insecure_skip_verify,
    }),
    require => Class['traefik'],
  }
}
