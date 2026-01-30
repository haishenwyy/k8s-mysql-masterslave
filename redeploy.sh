#!/bin/bash
# MySQL 主从复制 - 重新部署脚本
# 用于在修改配置后重新部署，确保 Slave root 密码与 Secret 一致

set -e

NAMESPACE="mysql"

echo "=== MySQL 主从复制 重新部署 ==="

# 1. 删除 Replication Job
echo "[1/5] 删除 Replication Job..."
kubectl delete job mysql-replication-setup -n ${NAMESPACE} --ignore-not-found=true --wait=true 2>/dev/null || true

# 2. 应用最新配置（含 Slave init 脚本）
echo "[2/5] 应用 Kustomize 配置..."
kubectl apply -k .

# 3. 删除 Slave Pod 以触发重建（使用 init 脚本设置 root 密码）
echo "[3/5] 重建 Slave Pod..."
kubectl delete pod -n ${NAMESPACE} -l app=mysql-slave --ignore-not-found=true --wait=true 2>/dev/null || true

# 4. 等待 Master 就绪
echo "[4/5] 等待 Master 就绪..."
kubectl wait --for=condition=ready pod -l app=mysql-master -n ${NAMESPACE} --timeout=300s

# 5. 等待 Slave 就绪（含 init 脚本执行）
echo "[5/5] 等待 Slave 就绪（root 密码已由 init 脚本设置）..."
kubectl wait --for=condition=ready pod -l app=mysql-slave -n ${NAMESPACE} --timeout=300s

# 6. 执行复制配置 Job
echo "[6/6] 执行主从复制配置 Job..."
kubectl delete job mysql-replication-setup -n ${NAMESPACE} --ignore-not-found=true 2>/dev/null || true
kubectl apply -f mysql-replication-job.yaml

echo ""
echo "等待 Job 完成..."
kubectl wait --for=condition=complete job/mysql-replication-setup -n ${NAMESPACE} --timeout=300s

echo ""
echo "=== 部署完成 ==="
echo "验证复制状态: kubectl exec -it mysql-slave-0 -n ${NAMESPACE} -- mysql -uroot -p\$(kubectl get secret mysql-secret -n ${NAMESPACE} -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d) -e \"SHOW SLAVE STATUS\\G\""
