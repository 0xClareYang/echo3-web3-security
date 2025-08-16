#!/usr/bin/env node

console.log(`
╔═══════════════════════════════════════════════════════════════╗
║                  🚀 Echo3 完整功能演示                        ║
║               AI-Powered Web3 Security & DeFi                ║
╚═══════════════════════════════════════════════════════════════╝
`);

const baseURL = 'http://localhost:3000';

async function makeRequest(endpoint, options = {}) {
    try {
        const response = await fetch(`${baseURL}${endpoint}`, options);
        return await response.json();
    } catch (error) {
        console.error(`请求失败 ${endpoint}:`, error.message);
        return null;
    }
}

async function demonstrateEcho3() {
    console.log('🔍 1. 检查Echo3系统状态...');
    const status = await makeRequest('/api/status');
    if (status) {
        console.log(`✅ Echo3 v${status.version} 在线运行`);
        console.log(`⏱️  运行时间: ${Math.floor(status.uptime / 60)}分钟`);
        console.log(`🛡️  保护状态: ${status.mode}`);
    }

    console.log('\n💰 2. 查看DeFi投资组合...');
    const portfolio = await makeRequest('/api/portfolio');
    if (portfolio && portfolio.success) {
        const overview = portfolio.portfolio.overview;
        console.log(`💎 总价值: $${overview.totalValue.toLocaleString()}`);
        console.log(`📈 平均APY: ${overview.weightedAPY.toFixed(2)}%`);
        console.log(`💵 月收益: $${overview.monthlyYield.toFixed(2)}`);
        
        console.log('\n   📊 资产分配:');
        Object.entries(portfolio.portfolio.assets).forEach(([symbol, asset]) => {
            console.log(`   ${symbol}: $${asset.valueUSD.toLocaleString()} (${asset.apy}% APY) - ${asset.protocol}`);
        });
    }

    console.log('\n🎯 3. 查看收益优化建议...');
    const yield = await makeRequest('/api/yield');
    if (yield && yield.success) {
        console.log('🏆 最佳收益机会:');
        yield.yield.opportunities.slice(0, 3).forEach((opp, index) => {
            console.log(`   ${index + 1}. ${opp.protocol} - ${opp.apy}% APY (${opp.risk} 风险)`);
            console.log(`      策略: ${opp.strategy}`);
        });
    }

    console.log('\n🤖 4. 自动交易状态...');
    const trading = await makeRequest('/api/trading');
    if (trading && trading.success) {
        console.log(`🔄 交易引擎: ${trading.trading.isActive ? '🟢 活跃' : '🔴 停止'}`);
        console.log(`📋 活跃策略: ${trading.trading.activeStrategies.length}个`);
        console.log(`💰 总利润: $${trading.trading.statistics.totalProfit.toFixed(2)}`);
        
        if (trading.trading.activeStrategies.length > 0) {
            console.log('\n   活跃策略:');
            trading.trading.activeStrategies.forEach(strategy => {
                console.log(`   • ${strategy.name} (${strategy.riskLevel} 风险)`);
            });
        }
    }

    console.log('\n🛡️ 5. 安全威胁检测...');
    const threats = await makeRequest('/api/threats');
    if (threats && threats.success) {
        const db = threats.threatIntelligence.database;
        console.log(`🗃️  恶意地址库: ${db.totalMaliciousAddresses}个地址`);
        console.log(`✅ 验证地址库: ${db.totalVerifiedAddresses}个地址`);
        console.log(`🔍 今日扫描: ${threats.threatIntelligence.recentAnalysis.totalScansToday}次交易`);
        console.log(`🛑 威胁拦截: ${threats.threatIntelligence.recentAnalysis.threatsDetectedToday}个威胁`);
    }

    console.log('\n🔍 6. 执行安全扫描演示...');
    const scanData = {
        from: '0x742d35Cc6634C0532925a3b8D0B48b7E3F1b5389',
        to: '0x1111111111111111111111111111111111111111', // 已知恶意地址
        value: (5 * 1e18).toString(), // 5 ETH
        gasPrice: '20000000000'
    };

    const scanResult = await makeRequest('/api/scan', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(scanData)
    });

    if (scanResult && scanResult.success) {
        console.log(`🚨 风险评分: ${scanResult.security.riskScore}% (${scanResult.security.riskLevel})`);
        console.log(`🤖 AI建议: ${scanResult.recommendation.action}`);
        console.log(`📝 威胁类型: ${scanResult.security.threatType}`);
        console.log(`⚡ 处理时间: ${scanResult.security.processingTime}ms`);
        
        if (scanResult.aiAnalysis.threatIntelligence) {
            const ti = scanResult.aiAnalysis.threatIntelligence;
            console.log('🔍 威胁情报分析:');
            if (ti.fromAddress) console.log(`   发送地址: ${ti.fromAddress.category}`);
            if (ti.toAddress) console.log(`   接收地址: ${ti.toAddress.category}`);
            if (ti.contractAnalysis) console.log(`   合约类型: ${ti.contractAnalysis.type}`);
        }
    }

    console.log('\n🎮 7. 演示自动交易控制...');
    // 激活自动交易
    const toggleResult = await makeRequest('/api/trading/toggle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: true })
    });

    if (toggleResult && toggleResult.success) {
        console.log(`✅ ${toggleResult.message}`);
    }

    console.log('\n📊 8. 实时监控状态...');
    const monitoring = await makeRequest('/api/monitoring');
    if (monitoring && monitoring.success) {
        const stats = monitoring.monitoring.stats;
        console.log(`📈 保护交易: ${stats.totalTransactions}笔`);
        console.log(`🛡️  拦截威胁: ${stats.threatsBlocked}个`);
        console.log(`📡 检测率: ${stats.threatDetectionRate}%`);
        console.log(`🔗 WebSocket连接: ${monitoring.monitoring.connectedClients}个`);
    }

    console.log(`
╔═══════════════════════════════════════════════════════════════╗
║                     🎉 演示完成！                             ║
║                                                               ║
║  🌐 完整仪表板: http://localhost:3000/dashboard               ║
║  📱 移动端友好: 响应式设计                                     ║
║  🔗 API文档: http://localhost:3000                            ║
║                                                               ║
║  核心功能 ✅:                                                  ║
║  • AI安全分析  • DeFi投资管理  • 自动交易策略                  ║
║  • 实时威胁监控  • 收益优化  • 多链支持                       ║
║                                                               ║
║  🛡️ Echo3: 为了您母亲的健康，保护Web3世界！                  ║
╚═══════════════════════════════════════════════════════════════╝
    `);
}

// 检查是否在Node.js环境中运行
if (typeof fetch === 'undefined') {
    console.log('⚠️  需要Node.js 18+支持fetch API');
    process.exit(1);
}

demonstrateEcho3().catch(console.error);