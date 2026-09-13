# Sausage Store Helm configuration

The umbrella chart contains backend, backend-report, frontend and infra subcharts.
No credentials are generated or deployed by default. Image values are versioned
placeholders; override the three application images with published tags before
deployment. Database images are PostgreSQL 14.20 and MongoDB 7.0.14.

## Secret contracts

Provision Secrets externally in the release namespace before deployment:

| values key | Default Secret | Required keys |
| --- | --- | --- |
| global.postgresqlSecretName | postgresql-credentials | database, username, password |
| global.mongodbSecretName | mongodb-credentials | username, password, uri |

PostgreSQL database defaults to sausage-store. MongoDB username/password initialize
the bootstrap administrator in the admin authentication database on an empty
volume. The uri key is shared by backend SPRING_DATA_MONGODB_URI and report DB;
it must identify database sausage-store, contain properly percent-encoded
credentials and use authSource=admin when authenticating the bootstrap user.
Credentials must match an existing database when reusing a PVC; changing a Secret
does not rotate database passwords.

Optionally set infra.postgresql.auth.createSecret or infra.mongodb.auth.createSecret
to true and supply the corresponding auth.password through an external values
file kept outside Git. Empty passwords cause rendering to fail. The optional
MongoDB Secret template builds and escapes the URI with authSource=admin.
Never store populated password values, rendered Secrets or kubeconfig in Git.

A separate reports user is optional: Go does not require that username. The
minimal initial setup uses the bootstrap administrator. For a later restricted
application user, provision that user separately and supply its URI in the uri
key while keeping the bootstrap keys appropriate for MongoDB. No Helm hook Job
is created.

Database names, Services and MongoDB claim names retain the existing fixed names;
use one release of this chart per namespace. PostgreSQL uses a standalone 1Gi PVC,
and MongoDB uses a 1Gi ReadWriteOnce volumeClaimTemplate mounted at /data/db.
An empty persistence.storageClass uses the cluster default StorageClass.

## Routing and scaling

Backend-report listens on PORT (default 8080), read from its ConfigMap.
DB comes exclusively from a Secret. Its HTTP routes are GET /api/v1/health
and /swagger/*. No other application component calls report directly;
its ClusterIP Service provides internal access to those endpoints.
It uses Recreate and a CPU HPA with 1..2 replicas at 75% utilization.
The Deployment omits replicas while HPA is enabled to preserve HPA ownership.

Frontend has a ClusterIP Service on port 80. Its nginx ConfigMap proxies /api to
the backend Service using Kubernetes DNS. Ingress uses class nginx, host
front-dani.2sem.students-projects.ru and the existing TLS Secret
2sem-students-projects-wildcard-secret; this chart does not create that Secret.

Backend uses RollingUpdate with maxUnavailable=0 and maxSurge=1.
Unused Spring Cloud Vault auto-configuration is disabled through
backend.env.vaultEnabled=false because credentials come from Kubernetes Secrets.
backend.env.hibernateDdlAuto=validate checks the migrated PostgreSQL schema at
startup without creating or modifying application tables through Hibernate.
Liveness checks /actuator/health:8080 after 60 seconds, every 10 seconds,
with timeout 3 seconds and failureThreshold 3. VPA targets the backend Deployment
using autoscaling.k8s.io/v1 and updateMode Off. Other VPA modes are rejected.

## Resource budget

Values include CPU and memory requests and limits for all five components.
The report CPU request enables HPA utilization calculation.

| Component | CPU request | Memory request | CPU limit | Memory limit |
| --- | ---: | ---: | ---: | ---: |
| Frontend | 50m | 64Mi | 250m | 128Mi |
| Backend | 100m | 192Mi | 600m | 512Mi |
| Backend-report | 50m | 64Mi | 250m | 128Mi |
| PostgreSQL | 100m | 128Mi | 500m | 256Mi |
| MongoDB | 50m | 128Mi | 250m | 512Mi |

| Scenario | Pods | Services | PVC / storage | CPU requests | Memory requests | CPU limits | Memory limits |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| Steady state | 5 | 5 | 2 / 2Gi | 350m | 576Mi | 1850m | 1536Mi |
| Report at 2, backend surge at 2 | 7 | 5 | 2 / 2Gi | 500m | 832Mi | 2700m | 2176Mi |
| Namespace quota | 10 | 5 | 4 / 5Gi | 2000m | 1000Mi | 3000m | 2500Mi |

There are 3 application ConfigMaps and 2 external database Secrets.
Including the existing system resources gives 4 ConfigMaps and 4 database/system
Secrets. Helm additionally stores release revisions as Secrets. CI limits history
to 3 revisions, keeping the planned total at 7 Secrets (8 during an update),
below the quota of 10. The TLS Secret is already among the system Secrets.
The maximum planned rollout leaves 168Mi of memory request headroom.
The calculation covers desired HPA replicas plus the configured backend surge;
terminating Pods awaiting deletion can briefly retain quota, so a rollout may
wait for their removal. Resource budgets must be recalculated if values change.

## Validation without deployment

Run helm lint sausage-store-chart and helm template sausage-store
sausage-store-chart --namespace r-devops-magistracy-project-2sem-856756022.
Default rendering does not require credentials. Validate the rendered manifests
against Kubernetes schemas or use kubectl apply --dry-run=client; neither command
deploys the application. VPA requires the installed autoscaling.k8s.io/v1 CRD,
and HPA requires the CPU metrics API when actually deployed.

## Production CI/CD

Production URL: https://front-dani.2sem.students-projects.ru

Namespace: r-devops-magistracy-project-2sem-856756022

The [deploy workflow](../.github/workflows/deploy.yaml) runs on pushes to main
and can also be started with workflow_dispatch. A shared concurrency group
prevents simultaneous production pipelines.

1. build_and_push_to_docker_hub builds and publishes all three images with the
   immutable source tag GITHUB_SHA:
   DOCKERHUB_USERNAME/sausage-backend:GITHUB_SHA,
   DOCKERHUB_USERNAME/sausage-frontend:GITHUB_SHA and
   DOCKERHUB_USERNAME/sausage-backend-report:GITHUB_SHA.
   Backend VERSION is also set to GITHUB_SHA.
2. add_helm_chart_to_nexus validates the local subcharts, runs strict lint and
   template checks, then packages chart version 0.RUN_NUMBER.RUN_ATTEMPT with
   appVersion GITHUB_SHA. The unique package is uploaded with HTTP Basic Auth
   to the hosted Nexus Helm repository dani-sausage-store:
   https://nexus.cloud-services-engineer.education-services.ru/repository/dani-sausage-store/
3. deploy_helm_chart_to_kubernetes writes the raw YAML KUBE_CONFIG to a private
   runner temporary file, checks namespace access and the existing TLS Secret,
   and creates or updates the two external database Secrets. It builds the
   MongoDB URI with URL-encoded credentials and authSource=admin.
   Helm refreshes the authenticated nexus repository, checks the exact chart
   version, and deploys nexus/sausage-store with SHA images, --wait,
   --timeout 10m and --history-max 3. It retains failed deployment resources
   for diagnosis.

All credential values are supplied by GitHub Actions Secrets:
DOCKERHUB_USERNAME, DOCKERHUB_TOKEN, KUBE_CONFIG, POSTGRES_PASSWORD,
MONGODB_PASSWORD, NEXUS_HELM_REPO, NEXUS_HELM_REPO_USER and
NEXUS_HELM_REPO_PASSWORD. They are absent from chart values and repository files.
Temporary credential files and runner kubeconfig are removed after use.
Database passwords must continue to match persisted databases on later runs.

Post-deployment checks verify all five rollouts, backend health UP, MongoDB
authentication, backend-report health, successful Flyway V001-V004 history,
Running/Ready Pods with SHA images, HTTPS and six products from /api/products.
Failure diagnostics include Helm status, Events and filtered container logs.
