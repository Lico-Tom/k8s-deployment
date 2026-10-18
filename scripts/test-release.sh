#!/usr/bin/env bash
# 执行 release 内建的 Helm 测试（templates/tests/ 下的 hook）
# 用法: ./scripts/test-release.sh <env> [namespace] [release-name]
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CHART_DIR"

HELM_BIN="${HELM_BIN:-helm}"

ENV="${1:-}"
NAMESPACE="${2:-$ENV}"
RELEASE_NAME="${3:-api}"

if [ -z "$ENV" ]; then
  echo "用法: ./scripts/test-release.sh <dev|staging|prod> [namespace] [release-name]" >&2
  exit 1
fi

echo "==> 执行 Helm 测试: ${RELEASE_NAME} (${NAMESPACE})"
"$HELM_BIN" test "$RELEASE_NAME" --namespace "$NAMESPACE" --logs
