# @summary Routes backend service hostnames to processes on the host.
#
# @param domain
#   Domain under which every backend service hostname lives.
#
# @param target_ip
#   IP address on which the backend service processes listen.
#
# @param services
#   Mapping of backend service names to their registered ports.
class profile::backend (
  String[1] $domain,
  Stdlib::IP::Address $target_ip,
  Hash[String[1], Stdlib::Port] $services,
) {
  $services.each |String $name, Stdlib::Port $port| {
    traefik::http_route { $name:
      hostname => "${name}.${domain}",
      target   => "http://${target_ip}:${port}",
      tls      => true,
    }
  }
}
