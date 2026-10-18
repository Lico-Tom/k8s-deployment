#!/usr/bin/env bash
# 拉取子 chart 依赖并打包成 .tgz
# 用法: ./scripts/package.sh
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CHART_DIR"

HELM_BIN="${HELM_BIN:-helm}"

echo "==> 更新依赖（拉取到 charts/ 目录）"
"$HELM_BIN" dependency update .

echo "==> 打包输出到 ./dist"
mkdir -p dist
"$HELM_BIN" package . --destination dist

echo "==> 产物"
ls -lh dist/*.tgz
