#!/usr/bin/env bash
set -euo pipefail

: "$SAUSAGE_STORE_NAMESPACE" "$PRODUCTION_URL" "$GITHUB_SHA" "$RUNNER_TEMP"
for component in backend frontend backend-report; do
  kubectl rollout status "deployment/sausage-store-$component" \
    --namespace "$SAUSAGE_STORE_NAMESPACE" --timeout=10m
done
for database in postgresql mongodb; do
  kubectl rollout status "statefulset/$database" \
    --namespace "$SAUSAGE_STORE_NAMESPACE" --timeout=10m
done

healthy=false
for attempt in $(seq 1 24); do
  if response="$(kubectl exec deployment/sausage-store-backend \
      --namespace "$SAUSAGE_STORE_NAMESPACE" -- \
      curl --fail --silent --show-error http://127.0.0.1:8080/actuator/health)" &&
      printf '%s' "$response" | python3 -c \
        'import json,sys; assert json.load(sys.stdin)["status"] == "UP"'; then
    healthy=true
    break
  fi
  sleep 5
done
test "$healthy" = true
printf 'Backend health: UP\n'

kubectl exec statefulset/mongodb --namespace "$SAUSAGE_STORE_NAMESPACE" -- \
  mongosh --quiet --eval \
  'db=db.getSiblingDB("admin"); if(!db.auth(process.env.MONGO_INITDB_ROOT_USERNAME,process.env.MONGO_INITDB_ROOT_PASSWORD))quit(1); if(!db.adminCommand({ping:1}).ok)quit(1); print("MongoDB authentication: OK");'

kubectl exec deployment/sausage-store-frontend \
  --namespace "$SAUSAGE_STORE_NAMESPACE" -- \
  wget -qO- http://sausage-store-backend-report-service:8080/api/v1/health >/dev/null
printf 'Backend-report health: OK\n'

migrations="$(kubectl exec statefulset/postgresql \
  --namespace "$SAUSAGE_STORE_NAMESPACE" -- psql -U store -d sausage-store -Atc \
  "SELECT count(*) FROM flyway_schema_history WHERE success AND version IN ('001','002','003','004');")"
test "$migrations" = 4
printf 'Flyway V001-V004: four successful migrations\n'
kubectl logs deployment/sausage-store-backend \
  --namespace "$SAUSAGE_STORE_NAMESPACE" --tail=500 \
  | python3 .github/scripts/redact-logs.py \
  | grep -E 'Started SausageApplication|DbMigrate|DbValidate|Initialized JPA EntityManagerFactory'

curl --fail --silent --show-error --head --retry 12 --retry-all-errors \
  --retry-delay 5 --connect-timeout 10 --max-time 30 "$PRODUCTION_URL/"
curl --fail --silent --show-error --retry 12 --retry-all-errors \
  --retry-delay 5 --connect-timeout 10 --max-time 30 \
  --output "$RUNNER_TEMP/products.json" "$PRODUCTION_URL/api/products"
python3 - <<'PY'
import json, os
from pathlib import Path
products = json.loads((Path(os.environ["RUNNER_TEMP"]) / "products.json").read_text())
assert isinstance(products, list) and len(products) == 6
print("HTTPS /api/products: HTTP 200, six products")
PY

kubectl wait --for=condition=Ready pods --all \
  --namespace "$SAUSAGE_STORE_NAMESPACE" --timeout=2m
kubectl get pods --namespace "$SAUSAGE_STORE_NAMESPACE" -o json \
  > "$RUNNER_TEMP/pods.json"
python3 - <<'PY'
import json, os
from pathlib import Path
pods = json.loads((Path(os.environ["RUNNER_TEMP"]) / "pods.json").read_text())["items"]
components = set()
for pod in pods:
    if pod["metadata"].get("deletionTimestamp"):
        continue
    assert pod["status"]["phase"] == "Running", pod["metadata"]["name"]
    for status in pod["status"].get("containerStatuses", []):
        assert status["ready"] and "running" in status["state"], pod["metadata"]["name"]
    for container in pod["spec"]["containers"]:
        if container["name"] in ("backend", "frontend", "backend-report"):
            assert container["image"].endswith(":" + os.environ["GITHUB_SHA"])
            components.add(container["name"])
assert components == {"backend", "frontend", "backend-report"}
print("All Pods Running/Ready; application images use the current commit SHA")
PY

helm list --namespace "$SAUSAGE_STORE_NAMESPACE"
helm status sausage-store --namespace "$SAUSAGE_STORE_NAMESPACE"
kubectl get pods --namespace "$SAUSAGE_STORE_NAMESPACE" -o wide
kubectl get deployments,statefulsets,svc,pvc,ingress,hpa,vpa,resourcequota \
  --namespace "$SAUSAGE_STORE_NAMESPACE"
