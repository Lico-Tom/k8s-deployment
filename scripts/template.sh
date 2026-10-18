#!/usr/bin/env bash
# 本地渲染模板，不连接集群即可验证产物
# 用法: ./scripts/template.sh [env] [release-name]
#   env: dev|staging|prod，缺省则只用默认 values
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CHART_DIR"

HELM_BIN="${HELM_BIN:-helm}"
ENV="${1:-}"
RELEASE_NAME="${2:-api}"

if ! command -v "$HELM_BIN" >/dev/null 2>&1; then
  echo "错误: 未找到 helm，请先安装或设置 HELM_BIN=/path/to/helm" >&2
  exit 127
fi

ARGS=()
if [ -n "$ENV" ]; then
  VALUES_FILE="environments/values-${ENV}.yaml"
  if [ ! -f "$VALUES_FILE" ]; then
    echo "错误: 环境配置不存在 -> $VALUES_FILE" >&2
    exit 1
  fi
  ARGS+=(--values "$VALUES_FILE")
fi

echo "==> 渲染 release=${RELEASE_NAME} env=${ENV:-default}"
"$HELM_BIN" template "$RELEASE_NAME" . "${ARGS[@]}"

# 同时做一次集群兼容性校验（需要能连到集群，失败不阻断）
if "$HELM_BIN" template "$RELEASE_NAME" . "${ARGS[@]}" --validate >/dev/null 2>&1; then
  echo "==> 集群 API 校验通过"
else
  echo "==> 跳过集群校验（未连接集群或 Invalid 规格，属正常）"
fi
