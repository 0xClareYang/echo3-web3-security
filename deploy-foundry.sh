#!/bin/bash
# Echo3 Foundry部署脚本 - Web3原生开发环境

echo "🛡️ Echo3 Foundry部署 - 为了您母亲的健康！"
echo "=================================================="

# 检查Foundry安装
if ! command -v forge &> /dev/null; then
    echo "📦 安装Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
fi

# 启动Anvil本地链
echo "⛓️ 启动Anvil本地区块链..."
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000 &
ANVIL_PID=$!

# 等待Anvil启动
sleep 5

# 部署智能合约
echo "📜 部署Echo3智能合约..."
cd contracts
forge install OpenZeppelin/openzeppelin-contracts
forge build

# 部署到本地链
forge create src/Echo3Agent.sol:Echo3Agent \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

forge create src/Echo3RiskAssessment.sol:Echo3RiskAssessment \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

echo "✅ 智能合约部署完成！"

# 启动后端API
echo "🚀 启动Echo3 API..."
cd ../
node server-simple.js &
API_PID=$!

echo "🎉 Echo3 Foundry环境部署完成！"
echo "📱 访问地址："
echo "   • API: http://localhost:3000"
echo "   • Anvil RPC: http://localhost:8545"
echo "   • Chain ID: 31337"
echo ""
echo "💰 测试账户（已预充值10000 ETH）："
echo "   0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "   私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo ""
echo "🛑 停止服务: kill $ANVIL_PID $API_PID"