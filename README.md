# Kubernetes MySQL 主从复制部署

## 文件说明

| 文件 | 说明 |
|------|------|
| `namespace.yaml` | 创建 mysql 命名空间 |
| `secret.yaml` | MySQL 根密码与复制用户密码（**部署前务必修改**） |
| `mysql-master-*.yaml` | Master 节点：ConfigMap、Service、StatefulSet |
| `mysql-slave-*.yaml` | Slave 节点：ConfigMap、Service、StatefulSet |
| `mysql-replication-job.yaml` | 配置主从复制的 Job |
| `mysql-*-svc-external.yaml` | 可选，供应用访问的 ClusterIP Service |
| `argocd-application.yaml` | Argo CD Application 定义（用于 GitOps 部署） |
| `mysql-slave-init-configmap.yaml` | Slave 初始化脚本，确保 root 密码与 Secret 一致 |
| `redeploy.sh` / `redeploy.ps1` | 重新部署脚本 |
| `undeploy.sh` / `undeploy.ps1` | 一键删除脚本 |

## 部署步骤

### 1. 修改 Secret

编辑 `secret.yaml`，设置安全密码：

```yaml
stringData:
  MYSQL_ROOT_PASSWORD: "your_secure_root_password"
  MYSQL_REPLICATION_PASSWORD: "your_replication_password"
```

### 2. 部署资源

```bash
# 创建命名空间和基础资源
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml

# 部署 Master
kubectl apply -f mysql-master-configmap.yaml
kubectl apply -f mysql-master-service.yaml
kubectl apply -f mysql-master-statefulset.yaml

# 等待 Master 就绪
kubectl wait --for=condition=ready pod -l app=mysql-master -n mysql --timeout=300s

# 部署 Slave
kubectl apply -f mysql-slave-configmap.yaml
kubectl apply -f mysql-slave-service.yaml
kubectl apply -f mysql-slave-statefulset.yaml

# 等待 Slave 就绪
kubectl wait --for=condition=ready pod -l app=mysql-slave -n mysql --timeout=300s

# 执行复制配置 Job
kubectl apply -f mysql-replication-job.yaml
```

### 3. 使用 Kustomize 一键部署

```bash
kubectl apply -k .
# 等待 Pod 就绪后，replication-job 会自动执行（已包含在 kustomization 中）
```

### 3.1 重新部署（修改配置后）

```bash
# Linux / macOS / Git Bash
chmod +x redeploy.sh
./redeploy.sh

# Windows PowerShell
.\redeploy.ps1
```

### 3.2 一键删除

```bash
# Linux / macOS / Git Bash
chmod +x undeploy.sh
./undeploy.sh

# Windows PowerShell
.\undeploy.ps1
```

### 4. 使用 Argo CD 部署（GitOps）

1. **推送代码到 Git 仓库**，确保 Argo CD 能访问该仓库。

2. **确认 `argocd-application.yaml`** 中的 `source.repoURL` 已配置为：
   ```yaml
   source:
     repoURL: https://github.com/haishenwyy/k8s-mysql-masterslave.git
     path: .
     targetRevision: main
   ```

3. **Secret 管理**：生产环境不建议将密码提交到 Git。可选方案：
   - 使用 [External Secrets Operator](https://external-secrets.io/) 或 [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) 管理密码
   - 首次部署前手动创建 Secret：`kubectl apply -f secret.yaml -n mysql`（不纳入 Git）

4. **创建 Argo CD Application**：
   ```bash
   kubectl apply -f argocd-application.yaml
   ```

5. **Sync Wave 部署顺序**（已配置）：
   - Wave -1: Namespace
   - Wave 0: Secret、ConfigMap、Service
   - Wave 1: Master StatefulSet
   - Wave 2: Slave StatefulSet、ClusterIP Service
   - Wave 3: Replication Job（Master/Slave 就绪后自动执行）

6. Argo CD 将自动同步、自愈并清理已移除资源（`prune: true`, `selfHeal: true`）。

## 验证复制状态

```bash
# 查看 Slave 复制状态
kubectl exec -it mysql-slave-0 -n mysql -- mysql -u root -p -e "SHOW SLAVE STATUS\G"
```

关注 `Slave_IO_Running` 和 `Slave_SQL_Running` 均为 `Yes` 表示复制正常。

## 连接方式

- **Master（写）**: `mysql-master-svc.mysql.svc.cluster.local:3306` 或 `mysql-master.mysql.svc.cluster.local:3306`
- **Slave（读）**: `mysql-slave-svc.mysql.svc.cluster.local:3306` 或 `mysql-slave.mysql.svc.cluster.local:3306`

## 注意事项

1. **存储**：当前使用 `emptyDir`，数据存储在节点本地，**Pod 删除后数据会丢失**，仅适合开发/测试环境
2. **多 Slave**：修改 `mysql-slave-statefulset.yaml` 中 `replicas` 及每个 Slave 的 `server-id`
3. **MySQL 8.0**：使用 `mysql_native_password` 以兼容部分客户端
4. **生产环境**：建议使用更安全的 Secret 管理方式（如 External Secrets、Sealed Secrets）
5. **Argo CD**：Replication Job 完成后会被 TTL 清理；若 Argo CD 检测到漂移会重新创建并执行，主从配置会重新应用（幂等）
