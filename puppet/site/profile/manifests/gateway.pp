# @summary Configures the shared Traefik gateway.
#
# @param private_ip
#   Host-only IP address on which TCP entry points listen.
#
# @param tcp_entry_points
#   Mapping of TCP entry-point names to ports.
#
# @param certificate_name
#   Basename used for the installed wildcard certificate.
#
# @param certificate_source_crt
#   Puppet file source for the wildcard certificate.
#
# @param certificate_source_key
#   Puppet file source for the wildcard certificate private key.
class profile::gateway (
  Stdlib::IP::Address $private_ip,
  Hash[String[1], Stdlib::Port] $tcp_entry_points,
  String[1] $certificate_name,
  String[1] $certificate_source_crt,
  String[1] $certificate_source_key,
) {
  class { 'traefik':
    private_ip             => $private_ip,
    tcp_entry_points       => $tcp_entry_points,
    certificate_name       => $certificate_name,
    certificate_source_crt => $certificate_source_crt,
    certificate_source_key => $certificate_source_key,
  }

  contain traefik
}
