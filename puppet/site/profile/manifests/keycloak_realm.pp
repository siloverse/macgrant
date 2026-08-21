# @summary Declares the kyc realm and its identity model as code.
class profile::keycloak_realm (
  String[1] $realm,
  Hash[String[1], String[1]] $service_clients,
  String[1] $test_user,
  String[1] $test_user_password,
  String[1] $test_user_firstname,
  String[1] $test_user_lastname
) {
  keycloak_realm { $realm:
    ensure => present,
    roles  => ['customer', 'employee', 'system'],
  }

  $service_clients.each |String $client_id, String $secret| {
    keycloak_client { $client_id:
      realm                        => $realm,
      ensure                       => present,
      public_client                => false,
      service_accounts_enabled     => true,
      standard_flow_enabled        => false,
      implicit_flow_enabled        => false,
      direct_access_grants_enabled => false,
      secret                       => $secret,
      default_client_scopes        => ['basic', 'roles'],
    }

    keycloak_role_mapping { "service-account-${client_id}":
      realm       => $realm,
      name        => "service-account-${client_id}",
      realm_roles => ['system'],
    }
  }


  exec { 'auth-silo-sa-manage-users':
    command => join([
      '/opt/keycloak/bin/kcadm-wrapper.sh add-roles', "-r ${realm}",
      '--uusername service-account-auth-silo',
      '--cclientid realm-management',
      '--rolename manage-users',
      '--rolename view-realm',
    ], ' '),
    unless  => join([
      '/opt/keycloak/bin/kcadm-wrapper.sh get-roles', "-r ${realm}",
      '--uusername service-account-auth-silo',
      '--cclientid realm-management | grep -q view-realm',
    ], ' '),
    require => Keycloak_client['auth-silo'],
  }

  keycloak_client { 'web-cli':
    realm                        => $realm,
    ensure                       => present,
    public_client                => true,
    direct_access_grants_enabled => true,
    standard_flow_enabled        => false,
    implicit_flow_enabled        => false,
    default_client_scopes        => ['basic', 'profile', 'email', 'roles'],
  }

  keycloak::partial_import { 'kyc-test-user':
    realm              => $realm,
    if_resource_exists => 'SKIP',
    content            => stdlib::to_json({
      'users' => [{
        'username'      => $test_user,
        'enabled'       => true,
        'email'         => "${test_user}@macgrant-platform.test",
        'emailVerified' => true,
        'credentials'   => [{ 'type' => 'password', 'value' => $test_user_password, 'temporary' => false }],
        'realmRoles'    => ['customer'],
        'firstName'     => $test_user_firstname,
        'lastName'      => $test_user_lastname,
      }],
    }),
  }
}