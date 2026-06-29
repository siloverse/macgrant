# @summary Manages packages and cache directories shared by platform components.
class profile::common {
  package { [
    'curl',
    'ca-certificates',
    'unzip',
  ]:
    ensure => installed,
  }

  file { '/var/cache/macgrant':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/var/cache/macgrant/packages':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/var/cache/macgrant'],
  }
}
