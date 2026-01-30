#!/bin/bash
# MySQL 主从复制 - 一键删除脚本

set -e

NAMESPACE="mysql"

echo "=== 删除 MySQL 主从复制部署 ==="

# 删除整个 namespace（包含所有资源）
kubectl delete namespace ${NAMESPACE} --ignore-not-found=true --wait=true

echo ""
echo "=== 删除完成 ==="
