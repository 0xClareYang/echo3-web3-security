# 🚀 Quick Start Guide

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Windows 10, macOS 12, Ubuntu 20.04 | Windows 11, macOS 13+, Ubuntu 22.04 |
| **CPU** | 2 cores | 4+ cores |
| **Memory** | 4GB RAM | 8GB+ RAM |
| **Storage** | 10GB free space | 20GB+ free space |
| **Network** | Stable internet | High-speed broadband |

## Prerequisites Installation

### Node.js Installation
```bash
# Windows (using Chocolatey)
choco install nodejs

# macOS (using Homebrew)
brew install node

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Docker Installation
```bash
# Windows: Download Docker Desktop from docker.com
# macOS: Download Docker Desktop from docker.com

# Ubuntu
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
```

## Quick Deployment

### Option 1: One-Click Windows Deployment
```bash
# Clone repository
git clone https://github.com/0xClareYang/echo3-web3-security.git
cd echo3-web3-security

# Run as Administrator
.\start-windows.bat
```

### Option 2: Docker Production Deployment
```bash
# Clone repository
git clone https://github.com/0xClareYang/echo3-web3-security.git
cd echo3-web3-security

# Start all services
docker-compose -f docker-compose.production.yml up -d

# Verify deployment
curl http://localhost:3000/api/v2/health
```

### Option 3: Manual Development Setup
```bash
# Install dependencies
npm install

# Set environment variables
cp .env.example .env
# Edit .env with your configuration

# Start development server
npm run dev
```

## Configuration

### Essential Environment Variables
```bash
# Core Settings
NODE_ENV=production
PORT=3000

# Blockchain RPCs
ETHEREUM_RPC_URL=https://rpc.ankr.com/eth
BSC_RPC_URL=https://bsc-dataseed1.binance.org/

# Security Keys (REQUIRED)
OPENAI_API_KEY=your_openai_api_key_here

# Database
DATABASE_URL=postgresql://localhost:5432/echo3

# Monitoring
GRAFANA_ADMIN_PASSWORD=echo3_secure_2024
```

### Wallet Configuration
1. Install MetaMask browser extension
2. Create or import wallet
3. Connect to supported networks:
   - Ethereum Mainnet
   - BSC Mainnet
   - Polygon Mainnet

## Verification

### Health Checks
```bash
# API Health
curl http://localhost:3000/api/v2/health

# Expected Response:
{
  "status": "healthy",
  "version": "3.1.0",
  "uptime": 123,
  "services": {
    "api": "operational",
    "blockchain": "connected",
    "security": "active"
  }
}
```

### Service Endpoints
- **Dashboard**: http://localhost:3000/dashboard
- **API Documentation**: http://localhost:3000/api/v2/
- **Monitoring**: http://localhost:3001 (admin/echo3_secure_2024)
- **Metrics**: http://localhost:9090

## First Steps

### 1. Connect Your Wallet
1. Open http://localhost:3000/dashboard
2. Click "Connect Wallet" in top-right corner
3. Approve MetaMask connection
4. Verify wallet address and balance display

### 2. Run Security Analysis
```javascript
// Test security analysis
fetch('http://localhost:3000/api/v2/analyze', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    from: '0x742d35Cc6634C0532925a3b8D0B48b7E3F1b5389',
    to: '0x8ba1f109551bd432803012645hac136c82153ec2',
    value: '1000000000000000000'
  })
})
```

### 3. Enable Auto Trading
1. Ensure wallet is connected
2. Click "Auto Trading" panel
3. Configure trading strategies
4. Enable with appropriate risk limits

### 4. Monitor Portfolio
1. Click "Portfolio Analytics"
2. Review real-time performance
3. Set up yield optimization alerts
4. Configure rebalancing rules

## Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Check what's using port 3000
netstat -ano | findstr :3000

# Kill process (Windows)
taskkill /PID <PID> /F

# Kill process (macOS/Linux)
kill -9 <PID>
```

#### Docker Issues
```bash
# Restart Docker service
sudo systemctl restart docker

# Clean up containers
docker system prune -a

# Rebuild images
docker-compose -f docker-compose.production.yml build --no-cache
```

#### Wallet Connection Issues
1. Ensure MetaMask is installed and unlocked
2. Check network settings (Ethereum Mainnet)
3. Clear browser cache and cookies
4. Disable other wallet extensions temporarily

#### API Key Issues
```bash
# Verify environment variables
echo $OPENAI_API_KEY

# Check configuration
cat .env | grep -i api
```

### Getting Help

| Issue Type | Solution |
|------------|----------|
| **Installation** | Check [Installation Guide](./docs/INSTALLATION.md) |
| **Configuration** | Review [Configuration Guide](./docs/CONFIGURATION.md) |
| **API Issues** | See [API Documentation](./docs/API_REFERENCE.md) |
| **Security** | Consult [Security Guide](./docs/SECURITY.md) |
| **Bug Reports** | Open [GitHub Issue](https://github.com/0xClareYang/echo3-web3-security/issues) |

## Next Steps

1. **📖 Read Documentation**: Explore detailed guides in `./docs/`
2. **🔧 Customize Configuration**: Adjust settings for your use case
3. **🛡️ Review Security**: Understand security features and best practices
4. **🚀 Deploy to Production**: Use production deployment guide
5. **🤝 Join Community**: Connect with other users and developers

---

**Ready to secure your Web3 journey? Let's build something amazing together!** 🚀