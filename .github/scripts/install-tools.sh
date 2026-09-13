#!/usr/bin/env bash
set -euo pipefail

: "$RUNNER_TEMP" "$GITHUB_PATH"
tools_dir="$RUNNER_TEMP/sausage-tools"
mkdir -p "$tools_dir/bin" "$tools_dir/downloads"
for tool in "$@"; do
  case "$tool" in
    helm)
      archive="$tools_dir/downloads/helm-v4.3.0-linux-amd64.tar.gz"
      curl --fail --silent --show-error --location \
        https://get.helm.sh/helm-v4.3.0-linux-amd64.tar.gz --output "$archive"
      checksum="$(curl --fail --silent --show-error --location \
        https://get.helm.sh/helm-v4.3.0-linux-amd64.tar.gz.sha256sum | awk '{print $1}')"
      printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check
      tar -xzf "$archive" -C "$tools_dir/downloads" linux-amd64/helm
      install -m 0755 "$tools_dir/downloads/linux-amd64/helm" "$tools_dir/bin/helm"
      "$tools_dir/bin/helm" version --short
      ;;
    kubectl)
      binary="$tools_dir/downloads/kubectl"
      curl --fail --silent --show-error --location \
        https://dl.k8s.io/release/v1.35.1/bin/linux/amd64/kubectl --output "$binary"
      checksum="$(curl --fail --silent --show-error --location \
        https://dl.k8s.io/release/v1.35.1/bin/linux/amd64/kubectl.sha256)"
      printf '%s  %s\n' "$checksum" "$binary" | sha256sum --check
      install -m 0755 "$binary" "$tools_dir/bin/kubectl"
      "$tools_dir/bin/kubectl" version --client
      ;;
    *)
      printf 'Unsupported tool: %s\n' "$tool" >&2
      exit 1
      ;;
  esac
done
printf '%s\n' "$tools_dir/bin" >> "$GITHUB_PATH"
