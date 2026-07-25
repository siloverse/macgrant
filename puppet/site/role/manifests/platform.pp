# @summary Composes the complete local development platform.
class role::platform {
  contain profile::dns
  contain profile::gateway
  contain profile::postgres
  contain profile::redis
  contain profile::keycloak

  Class['profile::gateway'] -> Class['profile::postgres']
  Class['profile::gateway'] -> Class['profile::redis']
  Class['profile::postgres'] -> Class['profile::keycloak']
}
