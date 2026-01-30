# MySQL 主从复制 - 重新部署脚本 (PowerShell)
# 用于修改配置后重新部署，确保 Slave root 密码与 Secret 一致

$ErrorActionPreference = "Stop"
$NAMESPACE = "mysql"

Write-Host "=== MySQL 主从复制 重新部署 ===" -ForegroundColor Cyan

# 1. 删除 Replication Job
Write-Host "[1/6] 删除 Replication Job..." -ForegroundColor Yellow
kubectl delete job mysql-replication-setup -n $NAMESPACE --ignore-not-found=true --wait=true 2>$null

# 2. 应用最新配置（含 Slave init 脚本）
Write-Host "[2/6] 应用 Kustomize 配置..." -ForegroundColor Yellow
kubectl apply -k .

# 3. 删除 Slave Pod 以触发重建（使用 init 脚本设置 root 密码）
Write-Host "[3/6] 重建 Slave Pod..." -ForegroundColor Yellow
kubectl delete pod -n $NAMESPACE -l app=mysql-slave --ignore-not-found=true --wait=true 2>$null

# 4. 等待 Master 就绪
Write-Host "[4/6] 等待 Master 就绪..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=mysql-master -n $NAMESPACE --timeout=300s

# 5. 等待 Slave 就绪
Write-Host "[5/6] 等待 Slave 就绪（root 密码已由 init 脚本设置）..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=mysql-slave -n $NAMESPACE --timeout=300s

# 6. 执行复制配置 Job
Write-Host "[6/6] 执行主从复制配置 Job..." -ForegroundColor Yellow
kubectl delete job mysql-replication-setup -n $NAMESPACE --ignore-not-found=true 2>$null
kubectl apply -f mysql-replication-job.yaml

Write-Host ""
Write-Host "等待 Job 完成..." -ForegroundColor Yellow
kubectl wait --for=condition=complete job/mysql-replication-setup -n $NAMESPACE --timeout=300s

Write-Host ""
Write-Host "=== 部署完成 ===" -ForegroundColor Green
Write-Host "验证复制状态: kubectl exec -it mysql-slave-0 -n $NAMESPACE -- mysql -uroot -p<密码> -e `"SHOW SLAVE STATUS\G`""
