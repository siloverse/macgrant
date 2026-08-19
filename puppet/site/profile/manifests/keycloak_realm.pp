# @summary Declares the kyc realm and its identity model as code.
class profile::keycloak_kyc_realm (
  String[1] $realm,
) {
  keycloak_realm { $realm:
    ensure => present,
    roles  => ['user', 'admin'],
  }
}