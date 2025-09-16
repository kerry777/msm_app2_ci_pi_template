const sql = require('mssql');

class DatabaseLogger {
  constructor() {
    this.pool = null;
    this.isConnected = false;
  }

  // 데이터베이스 연결 초기화
  async initialize(config) {
    try {
      this.pool = new sql.ConnectionPool({
        server: config.host || 'localhost',
        port: config.port || 1433,
        user: config.user || 'sa',
        password: config.password || '',
        database: config.database || 'mdm_db',
        options: {
          encrypt: false,
          trustServerCertificate: true
        }
      });

      // 연결 테스트
      await this.pool.connect();
      
      this.isConnected = true;
      console.log(`[${new Date().toLocaleString('ko-KR')}] Database logger connected successfully`);
      
      // 테이블 존재 확인 및 생성
      await this.ensureTableExists();
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Database logger connection failed:`, error.message);
      this.isConnected = false;
    }
  }

  // 테이블 존재 확인 및 생성
  async ensureTableExists() {
    try {
      const createTableSQL = `
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
      `;
      
      await this.pool.request().query(createTableSQL);
      console.log(`[${new Date().toLocaleString('ko-KR')}] User activity logs table ensured`);
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to ensure table exists:`, error.message);
    }
  }

  // 사용자 활동 로그 저장
  async logUserActivity(logData) {
    if (!this.isConnected || !this.pool) {
      console.warn(`[${new Date().toLocaleString('ko-KR')}] Database not connected, skipping log save`);
      return false;
    }

    try {
      const request = this.pool.request();
      const sql = `
        INSERT INTO user_activity_logs (
          timestamp, client_ip, user_agent, method, url, 
          user_id, user_name, trade_code, trade_name, access_type,
          action, details, status_code, response_time_ms,
          platform, browser, device, os, is_mobile, is_tablet, is_pc,
          program_name, session_id
        ) VALUES (@timestamp, @clientIP, @userAgent, @method, @url, 
                  @userId, @userName, @tradeCode, @tradeName, @accessType,
                  @action, @details, @statusCode, @responseTimeMs,
                  @platform, @browser, @device, @os, @isMobile, @isTablet, @isPc,
                  @programName, @sessionId)
      `;

      const result = await request
        .input('timestamp', sql.DateTime2, new Date(logData.timestamp))
        .input('clientIP', sql.VarChar(45), logData.clientIP)
        .input('userAgent', sql.NVarChar(sql.MAX), logData.userAgent)
        .input('method', sql.VarChar(10), logData.method)
        .input('url', sql.NVarChar(500), logData.url)
        .input('userId', sql.VarChar(50), logData.userId)
        .input('userName', sql.NVarChar(100), logData.userName)
        .input('tradeCode', sql.VarChar(50), logData.tradeCode)
        .input('tradeName', sql.NVarChar(100), logData.tradeName)
        .input('accessType', sql.VarChar(50), logData.accessType)
        .input('action', sql.NVarChar(100), logData.action)
        .input('details', sql.NVarChar(sql.MAX), JSON.stringify(logData.details))
        .input('statusCode', sql.Int, logData.statusCode || null)
        .input('responseTimeMs', sql.Int, logData.responseTimeMs || null)
        .input('platform', sql.VarChar(50), logData.platform || null)
        .input('browser', sql.NVarChar(100), logData.browser || null)
        .input('device', sql.NVarChar(100), logData.device || null)
        .input('os', sql.NVarChar(100), logData.os || null)
        .input('isMobile', sql.Bit, logData.isMobile || false)
        .input('isTablet', sql.Bit, logData.isTablet || false)
        .input('isPc', sql.Bit, logData.isPc || false)
        .input('programName', sql.NVarChar(100), logData.programName || null)
        .input('sessionId', sql.VarChar(100), logData.sessionId || null)
        .query(sql);

      return result.recordset[0]?.id || true;
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to save user activity log:`, error.message);
      return false;
    }
  }

  // 로그 통계 조회
  async getActivityStats(days = 30) {
    if (!this.isConnected || !this.pool) {
      return null;
    }

    try {
      const sql = `
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
        WHERE timestamp >= DATEADD(DAY, -${days}, GETDATE())
        GROUP BY CAST(timestamp AS DATE)
        ORDER BY log_date DESC
      `;

      const result = await this.pool.request().query(sql);
      return result.recordset;
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to get activity stats:`, error.message);
      return null;
    }
  }

  // 사용자별 활동 요약 조회
  async getUserActivitySummary(limit = 50) {
    if (!this.isConnected || !this.pool) {
      return null;
    }

    try {
      const sql = `
        SELECT TOP ${limit}
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
        ORDER BY total_actions DESC
      `;

      const result = await this.pool.request().query(sql);
      return result.recordset;
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to get user activity summary:`, error.message);
      return null;
    }
  }

  // 거래처별 활동 요약 조회
  async getTradeActivitySummary(limit = 50) {
    if (!this.isConnected || !this.pool) {
      return null;
    }

    try {
      const sql = `
        SELECT TOP ${limit}
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
        ORDER BY total_requests DESC
      `;

      const result = await this.pool.request().query(sql);
      return result.recordset;
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to get trade activity summary:`, error.message);
      return null;
    }
  }

  // 플랫폼별 활동 요약 조회
  async getPlatformActivitySummary(limit = 50) {
    if (!this.isConnected || !this.pool) {
      return null;
    }

    try {
      const sql = `
        SELECT TOP ${limit}
          platform,
          COUNT(*) as total_requests,
          COUNT(DISTINCT user_id) as unique_users,
          COUNT(DISTINCT trade_code) as unique_trades,
          AVG(CAST(response_time_ms AS FLOAT)) as avg_response_time,
          COUNT(CASE WHEN status_code >= 400 THEN 1 END) as error_count
        FROM user_activity_logs 
        WHERE platform IS NOT NULL
        GROUP BY platform
        ORDER BY total_requests DESC
      `;

      const result = await this.pool.request().query(sql);
      return result.recordset;
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to get platform activity summary:`, error.message);
      return null;
    }
  }

  // 브라우저별 활동 요약 조회
  async getBrowserActivitySummary(limit = 50) {
    if (!this.isConnected || !this.pool) {
      return null;
    }

    try {
      const sql = `
        SELECT TOP ${limit}
          browser,
          COUNT(*) as total_requests,
          COUNT(DISTINCT user_id) as unique_users,
          COUNT(DISTINCT trade_code) as unique_trades,
          AVG(CAST(response_time_ms AS FLOAT)) as avg_response_time,
          COUNT(CASE WHEN status_code >= 400 THEN 1 END) as error_count
        FROM user_activity_logs 
        WHERE browser IS NOT NULL
        GROUP BY browser
        ORDER BY total_requests DESC
      `;

      const result = await this.pool.request().query(sql);
      return result.recordset;
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to get browser activity summary:`, error.message);
      return null;
    }
  }

  // 디바이스별 활동 요약 조회
  async getDeviceActivitySummary(limit = 50) {
    if (!this.isConnected || !this.pool) {
      return null;
    }

    try {
      const sql = `
        SELECT TOP ${limit}
          device,
          COUNT(*) as total_requests,
          COUNT(DISTINCT user_id) as unique_users,
          COUNT(DISTINCT trade_code) as unique_trades,
          AVG(CAST(response_time_ms AS FLOAT)) as avg_response_time,
          COUNT(CASE WHEN status_code >= 400 THEN 1 END) as error_count
        FROM user_activity_logs 
        WHERE device IS NOT NULL
        GROUP BY device
        ORDER BY total_requests DESC
      `;

      const result = await this.pool.request().query(sql);
      return result.recordset;
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to get device activity summary:`, error.message);
      return null;
    }
  }

  // 오래된 로그 정리 (선택사항)
  async cleanupOldLogs(daysToKeep = 90) {
    if (!this.isConnected || !this.pool) {
      return false;
    }

    try {
      const sql = `
        DELETE FROM user_activity_logs 
        WHERE timestamp < DATEADD(DAY, -${daysToKeep}, GETDATE())
      `;

      const result = await this.pool.request().query(sql);
      console.log(`[${new Date().toLocaleString('ko-KR')}] Cleaned up ${result.rowsAffected[0]} old log records`);
      return result.rowsAffected[0];
      
    } catch (error) {
      console.error(`[${new Date().toLocaleString('ko-KR')}] Failed to cleanup old logs:`, error.message);
      return false;
    }
  }

  // 연결 종료
  async close() {
    if (this.pool) {
      await this.pool.close();
      this.isConnected = false;
      console.log(`[${new Date().toLocaleString('ko-KR')}] Database logger connection closed`);
    }
  }
}

module.exports = new DatabaseLogger(); 