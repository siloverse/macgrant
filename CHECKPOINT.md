# CHECKPOINT — macgrant local platform

_Last updated: 2026-08-20. This document is the arbiter: if Claude asserts something about this repo that isn't here or visible in the code, call it — that's drift._

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

- Done & verified: confidential clients (client_credentials tokens mint for all three), explicit `default_client_scopes => ['basic','roles']`, `web-cli` public client + test user `awais` (password-grant token verified).
- Still to do: `manage-users` grant to auth-silo's service account (kcadm exec; `keycloak_role_mapping` only does realm roles on users), `user_silo`/`notification_silo` databases.

### Phase 1 lessons (Reflect answers, 2026-08-19/20)

- **Claims are mapper output, not facts.** Clients start with NO scopes under the treydock provider (declarative completeness) → near-naked tokens (`scope: ""`, no roles claim). Claims appear only when a client scope's protocol mappers put them there.
- **Service vs user token, field by field:** `sub` = SA-user UUID vs person UUID; `azp` = the client (auth-silo vs web-cli — tool, not identity); profile claims exist only for humans AND only with profile/email scopes; `sid` only for user logins (SSO session); `aud: account` appeared on the SA token via the roles scope's audience-resolve mapper (composite default role → account client roles), absent on the user token (import set exactly `realmRoles: ["user"]`, no default composite).
- **`scope` claim ≠ assigned scopes:** `basic`/`roles` have include-in-token-scope OFF (mapper bundles, not OAuth scopes); `profile email` show up because theirs is ON.
- **OIDC standard claims are flat and top-level** (interop); `realm_access`/`resource_access` are Keycloak-specific nesting — the exact reason Phase 2 needs a hand-written JwtAuthenticationConverter.
- **`partial_import` with SKIP is create-only** — it does not converge drift (unlike the realm/client types). Paid for it: user created without firstName/lastName → password grant refused with `invalid_grant: Account is not fully set up` (direct grant has no UI for required actions; KC 26 user profile requires first/last name). Fix required deleting the user and re-importing.

## Parked

- **dnsmasq leaks VM-internal loopback answers to the host** — the `host { ... ip => '127.0.0.1' }` blocks in service profiles feed dnsmasq (reads /etc/hosts by default), so the host resolves postgres/redis/zookeeper/rabbitmq/otel hostnames to its own loopback. WILL bite Phase 4/5 (host-side JDBC/AMQP). Fix: `no-hosts` in dnsmasq config; VM-local resolution keeps working via nsswitch (`files` first).
- Grafana placeholder `admin_password` + `secret_key` in common.yaml (plan task 8.4).
- siloverse-build: `io.spring.dependency-management` in the spring-boot-application convention breaks Gradle's configuration cache (pom.withXml captures Project) and is redundant — the platform already imports the Boot BOM. Fix = delete it, bump 1.10.1.
- Vagrantfile literals `config.vm.hostname` and cert-preflight paths could derive from `macgrant::domain`; left as-is (YAGNI — revisit only if the domain ever changes).
- **`Keycloak_client[...]/secret: created secret` fires on EVERY provision — known, accepted.** Mechanism: the treydock provider only reads a client's secret when the client JSON has no `name` field (heuristic to skip built-in clients), but KC 26.5 returns `name` = clientId for module-created clients, so the secret is never read, current=absent, and Puppet re-PUTs the same hiera value each run. Harmless (converges, auto-corrects drift) but noisy — this resource is exempt from the "zero-change run = behavior-neutral" test. Revisit: check newer treydock releases for a fixed heuristic before ever patching the vendored module.
