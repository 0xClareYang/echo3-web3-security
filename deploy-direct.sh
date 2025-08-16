#!/bin/bash

# Echo3 直接生产部署脚本（不使用Docker）
# Direct Production Deployment Script for Echo3

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🚀 Echo3 Web3 Security Platform - Direct Production Deployment"
echo "============================================================="

# 检查系统要求
log_info "检查系统要求..."

# 检查 Node.js
if ! command -v node &> /dev/null; then
    log_error "Node.js 未安装. 请先安装 Node.js 18 或更高版本"
    exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    log_error "Node.js 版本过低 (当前: $(node --version), 需要: v18+)"
    exit 1
fi

# 检查 npm
if ! command -v npm &> /dev/null; then
    log_error "npm 未安装"
    exit 1
fi

# 检查 pm2
if ! command -v pm2 &> /dev/null; then
    log_info "安装 PM2 进程管理器..."
    npm install -g pm2
fi

log_success "系统要求检查完成"

# 创建生产用户
log_info "设置生产环境用户..."
if ! id "echo3" &>/dev/null; then
    sudo useradd -m -s /bin/bash echo3
    log_success "创建用户 echo3"
else
    log_info "用户 echo3 已存在"
fi

# 创建生产目录
PROD_DIR="/opt/echo3"
log_info "创建生产目录: $PROD_DIR"
sudo mkdir -p $PROD_DIR
sudo chown echo3:echo3 $PROD_DIR

# 复制应用文件
log_info "部署应用文件..."
sudo cp -r . $PROD_DIR/
sudo chown -R echo3:echo3 $PROD_DIR

# 切换到生产目录
cd $PROD_DIR

# 安装生产依赖
log_info "安装生产依赖..."
sudo -u echo3 npm ci --only=production

# 创建日志目录
log_info "创建日志目录..."
sudo mkdir -p /var/log/echo3
sudo chown echo3:echo3 /var/log/echo3

# 设置环境变量
log_info "配置环境变量..."
if [ ! -f ".env.production" ]; then
    sudo -u echo3 cp .env.production.example .env.production
    
    # 生成随机密码
    JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
    
    # 更新配置
    sudo -u echo3 sed -i "s/echo3_super_secure_jwt_secret_change_this_immediately_32chars_minimum/$JWT_SECRET/g" .env.production
    
    log_success "环境配置文件已创建"
    log_warning "请编辑 $PROD_DIR/.env.production 文件，设置您的 API 密钥"
fi

# 创建 PM2 配置文件
log_info "创建 PM2 配置..."
sudo -u echo3 cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'echo3-production',
    script: 'echo3-agent.js',
    cwd: '/opt/echo3',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    env_file: '.env.production',
    log_file: '/var/log/echo3/combined.log',
    out_file: '/var/log/echo3/out.log',
    error_file: '/var/log/echo3/error.log',
    time: true,
    max_memory_restart: '2G',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s',
    kill_timeout: 5000,
    listen_timeout: 8000,
    wait_ready: true
  }]
};
EOF

# 安装和配置 Nginx
log_info "配置 Nginx..."
if ! command -v nginx &> /dev/null; then
    # Ubuntu/Debian
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y nginx
    # CentOS/RHEL
    elif command -v yum &> /dev/null; then
        sudo yum install -y nginx
    else
        log_warning "无法自动安装 Nginx，请手动安装"
    fi
fi

# 创建 Nginx 配置
sudo tee /etc/nginx/sites-available/echo3 > /dev/null << 'EOF'
upstream echo3_backend {
    server 127.0.0.1:3000;
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    # 重定向到 HTTPS (如果有SSL证书)
    # return 301 https://$server_name$request_uri;

    # 或者直接处理 HTTP 请求
    location / {
        proxy_pass http://echo3_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # API 限流
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://echo3_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# 限流配置
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
EOF

# 启用站点
sudo ln -sf /etc/nginx/sites-available/echo3 /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 测试 Nginx 配置
sudo nginx -t

# 创建 systemd 服务
log_info "创建系统服务..."
sudo tee /etc/systemd/system/echo3.service > /dev/null << 'EOF'
[Unit]
Description=Echo3 Web3 Security Platform
After=network.target

[Service]
Type=forking
User=echo3
WorkingDirectory=/opt/echo3
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production
ExecStart=/usr/local/bin/pm2 start ecosystem.config.js --env production
ExecReload=/usr/local/bin/pm2 reload ecosystem.config.js --env production
ExecStop=/usr/local/bin/pm2 stop ecosystem.config.js
PIDFile=/opt/echo3/.pm2/pm2.pid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
log_info "启动服务..."
sudo systemctl daemon-reload
sudo systemctl enable echo3
sudo systemctl enable nginx

# 停止可能运行的服务
sudo -u echo3 pm2 delete all 2>/dev/null || true

# 启动 Echo3
sudo -u echo3 pm2 start ecosystem.config.js --env production
sudo -u echo3 pm2 save
sudo -u echo3 pm2 startup systemd -u echo3 --hp /home/echo3

# 启动 Nginx
sudo systemctl restart nginx

# 等待服务启动
log_info "等待服务启动..."
sleep 10

# 健康检查
log_info "运行健康检查..."
if curl -f http://localhost:3000/api/v2/health &> /dev/null; then
    log_success "Echo3 API 健康检查通过"
else
    log_error "Echo3 API 健康检查失败"
    sudo -u echo3 pm2 logs --lines 50
fi

if curl -f http://localhost/api/v2/health &> /dev/null; then
    log_success "Nginx 反向代理健康检查通过"
else
    log_warning "Nginx 反向代理可能需要配置调整"
fi

# 设置防火墙
log_info "配置防火墙..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable
    log_success "UFW 防火墙已配置"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
    log_success "FirewallD 已配置"
fi

# 显示部署信息
echo ""
echo "==============================================="
echo "🎉 Echo3 生产环境部署完成!"
echo "==============================================="
echo ""
echo "🌐 访问信息:"
echo "  主控制台:    http://$(hostname -I | awk '{print $1}')/dashboard"
echo "  API 健康:    http://$(hostname -I | awk '{print $1}')/api/v2/health"
echo ""
echo "🔧 管理命令:"
echo "  查看状态:    sudo systemctl status echo3"
echo "  查看日志:    sudo -u echo3 pm2 logs"
echo "  重启服务:    sudo systemctl restart echo3"
echo "  停止服务:    sudo systemctl stop echo3"
echo ""
echo "📁 重要文件位置:"
echo "  应用目录:    /opt/echo3"
echo "  日志目录:    /var/log/echo3"
echo "  配置文件:    /opt/echo3/.env.production"
echo "  Nginx配置:   /etc/nginx/sites-available/echo3"
echo ""
echo "⚠️  重要提醒:"
echo "  1. 请编辑 /opt/echo3/.env.production 设置您的 API 密钥"
echo "  2. 考虑配置 SSL 证书以启用 HTTPS"
echo "  3. 定期备份 /opt/echo3 目录"
echo "  4. 监控日志文件以确保系统正常运行"
echo ""

log_success "部署完成! 🚀"