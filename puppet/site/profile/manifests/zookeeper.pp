# @summary Configures ZooKeeper and exposes its client and AdminServer endpoints through Traefik.
#
# @param hostname
#   DNS hostname used by applications and for the ZooKeeper AdminServer HTTP route.
#   Example: `zookeeper.macgrant-platform.test`.
#
# @param client_address
#   IP address on which ZooKeeper listens for client connections.
#   Use `127.0.0.1` when ZooKeeper should only be reachable through Traefik.
#
# @param client_port
#   TCP port used by applications to connect to ZooKeeper.
#   The standard ZooKeeper client port is `2181`.
#
# @param data_dir
#   Absolute directory where ZooKeeper stores snapshots and transaction logs.
#   Example: `/var/lib/zookeeper`.
#
# @param admin_address
#   IP address on which the ZooKeeper AdminServer listens.
#   Use `127.0.0.1` to prevent direct external access.
#
# @param admin_port
#   HTTP port used by the ZooKeeper AdminServer.
#   This must not conflict with other services in the VM.
#
# @param route_entry_point
#   Name of the Traefik TCP entry point that exposes the ZooKeeper client port.
#   Example: `zookeeper`.
#
class profile::zookeeper (
  Stdlib::Host $hostname,
  Stdlib::IP::Address $client_address,
  Stdlib::Port $client_port,
  Stdlib::Absolutepath $data_dir,
  Stdlib::IP::Address $admin_address,
  Stdlib::Port $admin_port,
  String[1] $route_entry_point,
) {
  package { 'zookeeperd':
    ensure => installed,
  }

  package { 'libjetty9-java':
    ensure  => installed,
    require => Package['zookeeperd'],
  }

  file { '/etc/default/zookeeper':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/zookeeper-default.epp'),
    require => [
      Package['zookeeperd'],
      Package['libjetty9-java'],
    ],
    notify  => Service['zookeeper'],
  }

  file { $data_dir:
    ensure  => directory,
    owner   => 'zookeeper',
    group   => 'zookeeper',
    mode    => '0750',
    require => Package['zookeeperd'],
  }
  # The Ubuntu package creates a placeholder myid file.
  # Standalone ZooKeeper does not require a server ID.
  file { "${data_dir}/myid":
    ensure  => absent,
    require => [
      Package['zookeeperd'],
      File[$data_dir],
    ],
    before  => Service['zookeeper'],
  }

  file { '/etc/zookeeper/conf/zoo.cfg':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/zoo.cfg.epp', {
        'client_address' => $client_address,
        'client_port'    => $client_port,
        'data_dir'       => $data_dir,
        'admin_address'  => $admin_address,
        'admin_port'     => $admin_port,
    }),
    require => [
      Package['zookeeperd'],
      File[$data_dir],
    ],
    notify  => Service['zookeeper'],
  }

  service { 'zookeeper':
    ensure  => running,
    enable  => true,
    require => [
      Package['zookeeperd'],
      Package['libjetty9-java'],
      File['/etc/zookeeper/conf/zoo.cfg'],
      File['/etc/default/zookeeper'],
    ],
  }

  # Services inside the VM connect directly to ZooKeeper.
  host { $hostname:
    ensure => present,
    ip     => '127.0.0.1',
  }

  traefik::tcp_route { 'zookeeper':
    entry_point => $route_entry_point,
    target      => "${client_address}:${client_port}",
  }

  traefik::http_route { 'zookeeper-admin':
    hostname => $hostname,
    target   => "http://${admin_address}:${admin_port}",
    tls      => true,
  }

  Service['zookeeper'] -> Traefik::Tcp_route['zookeeper']
  Service['zookeeper'] -> Traefik::Http_route['zookeeper-admin']
}
