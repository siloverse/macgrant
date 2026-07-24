$domain = $facts['macgrant_domain']
$vm_ip  = $facts['macgrant_vm_ip']

class { 'traefik':
  private_ip => $vm_ip,
}

class { 'redis_server':
  hostname => "redis.${domain}",
  require  => Class['traefik'],
}

include local_dns
include postgres
include keycloak_server
