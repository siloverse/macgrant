# @summary Configures dnsmasq for the local Macgrant development domain.
#
# @param vm_ip
#   IP address of the Vagrant virtual machine.
#
# @param domain
#   Local wildcard DNS domain resolved to the Vagrant machine.
class local_dns (
  String $vm_ip = '192.168.56.10',
  String $domain = 'macgrant-platform.test',
) {
  package { 'dnsmasq':
    ensure => installed,
  }

  file { '/etc/dnsmasq.d/macgrant-platform.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('local_dns/macgrant-platform.conf.epp', {
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
