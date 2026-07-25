# Local Platform with Vagrant

This Vagrant VM hosts PostgreSQL, Redis, Keycloak, local DNS, and Traefik. Its
private IP address is `192.168.56.10`.

## Prerequisites

- Vagrant
- VirtualBox
- `mkcert` and `libnss3-tools`

On Ubuntu:

```bash
sudo apt install vagrant virtualbox mkcert libnss3-tools
```

## Setup

Create a browser-trusted certificate before starting the VM:

```bash
mkcert -install
mkdir -p .local-certs
mkcert \
  -cert-file .local-certs/macgrant-platform.test.crt \
  -key-file .local-certs/macgrant-platform.test.key \
  "macgrant-platform.test" \
  "*.macgrant-platform.test"

vagrant up
```

## Service Endpoints

Use the same service hostnames from the host machine and from within the VM:

| Service | Endpoint |
| --- | --- |
| Keycloak | <https://keycloak.macgrant-platform.test> |
| PostgreSQL | `postgres.macgrant-platform.test:5432` |
| Redis | `redis.macgrant-platform.test:6379` |

Fully restart Chrome with `chrome://restart` if it still shows a certificate
warning.

## Network Architecture

### Local DNS

The `local_dns` Puppet module runs `dnsmasq` in the VM. It resolves every
hostname under `macgrant-platform.test` to the VM's private IP:

```text
*.macgrant-platform.test -> 192.168.56.10
```

The Vagrant host trigger configures the host's resolver to send queries for
this domain to `dnsmasq`. Inside the VM, explicit `/etc/hosts` entries map the
PostgreSQL and Redis hostnames to `127.0.0.1`, allowing VM services to connect
to them directly with the same names used from the host.

### Traefik

PostgreSQL, Redis, and Keycloak bind to the VM's loopback interface. Binding to
loopback means the processes listen on `127.0.0.1` and cannot be reached
directly from the host. Traefik accepts host connections through the VM's
private interface and proxies them to these loopback listeners:

```text
keycloak.macgrant-platform.test:443 -> Traefik -> 127.0.0.1:8443
postgres.macgrant-platform.test:5432 -> Traefik -> 127.0.0.1:5432
redis.macgrant-platform.test:6379    -> Traefik -> 127.0.0.1:6379
```

Traefik terminates HTTPS for Keycloak. PostgreSQL and Redis use plain TCP
proxying. Connections to PostgreSQL or Redis from within the VM resolve
directly to `127.0.0.1` and bypass Traefik.

## Development Credentials

| Service | Username | Password |
| --- | --- | --- |
| Keycloak admin | `admin` | `changeme` |
| PostgreSQL admin | `postgres` | `123123` |
| Redis | - | `secret` |
| Keycloak database | `keycloak_user` | `keycloak_password` |
| TinyURL database | `tinyurl_user` | `tinyurl_password` |

These credentials and certificates are for local development only.

## Useful Commands

```bash
vagrant provision             # Apply configuration changes
vagrant ssh                   # Open a shell in the VM
vagrant halt                  # Stop the VM
vagrant destroy -f            # Delete the VM
```

## Puppet Modules

Modules under `puppet/site` are intentionally minimal private modules, not
independent PDK projects. Their runtime configuration remains in `manifests`
and `templates`.

Forge dependencies are downloaded by `scripts/install-puppet-modules.sh` into
the ignored `puppet/modules` directory. The environment is validated through
Puppet parsing and actual Vagrant provisioning.

Local certificates are ignored by Git; never commit `.local-certs` or mkcert's
`rootCA-key.pem`.
