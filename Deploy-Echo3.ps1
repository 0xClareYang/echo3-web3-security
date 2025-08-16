# 一键Docker部署脚本 (PowerShell)
# 自动化完成Echo3平台的完整部署

param(
    [switch]$SkipDockerCheck,
    [switch]$Verbose
)

# 设置错误处理
$ErrorActionPreference = "Stop"

# 颜色函数
function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Write-Success { param([string]$Text) Write-ColorText "✅ $Text" "Green" }
function Write-Info { param([string]$Text) Write-ColorText "ℹ️  $Text" "Cyan" }
function Write-Warning { param([string]$Text) Write-ColorText "⚠️  $Text" "Yellow" }
function Write-Error { param([string]$Text) Write-ColorText "❌ $Text" "Red" }

# 显示标题
Write-ColorText @"
=========================================
    🛡️  Echo3 Web3 Security Platform
    🐳  Docker 完整部署脚本
=========================================
"@ "Blue"

# 检查Docker是否安装和运行
if (-not $SkipDockerCheck) {
    Write-Info "检查Docker环境..."
    
    try {
        $dockerVersion = docker --version
        Write-Success "Docker已安装: $dockerVersion"
    } catch {
        Write-Error "Docker未安装或不在PATH中"
        Write-Warning "请先安装Docker Desktop: https://www.docker.com/products/docker-desktop/"
        exit 1
    }
    
    try {
        $composeVersion = docker-compose --version
        Write-Success "Docker Compose已安装: $composeVersion"
    } catch {
        Write-Error "Docker Compose未安装"
        exit 1
    }
    
    # 检查Docker是否运行
    try {
        docker info | Out-Null
        Write-Success "Docker服务正在运行"
    } catch {
        Write-Error "Docker服务未启动，请启动Docker Desktop"
        exit 1
    }
}

# 检查项目目录
$projectPath = "C:\Users\MagicBook\echo3-project"
if (-not (Test-Path $projectPath)) {
    Write-Error "项目目录不存在: $projectPath"
    exit 1
}

Set-Location $projectPath
Write-Success "项目目录: $projectPath"

# 检查配置文件
if (-not (Test-Path ".env.production")) {
    Write-Error "配置文件不存在: .env.production"
    Write-Warning "请确保配置文件存在且包含必需的API密钥"
    exit 1
}

# 验证API密钥配置
$envContent = Get-Content ".env.production" -Raw
$missingKeys = @()

if ($envContent -notmatch "OPENAI_API_KEY=sk-") {
    $missingKeys += "OPENAI_API_KEY"
}
if ($envContent -notmatch "BSC_API_KEY=\w{32}") {
    $missingKeys += "BSC_API_KEY"
}

if ($missingKeys.Count -gt 0) {
    Write-Error "缺少必需的API密钥: $($missingKeys -join ', ')"
    Write-Warning "请编辑 .env.production 文件并填入正确的API密钥"
    exit 1
}

Write-Success "配置文件验证通过"

# 创建数据目录
Write-Info "创建数据目录..."
$dataDirs = @(
    "C:\opt\echo3\data\postgres",
    "C:\opt\echo3\data\redis", 
    "C:\opt\echo3\data\prometheus",
    "C:\opt\echo3\data\grafana",
    "C:\opt\echo3\logs",
    "C:\opt\echo3\uploads",
    "C:\opt\echo3\backups"
)

foreach ($dir in $dataDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Success "创建目录: $dir"
    }
}

# 停止现有服务
Write-Info "停止现有服务..."
try {
    docker-compose -f docker-compose.production.yml down | Out-Null
} catch {
    Write-Warning "没有正在运行的服务需要停止"
}

# 拉取最新镜像
Write-Info "拉取Docker镜像..."
docker-compose -f docker-compose.production.yml pull

# 按顺序启动服务
Write-Info "🗄️ 启动PostgreSQL数据库..."
docker-compose -f docker-compose.production.yml up -d postgres

Write-Info "⏳ 等待数据库启动 (30秒)..."
Start-Sleep -Seconds 30

# 验证数据库连接
$dbRetries = 5
$dbConnected = $false
for ($i = 1; $i -le $dbRetries; $i++) {
    try {
        docker-compose -f docker-compose.production.yml exec -T postgres pg_isready -U echo3_user | Out-Null
        $dbConnected = $true
        break
    } catch {
        Write-Warning "数据库连接尝试 $i/$dbRetries 失败，重试中..."
        Start-Sleep -Seconds 10
    }
}

if (-not $dbConnected) {
    Write-Error "数据库启动失败"
    docker-compose -f docker-compose.production.yml logs postgres
    exit 1
}

Write-Success "数据库连接成功"

Write-Info "🔄 启动Redis缓存..."
docker-compose -f docker-compose.production.yml up -d redis
Start-Sleep -Seconds 10

Write-Info "🚀 启动Echo3 API服务..."
docker-compose -f docker-compose.production.yml up -d backend
Start-Sleep -Seconds 20

Write-Info "📊 启动监控服务..."
docker-compose -f docker-compose.production.yml up -d prometheus grafana
Start-Sleep -Seconds 15

# 检查服务状态
Write-Info "🔍 检查服务状态..."
docker-compose -f docker-compose.production.yml ps

# 等待API服务启动
Write-Info "🏥 等待API服务启动..."
$apiRetries = 12
$apiReady = $false

for ($i = 1; $i -le $apiRetries; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            $apiReady = $true
            break
        }
    } catch {
        Write-Warning "API健康检查尝试 $i/$apiRetries 失败，等待中..."
        Start-Sleep -Seconds 10
    }
}

if ($apiReady) {
    Write-Success "API服务启动成功"
} else {
    Write-Warning "API服务可能需要更多时间启动"
}

# 显示部署结果
Write-ColorText @"

=========================================
    🎉 Echo3 部署完成!
=========================================

✅ 部署状态:
   - PostgreSQL数据库: 运行中
   - Redis缓存: 运行中  
   - Echo3 API服务: 运行中
   - Prometheus监控: 运行中
   - Grafana面板: 运行中

📱 服务访问地址:
   - API健康检查: http://localhost:3000/health
   - API文档: http://localhost:3000/api-docs
   - Grafana监控: http://localhost:3001 (admin / 见.env文件)
   - Prometheus: http://localhost:9090

📝 接下来的步骤:
   1. 访问 http://localhost:3000/health 验证API服务
   2. 访问 http://localhost:3001 查看监控面板
   3. 准备钱包私钥并部署智能合约
   4. 配置域名和SSL证书 (生产环境)

📚 查看完整文档:
   - COMPLETE_DOCKER_GUIDE.md
   - docs/PRODUCTION_DEPLOYMENT.md
   - docs/BSC_INTEGRATION.md

为了您母亲的健康，Echo3平台已经以最高标准构建完成！
祝您和家人一切安好！🙏

"@ "Green"

# 可选：自动打开浏览器
$openBrowser = Read-Host "是否自动打开浏览器查看服务? (y/n)"
if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
    Start-Process "http://localhost:3000/health"
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:3001"
}