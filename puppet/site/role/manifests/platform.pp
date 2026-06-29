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
  contain profile::tempo
  contain profile::opentelemetry_collector
  contain profile::node_exporter
  contain profile::prometheus
  contain profile::grafana

  Class['profile::common'] -> Class['profile::rabbitmq']
  Class['profile::common'] -> Class['profile::tempo']
  Class['profile::gateway'] -> Class['profile::postgres']
  Class['profile::gateway'] -> Class['profile::redis']
  Class['profile::gateway'] -> Class['profile::zookeeper']
  Class['profile::gateway'] -> Class['profile::rabbitmq']
  Class['profile::gateway'] -> Class['profile::opentelemetry_collector']
  Class['profile::postgres'] -> Class['profile::keycloak']

  Class['profile::tempo'] -> Class['profile::opentelemetry_collector']
  Class['profile::tempo'] -> Class['profile::prometheus']
  Class['profile::opentelemetry_collector'] -> Class['profile::prometheus']
  Class['profile::node_exporter'] -> Class['profile::prometheus']
  Class['profile::prometheus'] -> Class['profile::grafana']
}
