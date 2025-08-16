-- Echo3 Production Database Initialization
-- 生产环境数据库结构和初始数据

-- ==============================================
-- 🔐 创建数据库和用户权限
-- ==============================================

-- 创建数据库扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- 设置时区
SET timezone = 'UTC';

-- ==============================================
-- 👥 用户管理表
-- ==============================================

CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user' NOT NULL,
    is_active BOOLEAN DEFAULT true,
    email_verified BOOLEAN DEFAULT false,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 用户设置表
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    security_level VARCHAR(20) DEFAULT 'medium',
    notification_preferences JSONB DEFAULT '{}',
    risk_tolerance INTEGER DEFAULT 50,
    preferred_chains TEXT[] DEFAULT ARRAY['ethereum', 'solana', 'bsc'],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- 🔍 风险分析记录表
-- ==============================================

CREATE TABLE IF NOT EXISTS risk_analyses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    session_id VARCHAR(255),
    transaction_hash VARCHAR(255),
    chain VARCHAR(50) NOT NULL,
    from_address VARCHAR(255) NOT NULL,
    to_address VARCHAR(255),
    contract_address VARCHAR(255),
    value_amount DECIMAL(30, 18),
    token_symbol VARCHAR(20),
    risk_score INTEGER NOT NULL,
    risk_level VARCHAR(20) NOT NULL,
    analysis_type VARCHAR(50) NOT NULL,
    ai_model_version VARCHAR(50),
    analysis_data JSONB NOT NULL,
    execution_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 地址信誉表
CREATE TABLE IF NOT EXISTS address_reputation (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    address VARCHAR(255) NOT NULL,
    chain VARCHAR(50) NOT NULL,
    reputation_score INTEGER DEFAULT 50,
    risk_factors TEXT[],
    last_activity TIMESTAMP WITH TIME ZONE,
    total_interactions INTEGER DEFAULT 0,
    flagged_interactions INTEGER DEFAULT 0,
    whitelist_status BOOLEAN DEFAULT false,
    blacklist_status BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(address, chain)
);

-- ==============================================
-- 💬 用户反馈系统
-- ==============================================

CREATE TABLE IF NOT EXISTS user_feedback (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    session_id VARCHAR(255),
    transaction_hash VARCHAR(255),
    analysis_id UUID REFERENCES risk_analyses(id),
    feedback_type VARCHAR(50) NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    category VARCHAR(50) NOT NULL,
    original_risk_score INTEGER,
    suggested_risk_score INTEGER,
    comments TEXT,
    context JSONB,
    status VARCHAR(20) DEFAULT 'PENDING',
    quality_score DECIMAL(3,2),
    reviewed_by UUID REFERENCES users(id),
    review_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 反馈奖励记录
CREATE TABLE IF NOT EXISTS feedback_rewards (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    feedback_id UUID REFERENCES user_feedback(id),
    reward_points INTEGER NOT NULL,
    reward_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- 🌉 跨链安全分析
-- ==============================================

CREATE TABLE IF NOT EXISTS cross_chain_analyses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    source_chain VARCHAR(50) NOT NULL,
    target_chain VARCHAR(50) NOT NULL,
    bridge_protocol VARCHAR(100),
    source_address VARCHAR(255) NOT NULL,
    target_address VARCHAR(255) NOT NULL,
    amount DECIMAL(30, 18),
    token_contract VARCHAR(255),
    bridge_contract VARCHAR(255),
    overall_risk_score INTEGER NOT NULL,
    bridge_risk INTEGER,
    fund_flow_risk INTEGER,
    mev_risk INTEGER,
    liquidity_risk INTEGER,
    analysis_details JSONB,
    suspicious_activity JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- 📊 系统监控和审计
-- ==============================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    source VARCHAR(100) NOT NULL,
    user_id UUID REFERENCES users(id),
    session_id VARCHAR(255),
    details JSONB,
    outcome VARCHAR(50),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 安全事件表
CREATE TABLE IF NOT EXISTS security_events (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    description TEXT NOT NULL,
    source VARCHAR(100) NOT NULL,
    affected_user_id UUID REFERENCES users(id),
    metadata JSONB,
    resolved BOOLEAN DEFAULT false,
    resolved_by UUID REFERENCES users(id),
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- 系统指标表
CREATE TABLE IF NOT EXISTS system_metrics (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(20, 6) NOT NULL,
    metric_unit VARCHAR(20),
    tags JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- 📈 性能优化索引
-- ==============================================

-- 用户相关索引
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = true;

-- 风险分析索引
CREATE INDEX IF NOT EXISTS idx_risk_analyses_user_id ON risk_analyses(user_id);
CREATE INDEX IF NOT EXISTS idx_risk_analyses_chain ON risk_analyses(chain);
CREATE INDEX IF NOT EXISTS idx_risk_analyses_created_at ON risk_analyses(created_at);
CREATE INDEX IF NOT EXISTS idx_risk_analyses_risk_score ON risk_analyses(risk_score);
CREATE INDEX IF NOT EXISTS idx_risk_analyses_tx_hash ON risk_analyses(transaction_hash);

-- 地址信誉索引
CREATE INDEX IF NOT EXISTS idx_address_reputation_address ON address_reputation(address);
CREATE INDEX IF NOT EXISTS idx_address_reputation_chain ON address_reputation(chain);
CREATE INDEX IF NOT EXISTS idx_address_reputation_score ON address_reputation(reputation_score);

-- 反馈系统索引
CREATE INDEX IF NOT EXISTS idx_user_feedback_user_id ON user_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_user_feedback_status ON user_feedback(status);
CREATE INDEX IF NOT EXISTS idx_user_feedback_created_at ON user_feedback(created_at);

-- 跨链分析索引
CREATE INDEX IF NOT EXISTS idx_cross_chain_source_chain ON cross_chain_analyses(source_chain);
CREATE INDEX IF NOT EXISTS idx_cross_chain_target_chain ON cross_chain_analyses(target_chain);
CREATE INDEX IF NOT EXISTS idx_cross_chain_risk_score ON cross_chain_analyses(overall_risk_score);

-- 审计日志索引
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON audit_logs(severity);

-- 安全事件索引
CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events(event_type);
CREATE INDEX IF NOT EXISTS idx_security_events_severity ON security_events(severity);
CREATE INDEX IF NOT EXISTS idx_security_events_resolved ON security_events(resolved);
CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON security_events(created_at);

-- 系统指标索引
CREATE INDEX IF NOT EXISTS idx_system_metrics_name ON system_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_system_metrics_created_at ON system_metrics(created_at);

-- ==============================================
-- 🔧 数据库函数和触发器
-- ==============================================

-- 自动更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为用户表创建更新时间戳触发器
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_settings_updated_at 
    BEFORE UPDATE ON user_settings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_address_reputation_updated_at 
    BEFORE UPDATE ON address_reputation 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ==============================================
-- 📊 初始数据插入
-- ==============================================

-- 创建系统管理员用户
INSERT INTO users (email, password_hash, role, is_active, email_verified) 
VALUES 
    ('admin@echo3.security', crypt('change_this_password', gen_salt('bf')), 'admin', true, true)
ON CONFLICT (email) DO NOTHING;

-- 插入系统默认设置
INSERT INTO user_settings (user_id, security_level, risk_tolerance) 
SELECT id, 'high', 30 FROM users WHERE email = 'admin@echo3.security'
ON CONFLICT DO NOTHING;

-- 初始化一些已知的安全地址
INSERT INTO address_reputation (address, chain, reputation_score, risk_factors, whitelist_status) VALUES
    ('0x0000000000000000000000000000000000000000', 'ethereum', 100, ARRAY['burn_address'], true),
    ('0x000000000000000000000000000000000000dead', 'ethereum', 100, ARRAY['burn_address'], true),
    ('11111111111111111111111111111112', 'solana', 100, ARRAY['system_program'], true)
ON CONFLICT (address, chain) DO NOTHING;

-- ==============================================
-- 🔍 数据库视图
-- ==============================================

-- 用户统计视图
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    u.id,
    u.email,
    u.role,
    u.created_at,
    COUNT(ra.id) as total_analyses,
    AVG(ra.risk_score) as avg_risk_score,
    COUNT(uf.id) as total_feedback,
    AVG(uf.rating) as avg_feedback_rating
FROM users u
LEFT JOIN risk_analyses ra ON u.id = ra.user_id
LEFT JOIN user_feedback uf ON u.id = uf.user_id
GROUP BY u.id, u.email, u.role, u.created_at;

-- 风险分析统计视图
CREATE OR REPLACE VIEW risk_analysis_stats AS
SELECT 
    chain,
    COUNT(*) as total_analyses,
    AVG(risk_score) as avg_risk_score,
    COUNT(CASE WHEN risk_level = 'HIGH' THEN 1 END) as high_risk_count,
    COUNT(CASE WHEN risk_level = 'CRITICAL' THEN 1 END) as critical_risk_count,
    DATE_TRUNC('day', created_at) as analysis_date
FROM risk_analyses
GROUP BY chain, DATE_TRUNC('day', created_at);

-- ==============================================
-- 🛡️ 权限设置
-- ==============================================

-- 确保数据库安全性
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO echo3_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO echo3_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO echo3_user;

-- 为监控创建只读用户
CREATE USER echo3_monitor WITH PASSWORD 'monitor_password';
GRANT CONNECT ON DATABASE echo3_production TO echo3_monitor;
GRANT USAGE ON SCHEMA public TO echo3_monitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO echo3_monitor;

-- 设置默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO echo3_monitor;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO echo3_user;

-- 数据库初始化完成
INSERT INTO system_metrics (metric_name, metric_value, metric_unit) 
VALUES ('database_initialized', 1, 'boolean');

COMMIT;