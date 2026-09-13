#!/usr/bin/env bash
set -euo pipefail

: "$RUNNER_TEMP" "$SAUSAGE_STORE_NAMESPACE"
test -n "$POSTGRES_PASSWORD"
test -n "$MONGODB_PASSWORD"
umask 077
credentials_dir="$(mktemp -d "$RUNNER_TEMP/sausage-db-secrets.XXXXXX")"
export SAUSAGE_CREDENTIALS_DIR="$credentials_dir"
trap 'rm -rf "$credentials_dir"' EXIT
python3 - <<'PY'
import os
from pathlib import Path
from urllib.parse import quote

path = Path(os.environ["SAUSAGE_CREDENTIALS_DIR"])
postgres_password = os.environ["POSTGRES_PASSWORD"]
mongo_password = os.environ["MONGODB_PASSWORD"]
uri = (
    "mongodb://" + quote("root", safe="") + ":" + quote(mongo_password, safe="")
    + "@mongodb:27017/sausage-store?authSource=admin"
)
(path / "postgres-password").write_text(postgres_password)
(path / "mongo-password").write_text(mongo_password)
(path / "mongo-uri").write_text(uri)
PY

kubectl create secret generic postgresql-credentials \
  --namespace "$SAUSAGE_STORE_NAMESPACE" \
  --from-literal=database=sausage-store --from-literal=username=store \
  --from-file="password=$credentials_dir/postgres-password" \
  --dry-run=client -o yaml |
  kubectl apply --namespace "$SAUSAGE_STORE_NAMESPACE" -f -

kubectl create secret generic mongodb-credentials \
  --namespace "$SAUSAGE_STORE_NAMESPACE" --from-literal=username=root \
  --from-file="password=$credentials_dir/mongo-password" \
  --from-file="uri=$credentials_dir/mongo-uri" \
  --dry-run=client -o yaml |
  kubectl apply --namespace "$SAUSAGE_STORE_NAMESPACE" -f -
