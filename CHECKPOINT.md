# CHECKPOINT — macgrant local platform

_Last updated: 2026-08-19. This document is the arbiter: if Claude asserts something about this repo that isn't here or visible in the code, call it — that's drift._

**Goal:** one-VM local platform (Vagrant + Puppet + Traefik + Keycloak + observability stack) hosting the siloverse learning apps. Design constraint: exactly one machine, YAGNI throughout — this exists to learn DDD, event-driven architecture, distributed microservices/observability/CI-CD on a laptop.

## Locked decisions

- **No IP addresses in app repos (2026-08-19).** Silos keep Spring's default bind (all interfaces) and declare only their port. macgrant owns the network facts: `macgrant::domain/vm_ip/host_ip` in `data/vagrant.yaml` are the single source of truth — hiera interpolates them (`%{lookup(...)}`), the Vagrantfile reads the same file for the VM network, cert preflight, and DNS trigger. Rationale: config that varies by environment lives in the environment; the repo that owns the environment owns its facts.
- **Host split DNS is persistent config, not runtime state (2026-08-19).** `/etc/systemd/resolved.conf.d/macgrant.conf` routes `~macgrant-platform.test` → 192.168.56.10. The `resolvectl` trigger script kept dying on host reboot (runtime-only) and couldn't sudo from Vagrant triggers; the drop-in survives reboots. Trigger script retained as a harmless re-apply.
- **Committed dev credentials tolerated in `data/common.yaml`** (header says why: disposable local VM). The silo client secret that leaked into pushed silo-repo history is treated as **burned** — remedy is rotation (fresh secrets minted for realm `kyc`), never history rewrite on published branches.
- **Keycloak version pinned** (`profile::keycloak::version` in versions.yaml) like every other component; previously floated on the module default.
- **Realm `kyc` roles are declared as the complete list** (`manage_roles` semantics): `['user','admin']`. Consequence, chosen deliberately (YAGNI): Keycloak's built-in realm roles `offline_access` and `uma_authorization` are **removed**. Re-add `offline_access` if refresh-token/offline flows ever appear.
- **Identity model lives in its own profile** (`profile::keycloak_realm`), separate from the server (`profile::keycloak`): they change for different reasons and at different speeds. Ordering edge `Class['profile::keycloak'] -> Class['profile::keycloak_realm']` because the realm provider shells out to kcadm against a running server.
- **Confidential silo clients are deny-by-default**: only `service_accounts_enabled` (client_credentials) is on; standard/implicit/direct-access flows off. A client = an identity plus an explicit list of ways it may obtain tokens; every disabled flow is an attack path that doesn't exist.

## Built & green

- **Phase 0 (2026-08-19), all verifies passed:** three silos answer through Traefik TLS; the decisive check was a plain JVM `HttpClient` with default SSLContext — no PKIX failure. Learned: Ubuntu's `ca-certificates-java` bridges the system trust store into the shared `/etc/ssl/certs/java/cacerts` (symlinked by every JDK), so `mkcert -install` had already satisfied JVM trust; no keytool needed.
- **Realm `kyc` exists as code** (`profile::keycloak_realm`): discovery endpoint answers, `issuer == https://keycloak.macgrant-platform.test/realms/kyc`. Nonexistent realm → 404/`null` issuer (the shape of a typo'd `issuer-uri`).
- Single-source-of-truth refactor verified behavior-neutral: Puppet re-run applied the catalog with zero resource changes.

## In flight (Phase 1)

- Confidential clients auth-silo/user-silo/notification-silo (secrets → common.yaml) — written, not yet provisioned/verified.
- Still to do: `web-cli` public client (Direct Access Grants) + test user (via `keycloak::partial_import`; module has no user type), `manage-users` grant to auth-silo's service account (kcadm exec; `keycloak_role_mapping` only does realm roles on users), `user_silo`/`notification_silo` databases.

## Parked

- **dnsmasq leaks VM-internal loopback answers to the host** — the `host { ... ip => '127.0.0.1' }` blocks in service profiles feed dnsmasq (reads /etc/hosts by default), so the host resolves postgres/redis/zookeeper/rabbitmq/otel hostnames to its own loopback. WILL bite Phase 4/5 (host-side JDBC/AMQP). Fix: `no-hosts` in dnsmasq config; VM-local resolution keeps working via nsswitch (`files` first).
- Grafana placeholder `admin_password` + `secret_key` in common.yaml (plan task 8.4).
- siloverse-build: `io.spring.dependency-management` in the spring-boot-application convention breaks Gradle's configuration cache (pom.withXml captures Project) and is redundant — the platform already imports the Boot BOM. Fix = delete it, bump 1.10.1.
- Vagrantfile literals `config.vm.hostname` and cert-preflight paths could derive from `macgrant::domain`; left as-is (YAGNI — revisit only if the domain ever changes).
