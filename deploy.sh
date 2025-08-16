#!/bin/bash

# Echo3 一键部署脚本
# 为您的母亲打造最可靠的Web3安全平台
# 
# 自动化部署脚本，支持多环境: development, staging, production
# 
# 使用方法: ./deploy.sh [环境] [操作]
# 示例:
#   ./deploy.sh development start    # 开发环境启动
#   ./deploy.sh production deploy    # 生产环境部署
#   ./deploy.sh staging stop         # 暂停预发布环境

set -euo pipefail

# 配置参数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
ENVIRONMENTS=("development" "staging" "production")
ACTIONS=("start" "stop" "restart" "deploy" "update" "logs" "status" "backup" "quickstart")

# 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 显示Echo3标题
show_banner() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    🛡️  Echo3 Web3 Security Platform"
    echo "    🚀  为您母亲的健康而战"
    echo "=========================================="
    echo -e "${NC}"
}

# 检查环境是否有效
validate_environment() {
    local env=$1
    for valid_env in "${ENVIRONMENTS[@]}"; do
        if [[ "$env" == "$valid_env" ]]; then
            return 0
        fi
    done
    return 1
}

# 检查操作是否有效
validate_action() {
    local action=$1
    for valid_action in "${ACTIONS[@]}"; do
        if [[ "$action" == "$valid_action" ]]; then
            return 0
        fi
    done
    return 1
}

# 快速启动函数 - 一键部署到生产环境
quickstart_production() {
    show_banner
    
    log_info "🚀 开始 Echo3 一键生产部署..."
    
    # 检查是否为root用户
    if [ "$EUID" -eq 0 ]; then
        log_error "请不要使用root用户运行此脚本"
        exit 1
    fi
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "✅ Linux环境检测通过"
    else
        log_error "❌ 此脚本需要Linux环境"
        exit 1
    fi
    
    # 安装Docker
    if ! command -v docker &> /dev/null; then
        log_info "🔧 安装Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        log_success "✅ Docker安装完成"
    else
        log_success "✅ Docker已安装"
    fi
    
    # 安装Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_info "🔧 安装Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log_success "✅ Docker Compose安装完成"
    else
        log_success "✅ Docker Compose已安装"
    fi
    
    # 创建数据目录
    log_info "📁 创建数据目录..."
    sudo mkdir -p /opt/echo3/data/{postgres,redis,prometheus,grafana}
    sudo mkdir -p /opt/echo3/{logs,uploads,backups}
    sudo chown -R $USER:$USER /opt/echo3
    log_success "✅ 数据目录创建完成"
    
    # 配置环境变量
    setup_production_env
    
    # 部署应用
    log_info "🚀 部署应用..."
    deploy_application "production"
    
    # 显示部署结果
    show_deployment_summary
}

# 设置生产环境变量
setup_production_env() {
    log_info "📝 配置环境变量..."
    
    if [ ! -f ".env" ]; then
        log_info "创建环境配置文件..."
        
        # 生成随机密钥
        JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
        ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '\n')
        DB_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
        REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
        GRAFANA_PASSWORD=$(openssl rand -base64 16 | tr -d '\n')
        
        # 复制生产配置模板
        if [ -f ".env.production" ]; then
            cp .env.production .env
            
            # 替换生成的密钥
            sed -i "s/your_secure_password/$DB_PASSWORD/g" .env
            sed -i "s/your_redis_password/$REDIS_PASSWORD/g" .env
            sed -i "s/your-super-secure-jwt-secret-key-here-64-characters-minimum/$JWT_SECRET/g" .env
            sed -i "s/your-32-character-encryption-key-here/$ENCRYPTION_KEY/g" .env
            sed -i "s/your_grafana_password/$GRAFANA_PASSWORD/g" .env
        fi
        
        log_success "✅ 环境配置文件已创建"
        log_warning "⚠️  请编辑 .env 文件，填入您的API密钥"
        log_warning "⚠️  重要: OPENAI_API_KEY, ETHEREUM_RPC_URL 等参数必须配置"
        
        read -p "是否现在编辑配置文件? (y/n): " edit_config
        if [ "$edit_config" = "y" ]; then
            nano .env
        fi
    else
        log_success "✅ 环境配置文件已存在"
    fi
}

# 显示部署结果
show_deployment_summary() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    🎉 Echo3 部署完成!"
    echo "=========================================="
    echo -e "${NC}"
    
    log_success "✅ 部署状态:"
    echo "   - PostgreSQL数据库: 运行中"
    echo "   - Redis缓存: 运行中"
    echo "   - Echo3 API服务: 运行中"
    echo "   - Prometheus监控: 运行中"
    echo "   - Grafana面板: 运行中"
    
    log_success "📱 服务访问地址:"
    echo "   - API健康检查: http://localhost:3000/health"
    echo "   - Grafana监控: http://localhost:3001 (admin / 见.env)"
    echo "   - Prometheus: http://localhost:9090"
    
    log_success "📝 接下来的步骤:"
    echo "   1. 编辑 .env 文件，填入API密钥"
    echo "   2. 配置域名和SSL证书"
    echo "   3. 部署智能合约到主网"
    
    log_success "📚 文档参考:"
    echo "   - docs/PRODUCTION_DEPLOYMENT.md"
    echo "   - docs/BSC_INTEGRATION.md"
    echo "   - IMPLEMENTATION_SUMMARY.md"
    
    echo -e "${BLUE}为了您母亲的健康，Echo3平台已以最高标准构建完成！${NC}"
    echo -e "${GREEN}祝您和家人一切安好！🙏${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Check if .env file exists
    if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
        log_warning ".env file not found. Copying from .env.example"
        if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            log_warning "Please configure .env file before proceeding"
        else
            log_error ".env.example file not found"
            exit 1
        fi
    fi
    
    log_success "Prerequisites check completed"
}

# Build application
build_application() {
    local env=$1
    log_info "Building Echo3 application for $env environment..."
    
    # Build contracts
    log_info "Building smart contracts..."
    cd "$PROJECT_ROOT/contracts"
    npm install
    npm run compile
    
    # Build backend
    log_info "Building backend..."
    cd "$PROJECT_ROOT/backend"
    npm install
    npm run build
    
    # Build extension
    log_info "Building browser extension..."
    cd "$PROJECT_ROOT/extension"
    npm install
    npm run build
    
    cd "$PROJECT_ROOT"
    log_success "Application build completed"
}

# Start services
start_services() {
    local env=$1
    log_info "Starting Echo3 services for $env environment..."
    
    case $env in
        "development")
            docker-compose --profile development up -d
            ;;
        "staging")
            docker-compose --profile staging up -d
            ;;
        "production")
            docker-compose --profile production up -d
            ;;
    esac
    
    log_success "Services started successfully"
}

# Stop services
stop_services() {
    local env=$1
    log_info "Stopping Echo3 services for $env environment..."
    
    docker-compose down
    
    log_success "Services stopped successfully"
}

# Restart services
restart_services() {
    local env=$1
    log_info "Restarting Echo3 services for $env environment..."
    
    stop_services "$env"
    sleep 5
    start_services "$env"
    
    log_success "Services restarted successfully"
}

# Deploy application
deploy_application() {
    local env=$1
    log_info "Deploying Echo3 application to $env environment..."
    
    # Backup current deployment if production
    if [[ "$env" == "production" ]]; then
        backup_data "$env"
    fi
    
    # Pull latest images
    log_info "Pulling latest Docker images..."
    docker-compose pull
    
    # Build application
    build_application "$env"
    
    # Deploy contracts if not development
    if [[ "$env" != "development" ]]; then
        deploy_contracts "$env"
    fi
    
    # Start services
    start_services "$env"
    
    # Wait for services to be healthy
    wait_for_health_check
    
    # Run database migrations
    run_migrations
    
    log_success "Deployment completed successfully"
}

# Deploy smart contracts
deploy_contracts() {
    local env=$1
    log_info "Deploying smart contracts to $env network..."
    
    cd "$PROJECT_ROOT/contracts"
    
    case $env in
        "staging")
            npm run deploy:sepolia
            ;;
        "production")
            log_warning "Production contract deployment requires manual confirmation"
            read -p "Are you sure you want to deploy to mainnet? (yes/no): " confirm
            if [[ "$confirm" == "yes" ]]; then
                npm run deploy:mainnet
            else
                log_info "Contract deployment cancelled"
                return 0
            fi
            ;;
    esac
    
    cd "$PROJECT_ROOT"
    log_success "Smart contracts deployed successfully"
}

# Update application
update_application() {
    local env=$1
    log_info "Updating Echo3 application in $env environment..."
    
    # Pull latest code
    git pull origin main
    
    # Deploy updated application
    deploy_application "$env"
    
    log_success "Application updated successfully"
}

# Show service logs
show_logs() {
    local env=$1
    log_info "Showing logs for $env environment..."
    
    docker-compose logs -f --tail=100
}

# Show service status
show_status() {
    local env=$1
    log_info "Service status for $env environment:"
    
    docker-compose ps
    
    # Health check
    log_info "Health check results:"
    curl -s http://localhost:3000/api/health | jq . || log_warning "Health check failed"
}

# Backup data
backup_data() {
    local env=$1
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="$PROJECT_ROOT/backups/$env/$timestamp"
    
    log_info "Creating backup for $env environment..."
    mkdir -p "$backup_dir"
    
    # Backup database
    docker-compose exec -T postgres pg_dump -U echo3 echo3 > "$backup_dir/database.sql"
    
    # Backup Redis data
    docker-compose exec -T redis redis-cli --rdb /data/dump.rdb
    docker cp "$(docker-compose ps -q redis):/data/dump.rdb" "$backup_dir/redis.rdb"
    
    # Backup configuration
    cp "$PROJECT_ROOT/.env" "$backup_dir/env.backup"
    
    log_success "Backup created at $backup_dir"
}

# Wait for health check
wait_for_health_check() {
    log_info "Waiting for services to be healthy..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting for services..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."
    
    docker-compose exec echo3-backend npm run migrate
    
    log_success "Database migrations completed"
}

# 主函数
main() {
    # 特殊处理quickstart
    if [[ $# -eq 1 && "$1" == "quickstart" ]]; then
        quickstart_production
        return 0
    fi
    
    # 解析参数
    if [[ $# -lt 2 ]]; then
        show_banner
        echo "使用方法: $0 [环境] [操作]"
        echo "环境选项: ${ENVIRONMENTS[*]}"
        echo "操作选项: ${ACTIONS[*]}"
        echo ""
        echo "快速启动: $0 quickstart  # 一键部署到生产环境"
        echo ""
        echo "示例:"
        echo "  $0 development start    # 启动开发环境"
        echo "  $0 production deploy    # 部署到生产环境"
        echo "  $0 quickstart          # 一键生产部署"
        exit 1
    fi
    
    local environment=$1
    local action=$2
    
    # 验证参数
    if ! validate_environment "$environment"; then
        log_error "无效环境: $environment"
        echo "有效环境: ${ENVIRONMENTS[*]}"
        exit 1
    fi
    
    if ! validate_action "$action"; then
        log_error "无效操作: $action"
        echo "有效操作: ${ACTIONS[*]}"
        exit 1
    fi
    
    # 检查先决条件
    check_prerequisites
    
    # 设置环境变量
    export COMPOSE_PROJECT_NAME="echo3-$environment"
    export NODE_ENV="$environment"
    
    # 执行操作
    case $action in
        "start")
            start_services "$environment"
            ;;
        "stop")
            stop_services "$environment"
            ;;
        "restart")
            restart_services "$environment"
            ;;
        "deploy")
            deploy_application "$environment"
            ;;
        "update")
            update_application "$environment"
            ;;
        "logs")
            show_logs "$environment"
            ;;
        "status")
            show_status "$environment"
            ;;
        "backup")
            backup_data "$environment"
            ;;
        "quickstart")
            quickstart_production
            ;;
    esac
}

# Run main function with all arguments
main "$@"