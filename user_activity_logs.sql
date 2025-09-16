-- 사용자 활동 로그 테이블 생성 (MSSQL)
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='user_activity_logs' AND xtype='U')
BEGIN
    CREATE TABLE user_activity_logs (
        id BIGINT IDENTITY(1,1) PRIMARY KEY,
        timestamp DATETIME2 NOT NULL,
        client_ip VARCHAR(45) NOT NULL,
        user_agent NVARCHAR(MAX),
        method VARCHAR(10) NOT NULL,
        url NVARCHAR(500) NOT NULL,
        user_id VARCHAR(50),
        user_name NVARCHAR(100),
        trade_code VARCHAR(50),
        trade_name NVARCHAR(100),
        access_type VARCHAR(50),
        action NVARCHAR(100) NOT NULL,
        details NVARCHAR(MAX),
        status_code INT,
        response_time_ms INT,
        platform VARCHAR(50),
        browser NVARCHAR(100),
        device NVARCHAR(100),
        os NVARCHAR(100),
        is_mobile BIT DEFAULT 0,
        is_tablet BIT DEFAULT 0,
        is_pc BIT DEFAULT 0,
        program_name NVARCHAR(100),
        session_id VARCHAR(100),
        created_at DATETIME2 DEFAULT GETDATE()
    );

    -- 인덱스 생성
    CREATE INDEX idx_timestamp ON user_activity_logs (timestamp);
    CREATE INDEX idx_user_id ON user_activity_logs (user_id);
    CREATE INDEX idx_trade_code ON user_activity_logs (trade_code);
    CREATE INDEX idx_action ON user_activity_logs (action);
    CREATE INDEX idx_client_ip ON user_activity_logs (client_ip);
    CREATE INDEX idx_platform ON user_activity_logs (platform);
    CREATE INDEX idx_browser ON user_activity_logs (browser);
    CREATE INDEX idx_device ON user_activity_logs (device);
    CREATE INDEX idx_session_id ON user_activity_logs (session_id);

    PRINT 'User activity logs table created successfully';
END
ELSE
BEGIN
    PRINT 'User activity logs table already exists';
END

-- 로그 보관 정책을 위한 파티션 테이블 (선택사항)
-- 3개월 단위로 파티션을 나누어 성능 향상 및 관리 용이성 확보
/*
CREATE TABLE user_activity_logs_partitioned (
    id BIGINT AUTO_INCREMENT,
    timestamp DATETIME NOT NULL,
    client_ip VARCHAR(45) NOT NULL,
    user_agent TEXT,
    method VARCHAR(10) NOT NULL,
    url VARCHAR(500) NOT NULL,
    user_id VARCHAR(50),
    user_name VARCHAR(100),
    trade_code VARCHAR(50),
    trade_name VARCHAR(100),
    access_type VARCHAR(50),
    action VARCHAR(100) NOT NULL,
    details JSON,
    status_code INT,
    response_time_ms INT,
    platform VARCHAR(50),
    browser VARCHAR(100),
    device VARCHAR(100),
    os VARCHAR(100),
    is_mobile BOOLEAN DEFAULT FALSE,
    is_tablet BOOLEAN DEFAULT FALSE,
    is_pc BOOLEAN DEFAULT FALSE,
    program_name VARCHAR(100),
    session_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (YEAR(timestamp) * 100 + MONTH(timestamp)) (
    PARTITION p202401 VALUES LESS THAN (202402),
    PARTITION p202402 VALUES LESS THAN (202403),
    PARTITION p202403 VALUES LESS THAN (202404),
    PARTITION p202404 VALUES LESS THAN (202405),
    PARTITION p202405 VALUES LESS THAN (202406),
    PARTITION p202406 VALUES LESS THAN (202407),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
*/

-- 로그 통계 뷰 생성
IF EXISTS (SELECT * FROM sysobjects WHERE name='user_activity_stats' AND xtype='V')
    DROP VIEW user_activity_stats;
GO

CREATE VIEW user_activity_stats AS
SELECT 
    CAST(timestamp AS DATE) as log_date,
    COUNT(*) as total_requests,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT trade_code) as unique_trades,
    COUNT(DISTINCT client_ip) as unique_ips,
    AVG(CAST(response_time_ms AS FLOAT)) as avg_response_time,
    COUNT(CASE WHEN status_code >= 400 THEN 1 END) as error_count,
    COUNT(CASE WHEN is_mobile = 1 THEN 1 END) as mobile_requests,
    COUNT(CASE WHEN is_tablet = 1 THEN 1 END) as tablet_requests,
    COUNT(CASE WHEN is_pc = 1 THEN 1 END) as pc_requests
FROM user_activity_logs 
WHERE timestamp >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(timestamp AS DATE)
GO

-- 사용자별 활동 통계 뷰
IF EXISTS (SELECT * FROM sysobjects WHERE name='user_activity_summary' AND xtype='V')
    DROP VIEW user_activity_summary;
GO

CREATE VIEW user_activity_summary AS
SELECT 
    user_id,
    user_name,
    trade_code,
    trade_name,
    COUNT(*) as total_actions,
    COUNT(DISTINCT CAST(timestamp AS DATE)) as active_days,
    MIN(timestamp) as first_activity,
    MAX(timestamp) as last_activity,
    COUNT(DISTINCT action) as unique_actions,
    AVG(CAST(response_time_ms AS FLOAT)) as avg_response_time,
    COUNT(DISTINCT platform) as platforms_used,
    COUNT(DISTINCT browser) as browsers_used,
    COUNT(DISTINCT device) as devices_used
FROM user_activity_logs 
WHERE user_id IS NOT NULL
GROUP BY user_id, user_name, trade_code, trade_name
GO

-- 거래처별 활동 통계 뷰
IF EXISTS (SELECT * FROM sysobjects WHERE name='trade_activity_summary' AND xtype='V')
    DROP VIEW trade_activity_summary;
GO

CREATE VIEW trade_activity_summary AS
SELECT 
    trade_code,
    trade_name,
    COUNT(*) as total_requests,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT CAST(timestamp AS DATE)) as active_days,
    MIN(timestamp) as first_activity,
    MAX(timestamp) as last_activity,
    COUNT(DISTINCT action) as unique_actions,
    COUNT(DISTINCT platform) as platforms_used,
    COUNT(DISTINCT browser) as browsers_used,
    COUNT(DISTINCT device) as devices_used
FROM user_activity_logs 
WHERE trade_code IS NOT NULL
GROUP BY trade_code, trade_name
GO

-- 플랫폼별 통계 뷰
IF EXISTS (SELECT * FROM sysobjects WHERE name='platform_activity_summary' AND xtype='V')
    DROP VIEW platform_activity_summary;
GO

CREATE VIEW platform_activity_summary AS
SELECT 
    platform,
    COUNT(*) as total_requests,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT trade_code) as unique_trades,
    AVG(CAST(response_time_ms AS FLOAT)) as avg_response_time,
    COUNT(CASE WHEN status_code >= 400 THEN 1 END) as error_count
FROM user_activity_logs 
WHERE platform IS NOT NULL
GROUP BY platform
GO

-- 브라우저별 통계 뷰
IF EXISTS (SELECT * FROM sysobjects WHERE name='browser_activity_summary' AND xtype='V')
    DROP VIEW browser_activity_summary;
GO

CREATE VIEW browser_activity_summary AS
SELECT 
    browser,
    COUNT(*) as total_requests,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT trade_code) as unique_trades,
    AVG(CAST(response_time_ms AS FLOAT)) as avg_response_time,
    COUNT(CASE WHEN status_code >= 400 THEN 1 END) as error_count
FROM user_activity_logs 
WHERE browser IS NOT NULL
GROUP BY browser
GO

-- 디바이스별 통계 뷰
IF EXISTS (SELECT * FROM sysobjects WHERE name='device_activity_summary' AND xtype='V')
    DROP VIEW device_activity_summary;
GO

CREATE VIEW device_activity_summary AS
SELECT 
    device,
    COUNT(*) as total_requests,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT trade_code) as unique_trades,
    AVG(CAST(response_time_ms AS FLOAT)) as avg_response_time,
    COUNT(CASE WHEN status_code >= 400 THEN 1 END) as error_count
FROM user_activity_logs 
WHERE device IS NOT NULL
GROUP BY device
GO 