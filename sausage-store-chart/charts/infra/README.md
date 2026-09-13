# PostgreSQL

PostgreSQL is a singleton StatefulSet with a ClusterIP Service named
`postgresql` and a separate PVC named `postgresql-data`. The PVC survives
Pod or StatefulSet recreation. It requests 1Gi with ReadWriteOnce access.
The default cluster StorageClass is used unless explicitly overridden.
The data directory is /var/lib/postgresql/data/pgdata on the mounted PVC.

The default image is postgres:14.20-alpine, compatible with the backend's
Flyway 8.0.5. Requests are 100m CPU / 128Mi memory; limits are 500m / 256Mi.
This leaves capacity for the other application components within the
namespace quota. Only one PostgreSQL Service and one PVC are created.

## Credentials

By default, provision the Secret named by global.postgresqlSecretName
(default: postgresql-credentials) externally before deploying. It needs
three keys: database, username, password. Default connection values are
database sausage-store and username store. No password is supplied in Git.

Both PostgreSQL and backend read credentials through secretKeyRef.
Backend gets its JDBC URL from backend.env.postgresUri via ConfigMap;
keep its database name consistent with the Secret's database key.

Optional Helm-managed Secret creation is available by setting
infra.postgresql.auth.createSecret=true and supplying
infra.postgresql.auth.password through an external values file or stdin.
An empty password is rejected. Do not commit that values file.

Backend application properties accept SPRING_DATASOURCE_URL,
SPRING_DATASOURCE_USERNAME and SPRING_DATASOURCE_PASSWORD. Flyway uses
that same DataSource and applies the classpath:db/migration SQL files at
application startup. The Maven Flyway plugin uses PSQL_* variables only
when explicitly invoked.

The PostgreSQL names follow the existing infra chart convention and
assume one application release per namespace. This stage only validates
the rendered chart; no cluster resources are deployed.
