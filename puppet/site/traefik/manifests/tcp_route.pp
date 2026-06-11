# @summary Creates a dynamic TCP route for Traefik.
#
# @param entry_point
#   Name of the static Traefik TCP entry point.
#
# @param target
#   Backend address to which Traefik forwards TCP connections.
#
# @param rule
#   Traefik TCP routing rule.
#
# @param tls_passthrough
#   Whether Traefik passes the TLS connection through to the backend.
define traefik::tcp_route (
  String[1] $entry_point,
  String[1] $target,
  String[1] $rule = 'HostSNI(`*`)',
  Boolean $tls_passthrough = false,
) {
  $route_name = regsubst(
    $title,
    '[^a-zA-Z0-9-]',
    '-',
    'G',
  )

  unless $entry_point in $traefik::tcp_entry_points {
    fail("Traefik TCP entry point '${entry_point}' is not configured")
  }

  file { "${traefik::dynamic_config_dir}/${route_name}.yml":
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    content => epp('traefik/tcp_route.yml.epp', {
      'route_name'      => $route_name,
      'entry_point'     => $entry_point,
      'target'          => $target,
      'rule'            => $rule,
      'tls_passthrough' => $tls_passthrough,
    }),
    require => Class['traefik'],
  }
}
