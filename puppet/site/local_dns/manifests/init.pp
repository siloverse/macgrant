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
    content => @("DNSMASQ"/L),
      listen-address=127.0.0.1,${vm_ip}
      bind-interfaces

      address=/${domain}/${vm_ip}
      | DNSMASQ
  require => Package['dnsmasq'],
  notify  => Service['dnsmasq'],
  }

  service { 'dnsmasq':
    ensure  => running,
    enable  => true,
    require => Package['dnsmasq'],
  }
}