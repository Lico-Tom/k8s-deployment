#!/usr/bin/env bash
# 卸载 release（保留命名空间）
# 用法: ./scripts/uninstall.sh <env> [namespace] [release-name]
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CHART_DIR"

HELM_BIN="${HELM_BIN:-helm}"

ENV="${1:-}"
NAMESPACE="${2:-$ENV}"
RELEASE_NAME="${3:-api}"

if [ -z "$ENV" ]; then
  echo "用法: ./scripts/uninstall.sh <dev|staging|prod> [namespace] [release-name]" >&2
  exit 1
fi

echo "==> 卸载 release=${RELEASE_NAME} namespace=${NAMESPACE}"
"$HELM_BIN" uninstall "$RELEASE_NAME" --namespace "$NAMESPACE" --wait

echo "==> 检查残留"
kubectl get pods -n "$NAMESPACE" | grep -c "$RELEASE_NAME" || echo "  无残留 Pod"
