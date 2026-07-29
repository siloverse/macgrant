# Macgrant Local Platform

This repository provisions a disposable Ubuntu development VM with Vagrant
and Puppet. It runs PostgreSQL, Redis, ZooKeeper, RabbitMQ, Keycloak, dnsmasq,
and Traefik on the host-only network at `192.168.56.10`.

## Prerequisites

- Vagrant
- VirtualBox
- `mkcert` and `libnss3-tools`
- `dig` and `resolvectl` for DNS troubleshooting

On Ubuntu:

```bash
sudo apt install \
  vagrant \
  virtualbox \
  mkcert \
  libnss3-tools \
  dnsutils
```

## Certificates

Create the browser-trusted wildcard certificate before starting the VM:

```bash
mkcert -install
mkdir -p .local-certs

mkcert \
  -cert-file .local-certs/macgrant-platform.test.crt \
  -key-file .local-certs/macgrant-platform.test.key \
  "macgrant-platform.test" \
  "*.macgrant-platform.test"
```

The Vagrant certificate preflight stops provisioning with a clear error when
either required file is missing. Puppet copies the files into
`/etc/traefik/certs`, and Traefik loads them through its watched
`/etc/traefik/dynamic/tls.yml` file.

Everything under `.local-certs/` is ignored by Git. Never commit a certificate
private key or mkcert's `rootCA-key.pem`.

## Start The Platform

```bash
vagrant up
```

Provisioning runs in this order:

1. Configure GRUB for unattended boots.
2. Check that the wildcard certificate and key exist.
3. Install Puppet 8 when needed.
4. Install the pinned Forge module dependencies into `puppet/modules`.
5. Install and verify the pinned Traefik binary.
6. Apply `puppet/manifests/default.pp`.
7. Configure host-side split DNS after the VM starts.

Vagrant allows up to 10 minutes for the VM to boot. The GRUB provisioner
selects the first Ubuntu entry, clears an existing failed-boot marker, and
sets two-second menu and failed-boot timeouts. This prevents a previous failed
or forced shutdown from leaving a headless `vagrant up` waiting at the GRUB
menu. The settings are stored in
`/etc/default/grub.d/99-vagrant-autoboot.cfg`.

The VM uses:

```text
Box:         bento/ubuntu-24.04
Hostname:    macgrant-platform
VM IP:       192.168.56.10
Host IP:     192.168.56.1
Domain:      macgrant-platform.test
```

## Service Endpoints

| Service | Endpoint |
| --- | --- |
| Keycloak | <https://keycloak.macgrant-platform.test> |
| Keycloak issuer | <https://keycloak.macgrant-platform.test/realms/master> |
| PostgreSQL | `jdbc:postgresql://postgres.macgrant-platform.test:5432/keycloak` |
| Redis | `redis://redis.macgrant-platform.test:6379` |
| ZooKeeper | `zookeeper.macgrant-platform.test:2181` |
| ZooKeeper AdminServer | <https://zookeeper.macgrant-platform.test/commands> |
| RabbitMQ AMQP | `amqp://admin:admin@rabbitmq.macgrant-platform.test:5672/macgrant` |
| RabbitMQ management | <https://rabbitmq.macgrant-platform.test> |

Keycloak uses edge TLS termination:

```text
client -> HTTPS :443 -> Traefik -> HTTP 127.0.0.1:8080 -> Keycloak
```

PostgreSQL, Redis, and ZooKeeper remain bound to loopback. Traefik deliberately
exposes their native TCP ports only on the VM's host-only address:

```text
postgres.macgrant-platform.test:5432
  -> 192.168.56.10:5432 (Traefik)
  -> 127.0.0.1:5432 (PostgreSQL)

redis.macgrant-platform.test:6379
  -> 192.168.56.10:6379 (Traefik)
  -> 127.0.0.1:6379 (Redis)

zookeeper.macgrant-platform.test:2181
  -> 192.168.56.10:2181 (Traefik)
  -> 127.0.0.1:2181 (ZooKeeper)

rabbitmq.macgrant-platform.test:5672
  -> 192.168.56.10:5672 (Traefik)
  -> 127.0.0.1:5672 (RabbitMQ)
```

This keeps the services off the VM's other interfaces while preserving their
native client protocols. ZooKeeper's AdminServer stays on loopback at
`127.0.0.1:8081`, and RabbitMQ's management UI stays on loopback at
`127.0.0.1:15672`; Traefik exposes both as trusted HTTPS at the endpoints
above. Inside the VM, `/etc/hosts` maps the service names to `127.0.0.1`, so
local clients bypass Traefik.

## ZooKeeper

`profile::zookeeper` configures a standalone ZooKeeper node. It installs the
Ubuntu `zookeeperd` package and `libjetty9-java`; the managed
`/etc/default/zookeeper` classpath enables ZooKeeper's Jetty-based AdminServer.
Puppet manages `/etc/zookeeper/conf/zoo.cfg` and the data directory
`/var/lib/zookeeper` (owned by `zookeeper`). It also removes the package's
placeholder `myid` file because a standalone node has no server ID.

The default configuration listens only on loopback for both the native client
protocol (`127.0.0.1:2181`) and AdminServer HTTP (`127.0.0.1:8081`). It keeps
three snapshots, purges old snapshots every 24 hours, and permits only the
`ruok`, `srvr`, `stat`, and `mntr` four-letter commands. Traefik makes the
client protocol available at the ZooKeeper endpoint and publishes the
AdminServer over HTTPS.

For a quick health check from the host:

```bash
curl -fsS https://zookeeper.macgrant-platform.test/commands/ruok
```

## RabbitMQ

`profile::rabbitmq` installs RabbitMQ from Team RabbitMQ's `amd64` APT
repositories. The RabbitMQ server package and Erlang package family are pinned
to the versions declared in `data/versions.yaml`; the current defaults are
RabbitMQ `4.3.4-1` and Erlang `1:27.*`. Puppet also enables the management
plugin and keeps the service enabled and running.

AMQP listens only on `127.0.0.1:5672`, while the management UI listens only on
`127.0.0.1:15672`. Traefik exposes AMQP through its host-only `rabbitmq` TCP
entry point and publishes the management UI over trusted HTTPS.

The disposable development account is `admin` with password `admin`. It has
administrator privileges and full permissions on the `macgrant` vhost. Puppet
removes RabbitMQ's default `guest` account after configuring this account.
Change the values under `profile::rabbitmq` in `data/common.yaml` if different
local credentials or a different vhost are required.

## DNS

The `profile::dns` class manages dnsmasq and renders
`/etc/dnsmasq.d/macgrant-platform.conf` from EPP:

```text
*.macgrant-platform.test -> 192.168.56.10
```

dnsmasq listens on `127.0.0.1` and `192.168.56.10`. The Vagrant host trigger
runs `scripts/configure-host-dns.sh`, discovers the interface containing
`192.168.56.1`, and configures systemd-resolved with:

```text
~macgrant-platform.test -> 192.168.56.10
```

No VirtualBox interface name is hard-coded.

## Puppet Architecture

The entry manifest contains only:

```puppet
include role::platform
```

`role::platform` contains seven profiles:

- `profile::dns`
- `profile::gateway`
- `profile::postgres`
- `profile::redis`
- `profile::keycloak`
- `profile::zookeeper`
- `profile::rabbitmq`

Profiles compose Forge modules and declare each service's routing intent.
The generic `traefik` module owns the gateway user, directories, certificates,
static configuration, dynamic-route format, systemd unit, and service.

Environment values live in `data/vagrant.yaml`; pinned package versions live
in `data/versions.yaml`; intentionally committed disposable-development
credentials live in `data/common.yaml`. Vagrant 2.4 uploads `hiera.yaml` for
the Puppet provisioner, so its data directory points at the shared
`/vagrant/data` directory.

Downloaded Forge modules are separate from site code:

```text
puppet/site     private role, profiles, and Traefik component
puppet/modules  downloaded Forge modules, ignored by Git
```

The private modules are intentionally minimal and are not independent PDK
projects. Do not generate PDK scaffolding in `puppet/site`.

## Add An HTTP Service

Declare the route in the profile that owns the service:

```puppet
traefik::http_route { 'example-api':
  hostname => 'api.macgrant-platform.test',
  target   => 'http://127.0.0.1:9000',
  tls      => true,
}
```

The shared type sanitizes the resource title and writes
`/etc/traefik/dynamic/example-api.yml`. Traefik watches the directory, so
dynamic route changes do not restart the gateway.

Use `insecure_skip_verify => true` only for an HTTPS backend whose development
certificate cannot be verified.

## Route To A Host Service

A service running on the development host can be reached from the VM through
the VirtualBox host-only address:

```puppet
traefik::http_route { 'host-api':
  hostname => 'host-api.macgrant-platform.test',
  target   => 'http://192.168.56.1:3000',
  tls      => true,
}
```

Bind the host process specifically to `192.168.56.1:3000` and allow that
host-only interface through the host firewall. Do not expose the development
service on public interfaces.

## Development Workflow

Apply all provisioners:

```bash
vagrant provision
```

Apply only Puppet after changing manifests, templates, or Hiera data:

```bash
vagrant provision --provision-with puppet
```

Access the VM:

```bash
vagrant ssh
```

Fully recreate the environment:

```bash
vagrant destroy -f
vagrant up
```

The certificates remain local and must exist before `vagrant up`.

## Validation

Run shell and Vagrant syntax checks on the host:

```bash
/opt/vagrant/embedded/bin/ruby -c Vagrantfile
bash -n scripts/*.sh
vagrant validate
```

Run Puppet validation with Puppet 8 in the VM:

```bash
find /vagrant/puppet/manifests /vagrant/puppet/site \
  -type f \
  -name '*.pp' \
  -print0 |
  xargs -0 /opt/puppetlabs/bin/puppet parser validate

find /vagrant/puppet/site \
  -type f \
  -name '*.epp' \
  -print0 |
  xargs -0 /opt/puppetlabs/bin/puppet epp validate
```

Apply directly inside the VM when diagnosing Vagrant integration:

```bash
sudo /opt/puppetlabs/bin/puppet apply \
  --hiera_config=/vagrant/hiera.yaml \
  --modulepath=/vagrant/puppet/site:/vagrant/puppet/modules \
  /vagrant/puppet/manifests/default.pp
```

`pdk validate` is only appropriate inside a separately managed PDK/Forge
module. It is intentionally not required for these private site modules.

## Development Credentials

These credentials are committed only for the disposable local VM:

| Service | Username | Password |
| --- | --- | --- |
| Keycloak admin | `admin` | `changeme` |
| PostgreSQL admin | `postgres` | `123123` |
| Redis | - | `secret` |
| Keycloak database | `keycloak_user` | `keycloak_password` |
| TinyURL database | `tinyurl_user` | `tinyurl_password` |

Do not reuse them outside local development.

## Troubleshooting

Check VM and service status:

```bash
vagrant status
vagrant ssh -c \
  "systemctl is-active dnsmasq postgresql redis zookeeper keycloak traefik"
```

Check DNS:

```bash
dig @192.168.56.10 anything.macgrant-platform.test +short
resolvectl query keycloak.macgrant-platform.test
```

Check trusted HTTPS and the Keycloak issuer:

```bash
curl -I https://keycloak.macgrant-platform.test
curl -fsS \
  https://keycloak.macgrant-platform.test/realms/master/.well-known/openid-configuration |
  jq -r .issuer
curl -fsS https://zookeeper.macgrant-platform.test/commands/ruok
```

Inspect Traefik:

```bash
vagrant ssh -c "sudo cat /etc/traefik/traefik.yml"
vagrant ssh -c "sudo ls -l /etc/traefik/dynamic"
vagrant ssh -c "sudo journalctl -u traefik -n 100 --no-pager"
```

Re-run the host DNS trigger logic manually when necessary:

```bash
scripts/configure-host-dns.sh \
  192.168.56.10 \
  192.168.56.1 \
  macgrant-platform.test
```
