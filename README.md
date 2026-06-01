# Local Platform with Vagrant

This Vagrant VM runs PostgreSQL, Redis, and Keycloak on `192.168.56.10`.

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
  -cert-file .local-certs/keycloak.crt \
  -key-file .local-certs/keycloak.key \
  192.168.56.10 localhost

vagrant up
```

Open Keycloak at:

<https://192.168.56.10:8443>

Fully restart Chrome with `chrome://restart` if it still shows a certificate
warning.

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

Puppet configuration is under `puppet/site`. Local certificates are ignored
by Git; never commit `.local-certs` or mkcert's `rootCA-key.pem`.
