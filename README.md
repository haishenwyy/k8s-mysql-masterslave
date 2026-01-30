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

### 3. 使用 Kustomize 一键部署（不含 replication-job）

```bash
kubectl apply -k .
# 等待 Pod 就绪后手动执行
kubectl apply -f mysql-replication-job.yaml
```

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
