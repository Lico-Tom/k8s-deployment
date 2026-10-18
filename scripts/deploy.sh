#!/usr/bin/env bash
# 部署/升级到指定环境
# 用法: ./scripts/deploy.sh <env> [namespace] [release-name]
#   ./scripts/deploy.sh dev
#   ./scripts/deploy.sh prod prod api
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CHART_DIR"

HELM_BIN="${HELM_BIN:-helm}"

ENV="${1:-}"
NAMESPACE="${2:-$ENV}"
RELEASE_NAME="${3:-api}"

if [ -z "$ENV" ]; then
  echo "用法: ./scripts/deploy.sh <dev|staging|prod> [namespace] [release-name]" >&2
  exit 1
fi

VALUES_FILE="environments/values-${ENV}.yaml"
if [ ! -f "$VALUES_FILE" ]; then
  echo "错误: 环境配置不存在 -> $VALUES_FILE" >&2
  exit 1
fi

if ! command -v "$HELM_BIN" >/dev/null 2>&1; then
  echo "错误: 未找到 helm，请先安装或设置 HELM_BIN=/path/to/helm" >&2
  exit 127
fi

echo "==> 前置检查"
"$HELM_BIN" lint . --values "$VALUES_FILE"

echo "==> 部署 release=${RELEASE_NAME} namespace=${NAMESPACE} env=${ENV}"
"$HELM_BIN" upgrade --install "$RELEASE_NAME" . \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values "$VALUES_FILE" \
  --atomic \
  --timeout 5m \
  --wait \
  --history-max 10 || {
    echo "==> 部署失败，回滚到上一版本" >&2
    "$HELM_BIN" rollback "$RELEASE_NAME" --namespace "$NAMESPACE" || true
    exit 1
  }

echo "==> 当前状态"
"$HELM_BIN" status "$RELEASE_NAME" --namespace "$NAMESPACE"
