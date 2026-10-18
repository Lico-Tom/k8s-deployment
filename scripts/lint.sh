#!/usr/bin/env bash
# 语法检查 + 用三套环境 values 分别 lint，确保 values 与模板匹配
# 用法: ./scripts/lint.sh
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CHART_DIR"

HELM_BIN="${HELM_BIN:-helm}"

if ! command -v "$HELM_BIN" >/dev/null 2>&1; then
  echo "错误: 未找到 helm，请先安装或设置 HELM_BIN=/path/to/helm" >&2
  exit 127
fi

echo "==> helm 版本"
"$HELM_BIN" version --short

echo "==> 默认 values 检查"
"$HELM_BIN" lint .

for env in dev staging prod; do
  values_file="environments/values-${env}.yaml"
  [ -f "$values_file" ] || continue
  echo "==> ${env} 环境检查 (${values_file})"
  "$HELM_BIN" lint . --values "$values_file"
done

echo "==> 全部通过"
