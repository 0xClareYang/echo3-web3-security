# 🚀 Echo3 生产环境部署指南

## 📋 部署前检查清单

### ✅ 必需配置项

**API密钥和访问凭证**
- [ ] OpenAI API Key (必需 - 用于AI风险分析)
- [ ] Ethereum/Polygon RPC节点 (推荐Infura/Alchemy)
- [ ] BSC API Key (BscScan)
- [ ] Solana RPC节点访问

**服务器环境**
- [ ] 云服务器 (推荐配置: 4vCPU, 16GB RAM, 100GB SSD)
- [ ] Docker & Docker Compose (最新版本)
- [ ] 域名和SSL证书
- [ ] 防火墙配置

**安全配置**
- [ ] 强随机JWT密钥 (64字符+)
- [ ] 数据库密码 (复杂密码)
- [ ] 部署钱包私钥 (建议硬件钱包)
- [ ] 多签治理钱包地址

---

## 🔧 第一步：环境准备

### 1.1 服务器配置

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 创建项目目录
sudo mkdir -p /opt/echo3
sudo chown $USER:$USER /opt/echo3
cd /opt/echo3
```

### 1.2 克隆项目并配置

```bash
# 假设代码已上传到您的Git仓库
git clone https://your-git-repo/echo3-project.git
cd echo3-project

# 复制并编辑环境配置
cp .env.production .env
nano .env  # 编辑配置文件，填入您的API密钥
```

### 1.3 创建必需目录

```bash
# 创建数据存储目录
sudo mkdir -p /opt/echo3/data/{postgres,redis,prometheus,grafana}
sudo mkdir -p /opt/echo3/{logs,uploads,backups}

# 设置权限
sudo chown -R $USER:$USER /opt/echo3
chmod 755 /opt/echo3/data
```

---

## 🚀 第二步：部署流程

### 2.1 配置检查

```bash
# 检查环境配置
cat .env | grep -E "(API_KEY|RPC_URL|PASSWORD|SECRET)" | head -5

# 验证Docker配置
docker-compose -f docker-compose.production.yml config
```

### 2.2 数据库初始化

```bash
# 首次启动PostgreSQL
docker-compose -f docker-compose.production.yml up -d postgres

# 等待数据库启动
sleep 30

# 验证数据库连接
docker-compose -f docker-compose.production.yml exec postgres psql -U echo3_user -d echo3_production -c "SELECT version();"
```

### 2.3 完整系统部署

```bash
# 启动所有服务
docker-compose -f docker-compose.production.yml up -d

# 检查服务状态
docker-compose -f docker-compose.production.yml ps

# 查看服务日志
docker-compose -f docker-compose.production.yml logs -f backend
```

### 2.4 智能合约部署

```bash
# 给部署脚本执行权限
chmod +x scripts/deploy-contracts.sh

# 先部署到测试网验证
./scripts/deploy-contracts.sh testnet

# 确认无误后部署到主网
./scripts/deploy-contracts.sh mainnet
```

---

## 📊 第三步：验证和监控

### 3.1 健康检查

```bash
# API健康检查
curl https://your-domain.com/health

# 预期响应:
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00Z",
  "services": {
    "database": "connected",
    "redis": "connected",
    "ai_engine": "active"
  }
}
```

### 3.2 功能测试

```bash
# 测试风险分析API
curl -X POST https://your-domain.com/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "chain": "ethereum",
    "fromAddress": "0x...",
    "toAddress": "0x...",
    "value": "1000000000000000000"
  }'
```

### 3.3 监控面板访问

- **Grafana监控**: https://your-domain.com:3001
  - 用户名: admin
  - 密码: (在.env中配置的GRAFANA_ADMIN_PASSWORD)

- **Prometheus指标**: https://your-domain.com:9090

---

## 🔒 第四步：安全配置

### 4.1 防火墙设置

```bash
# 只开放必要端口
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3001/tcp  # Grafana (可选，建议内网访问)

# 检查防火墙状态
sudo ufw status
```

### 4.2 SSL证书配置

```bash
# 使用Let's Encrypt (免费SSL)
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# 配置Nginx SSL (已在nginx/nginx.conf中预配置)
```

### 4.3 备份配置

```bash
# 设置每日自动备份
echo "0 2 * * * cd /opt/echo3 && docker-compose -f docker-compose.production.yml exec backup /backup.sh" | sudo crontab -
```

---

## 📈 第五步：性能优化

### 5.1 数据库优化

```sql
-- 连接数据库执行优化SQL
docker-compose exec postgres psql -U echo3_user -d echo3_production

-- 创建索引优化查询
CREATE INDEX CONCURRENTLY idx_risk_analyses_performance 
ON risk_analyses (created_at, chain, risk_level);

-- 配置数据库参数
ALTER SYSTEM SET shared_buffers = '512MB';
ALTER SYSTEM SET effective_cache_size = '2GB';
SELECT pg_reload_conf();
```

### 5.2 Redis优化

```bash
# 编辑Redis配置
docker-compose exec redis redis-cli CONFIG SET maxmemory 1gb
docker-compose exec redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

---

## 🚨 运维和故障排除

### 常见问题解决

**问题1: API响应慢**
```bash
# 检查CPU和内存使用
docker stats

# 检查数据库连接
docker-compose logs postgres

# 优化建议: 增加服务器配置或启用缓存
```

**问题2: 智能合约部署失败**
```bash
# 检查Gas费用设置
echo $GAS_PRICE_ETHEREUM

# 检查钱包余额
# 确保有足够ETH/BNB用于部署
```

**问题3: 数据库连接失败**
```bash
# 重启数据库服务
docker-compose restart postgres

# 检查连接池配置
docker-compose logs backend | grep "database"
```

### 监控指标关注点

**关键指标**
- API响应时间 < 2秒
- 错误率 < 1%
- CPU使用率 < 80%
- 内存使用率 < 85%
- 磁盘空间 > 20%

**告警设置**
- 服务下线: 立即告警
- 高风险交易激增: 2分钟内告警
- 系统资源不足: 5分钟内告警

---

## 🔄 更新和维护

### 代码更新流程

```bash
# 1. 备份当前版本
docker-compose exec backup /backup.sh

# 2. 拉取最新代码
git pull origin main

# 3. 更新服务
docker-compose -f docker-compose.production.yml build --no-cache
docker-compose -f docker-compose.production.yml up -d

# 4. 验证更新
curl https://your-domain.com/health
```

### 定期维护任务

**每日**
- [ ] 检查服务状态
- [ ] 查看错误日志
- [ ] 验证备份完成

**每周**
- [ ] 检查磁盘空间
- [ ] 更新系统安全补丁
- [ ] 分析性能指标

**每月**
- [ ] 数据库性能调优
- [ ] 安全审计检查
- [ ] 更新依赖包版本

---

## 📞 紧急联系和支持

### 紧急故障处理

**系统完全下线**
```bash
# 1. 快速重启所有服务
docker-compose -f docker-compose.production.yml restart

# 2. 如果仍然失败，从备份恢复
./scripts/restore-from-backup.sh [备份日期]
```

**数据库故障**
```bash
# 1. 检查数据库日志
docker-compose logs postgres

# 2. 重启数据库
docker-compose restart postgres

# 3. 如果数据损坏，从备份恢复
./scripts/restore-database.sh [备份文件]
```

### 性能监控和告警

所有关键指标和告警已配置在Grafana中，建议：
1. 设置Slack/邮件告警通知
2. 配置24/7监控值班
3. 建立故障处理流程

---

## ✅ 部署完成确认

部署成功后，请确认以下项目：

- [ ] 所有服务状态正常 (docker-compose ps)
- [ ] API接口响应正常 (/health, /api/analyze)
- [ ] 智能合约部署成功 (主网/测试网)
- [ ] 监控面板可访问 (Grafana)
- [ ] 告警系统配置完成 (Prometheus)
- [ ] SSL证书正常 (HTTPS访问)
- [ ] 备份任务设置完成
- [ ] 防火墙和安全策略生效

🎉 **恭喜！Echo3平台已成功部署到生产环境！**

---

## 📱 下一步建议

1. **浏览器扩展发布**: 准备Chrome/Firefox扩展商店发布
2. **API文档完善**: 为第三方开发者提供接入文档
3. **用户增长**: 制定营销和用户获取策略
4. **社区建设**: 建立Discord/Telegram社区
5. **合规准备**: 根据运营地区准备法律合规文档

有任何问题需要技术支持，请参考项目README或联系技术团队。