# @summary Composes the complete local development platform.
class role::platform {
  contain profile::common
  contain profile::dns
  contain profile::gateway
  contain profile::postgres
  contain profile::redis
  contain profile::keycloak
  contain profile::zookeeper
  contain profile::rabbitmq
  include profile::tempo
  Class['profile::common'] -> Class['profile::rabbitmq']
  Class['profile::common'] -> Class['profile::tempo']
  Class['profile::gateway'] -> Class['profile::postgres']
  Class['profile::gateway'] -> Class['profile::redis']
  Class['profile::gateway'] -> Class['profile::zookeeper']
  Class['profile::gateway'] -> Class['profile::rabbitmq']
  Class['profile::postgres'] -> Class['profile::keycloak']
}
