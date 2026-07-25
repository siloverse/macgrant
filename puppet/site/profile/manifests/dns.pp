# @summary Configures wildcard DNS for the local development domain.
#
# @param vm_ip
#   IP address of the Vagrant virtual machine.
#
# @param domain
#   Local wildcard DNS domain resolved to the Vagrant machine.
class profile::dns (
  Stdlib::IP::Address $vm_ip,
  String[1] $domain,
) {
  package { 'dnsmasq':
    ensure => installed,
  }

  file { '/etc/dnsmasq.d/macgrant-platform.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/dnsmasq.conf.epp', {
      'vm_ip'  => $vm_ip,
      'domain' => $domain,
    }),
    require => Package['dnsmasq'],
    notify  => Service['dnsmasq'],
  }

  service { 'dnsmasq':
    ensure  => running,
    enable  => true,
    require => Package['dnsmasq'],
  }
}
