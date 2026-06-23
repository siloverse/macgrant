# @summary Installs packages shared by multiple platform components.
class profile::common {
  package { [
    'curl',
  ]:
    ensure => installed,
  }
}