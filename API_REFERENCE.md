# 🌐 API Reference

## Base URL
```
http://localhost:3000/api/v2
```

## Authentication
Most endpoints require no authentication for basic usage. Wallet-specific operations require wallet connection.

---

## Core Endpoints

### Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-16T10:30:00Z",
  "version": "3.1.0",
  "uptime": 3600,
  "system": {
    "memory": {
      "used": 125,
      "total": 512,
      "unit": "MB"
    },
    "platform": "linux"
  },
  "performance": {
    "transactionsProcessed": 15420,
    "threatsBlocked": 142,
    "systemHealth": {
      "status": "optimal",
      "score": 98.5
    }
  }
}
```

### Metrics
```http
GET /metrics
```

**Response:**
```json
{
  "timestamp": "2024-01-16T10:30:00Z",
  "platform": {
    "name": "Echo3",
    "version": "3.1.0",
    "uptime": 3600
  },
  "performance": {
    "transactionsProcessed": 15420,
    "threatsBlocked": 142,
    "averageResponseTime": 89,
    "systemLoad": 25
  },
  "security": {
    "overallScore": 96.8,
    "activeThreats": 0,
    "riskDistribution": {
      "low": 85,
      "medium": 12,
      "high": 3
    }
  }
}
```

---

## Security Analysis

### Analyze Transaction
```http
POST /analyze
```

**Request Body:**
```json
{
  "from": "0x742d35Cc6634C0532925a3b8D0B48b7E3F1b5389",
  "to": "0x8ba1f109551bd432803012645hac136c82153ec2",
  "value": "1000000000000000000",
  "data": "0x...",
  "gasPrice": "20000000000"
}
```

**Response:**
```json
{
  "success": true,
  "transactionId": "tx_abc123def456",
  "timestamp": "2024-01-16T10:30:00Z",
  "input": {
    "from": "0x742d35Cc6634C0532925a3b8D0B48b7E3F1b5389",
    "to": "0x8ba1f109551bd432803012645hac136c82153ec2",
    "value": "1000000000000000000"
  },
  "risk": {
    "score": 0.23,
    "level": "low",
    "classification": "LOW",
    "confidence": 0.94
  },
  "recommendation": {
    "action": "ALLOW",
    "severity": "LOW",
    "message": "Transaction appears safe. Echo3 is watching.",
    "suggestions": []
  },
  "security": {
    "score": 94.2,
    "threats": {
      "malware": false,
      "phishing": false,
      "sanctions": false
    },
    "vulnerabilities": []
  },
  "compliance": {
    "amlCompliant": true,
    "kycRequired": false,
    "jurisdictionCheck": "passed",
    "sanctionsScreening": "clear"
  },
  "metadata": {
    "processingTime": 156,
    "engineVersion": "3.1.0",
    "analysisDepth": "comprehensive"
  }
}
```

### Scan Address/Contract
```http
POST /scan
```

**Request Body:**
```json
{
  "from": "0x742d35Cc6634C0532925a3b8D0B48b7E3F1b5389",
  "to": "0x8ba1f109551bd432803012645hac136c82153ec2",
  "value": "1000000000000000000",
  "walletScan": true
}
```

**Response:**
```json
{
  "success": true,
  "transactionId": "scan_def789ghi012",
  "timestamp": "2024-01-16T10:30:00Z",
  "security": {
    "riskScore": 15,
    "riskLevel": "LOW",
    "threatType": "clean",
    "processingTime": 89
  },
  "recommendation": {
    "action": "ALLOW"
  },
  "aiAnalysis": {
    "confidence": 96,
    "threatIntelligence": {
      "fromAddress": {
        "category": "verified"
      },
      "toAddress": {
        "category": "verified"
      },
      "contractAnalysis": {
        "type": "defi_protocol"
      }
    }
  }
}
```

---

## Trading & Portfolio

### Get Portfolio Data
```http
GET /portfolio
```

**Response:**
```json
{
  "success": true,
  "portfolio": {
    "overview": {
      "totalValue": 24570,
      "weightedAPY": 5.29,
      "monthlyYield": 108.21,
      "yearlyYield": 1298.52,
      "riskScore": 0.23
    },
    "assets": {
      "ETH": {
        "balance": 5.2,
        "valueUSD": 9620,
        "allocation": 39.1,
        "apy": 4.2,
        "protocol": "Lido Staking"
      },
      "USDC": {
        "balance": 8500,
        "valueUSD": 8500,
        "allocation": 34.6,
        "apy": 8.5,
        "protocol": "Aave Lending"
      }
    }
  }
}
```

### Get Yield Opportunities
```http
GET /yield
```

**Response:**
```json
{
  "success": true,
  "yield": {
    "opportunities": [
      {
        "protocol": "Curve Finance",
        "pool": "USDC-USDT-DAI",
        "apy": 12.5,
        "tvl": "$245M",
        "risk": "Low",
        "strategy": "Stable coin yield farming",
        "minDeposit": 1000,
        "lockPeriod": "None"
      },
      {
        "protocol": "Uniswap V3",
        "pool": "ETH-USDC",
        "apy": 18.2,
        "tvl": "$180M",
        "risk": "Medium",
        "strategy": "Liquidity provision with concentrated range",
        "minDeposit": 500,
        "lockPeriod": "None"
      }
    ]
  }
}
```

### Toggle Auto Trading
```http
POST /trading/toggle
```

**Request Body:**
```json
{
  "active": true,
  "walletAddress": "0x742d35Cc6634C0532925a3b8D0B48b7E3F1b5389",
  "walletBalance": "5.2",
  "strategies": ["dca", "yield_harvest", "stop_loss"]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Auto trading activated successfully!",
  "isActive": true,
  "strategies": [
    {
      "name": "Dollar Cost Averaging",
      "status": "active",
      "riskLevel": "Low"
    },
    {
      "name": "Yield Harvesting",
      "status": "active",
      "riskLevel": "Low"
    },
    {
      "name": "Stop Loss Protection",
      "status": "active",
      "riskLevel": "Medium"
    }
  ]
}
```

### Get Trading Status
```http
GET /trading
```

**Response:**
```json
{
  "success": true,
  "trading": {
    "isActive": true,
    "activeStrategies": [
      {
        "name": "Dollar Cost Averaging",
        "description": "Regular purchases regardless of price",
        "riskLevel": "Low",
        "interval": "1 week",
        "active": true
      }
    ],
    "statistics": {
      "totalProfit": 1672.58,
      "totalTrades": 245,
      "winRate": 67.3,
      "avgProfit": 6.82
    }
  }
}
```

---

## Threat Intelligence

### Get Threat Data
```http
GET /threats
```

**Response:**
```json
{
  "success": true,
  "threatIntelligence": {
    "database": {
      "totalMaliciousAddresses": 15420,
      "totalVerifiedAddresses": 8932,
      "lastDatabaseUpdate": "2024-01-16T10:00:00Z"
    },
    "recentAnalysis": {
      "totalScansToday": 1247,
      "threatsDetectedToday": 23,
      "averageProcessingTime": 91
    },
    "categories": [
      "phishing_contracts",
      "honeypot_tokens",
      "rug_pull_projects",
      "sandwich_attackers",
      "mev_bots"
    ]
  }
}
```

### Get System Status
```http
GET /system
```

**Response:**
```json
{
  "success": true,
  "system": {
    "uptime": 86400,
    "memory": {
      "used": 245,
      "total": 512,
      "percentage": 48
    },
    "cpu": {
      "usage": 25
    },
    "network": {
      "status": "excellent",
      "latency": 18
    },
    "security": {
      "status": "maximum",
      "aiEngine": "Neural Guard v3.1",
      "protection": "active"
    }
  }
}
```

### Get MEV Protection Data
```http
GET /mev
```

**Response:**
```json
{
  "success": true,
  "mev": {
    "protection": {
      "status": "active",
      "attacksPrevented": 142,
      "amountSaved": 15420,
      "lastProtection": "2024-01-16T09:45:00Z"
    },
    "analysis": {
      "frontrunningDetection": true,
      "sandwichAttackDetection": true,
      "priceImpactAnalysis": true
    },
    "statistics": {
      "totalScans": 1247,
      "mevDetected": 23,
      "successRate": 98.1
    }
  }
}
```

### Get Monitoring Data
```http
GET /monitoring
```

**Response:**
```json
{
  "success": true,
  "monitoring": {
    "stats": {
      "totalTransactions": 15420,
      "threatsBlocked": 142,
      "threatDetectionRate": 96.8,
      "systemHealth": 98.5
    },
    "connectedClients": 7,
    "blockchainNetworks": [
      {
        "name": "Ethereum",
        "status": "online",
        "latency": 15
      },
      {
        "name": "BSC",
        "status": "online",
        "latency": 22
      },
      {
        "name": "Polygon",
        "status": "online",
        "latency": 18
      }
    ]
  }
}
```

---

## Error Handling

### Error Response Format
```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {
    "field": "validation error details"
  },
  "timestamp": "2024-01-16T10:30:00Z"
}
```

### Common Error Codes

| Code | Description | Status Code |
|------|-------------|-------------|
| `INVALID_REQUEST` | Request validation failed | 400 |
| `UNAUTHORIZED` | Authentication required | 401 |
| `FORBIDDEN` | Insufficient permissions | 403 |
| `NOT_FOUND` | Resource not found | 404 |
| `RATE_LIMITED` | Too many requests | 429 |
| `INTERNAL_ERROR` | Server error | 500 |
| `SERVICE_UNAVAILABLE` | Service temporarily unavailable | 503 |

---

## Rate Limiting

| Endpoint Category | Limit | Window |
|------------------|-------|--------|
| **Health/Metrics** | 100 requests | 1 minute |
| **Security Analysis** | 50 requests | 1 minute |
| **Trading Operations** | 20 requests | 1 minute |
| **General API** | 200 requests | 1 minute |

---

## SDKs and Integration

### JavaScript SDK Example
```javascript
class Echo3Client {
  constructor(baseUrl = 'http://localhost:3000/api/v2') {
    this.baseUrl = baseUrl;
  }

  async analyzeTransaction(txData) {
    const response = await fetch(`${this.baseUrl}/analyze`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(txData)
    });
    return response.json();
  }

  async getHealth() {
    const response = await fetch(`${this.baseUrl}/health`);
    return response.json();
  }

  async toggleTrading(config) {
    const response = await fetch(`${this.baseUrl}/trading/toggle`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(config)
    });
    return response.json();
  }
}

// Usage
const echo3 = new Echo3Client();
const health = await echo3.getHealth();
console.log('System status:', health.status);
```

### Python SDK Example
```python
import requests

class Echo3Client:
    def __init__(self, base_url='http://localhost:3000/api/v2'):
        self.base_url = base_url
    
    def analyze_transaction(self, tx_data):
        response = requests.post(
            f'{self.base_url}/analyze',
            json=tx_data
        )
        return response.json()
    
    def get_health(self):
        response = requests.get(f'{self.base_url}/health')
        return response.json()

# Usage
echo3 = Echo3Client()
health = echo3.get_health()
print(f"System status: {health['status']}")
```

---

**Need help? Check our [troubleshooting guide](./TROUBLESHOOTING.md) or [open an issue](https://github.com/0xClareYang/echo3-web3-security/issues).**