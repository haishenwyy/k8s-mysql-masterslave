# MySQL 主从复制 - 一键删除脚本 (PowerShell)

$ErrorActionPreference = "Stop"
$NAMESPACE = "mysql"

Write-Host "=== 删除 MySQL 主从复制部署 ===" -ForegroundColor Cyan

# 删除整个 namespace（包含所有资源）
kubectl delete namespace $NAMESPACE --ignore-not-found=true --wait=true

Write-Host ""
Write-Host "=== 删除完成 ===" -ForegroundColor Green
