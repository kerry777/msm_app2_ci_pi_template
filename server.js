const express = require('express');
const dotenv = require('dotenv');
const path = require('path');
const cors = require('cors');
const databaseLogger = require('./database_logger');
const fs = require('fs');

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const app = express();
const port = process.env.PORT || 4100;

// 로그 함수 - 현재 시간을 포함한 로그 출력
const logWithTimestamp = (message) => {
  const now = new Date();
  const timestamp = now.toLocaleString('ko-KR', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
  console.log(`[${timestamp}] ${message}`);
};

// User-Agent 파싱 함수
const parseUserAgent = (userAgent) => {
  const ua = userAgent || '';
  const result = {
    platform: 'Unknown',
    browser: 'Unknown',
    device: 'Unknown',
    os: 'Unknown',
    isMobile: false,
    isTablet: false,
    isPc: false
  };

  // 플랫폼 감지
  if (ua.includes('Android')) {
    result.platform = 'Android';
    result.os = 'Android';
    result.isMobile = true;
  } else if (ua.includes('iPhone') || ua.includes('iPad')) {
    result.platform = 'iOS';
    result.os = 'iOS';
    if (ua.includes('iPad')) {
      result.isTablet = true;
    } else {
      result.isMobile = true;
    }
  } else if (ua.includes('Windows')) {
    result.platform = 'Windows';
    result.os = 'Windows';
    result.isPc = true;
  } else if (ua.includes('Mac OS X')) {
    result.platform = 'macOS';
    result.os = 'macOS';
    result.isPc = true;
  } else if (ua.includes('Linux')) {
    result.platform = 'Linux';
    result.os = 'Linux';
    result.isPc = true;
  }

  // 브라우저 감지
  if (ua.includes('Chrome')) {
    result.browser = 'Chrome';
  } else if (ua.includes('Firefox')) {
    result.browser = 'Firefox';
  } else if (ua.includes('Safari')) {
    result.browser = 'Safari';
  } else if (ua.includes('Edge')) {
    result.browser = 'Edge';
  } else if (ua.includes('Opera')) {
    result.browser = 'Opera';
  }

  // 디바이스 감지
  if (ua.includes('Mobile')) {
    result.device = 'Mobile';
  } else if (ua.includes('Tablet') || ua.includes('iPad')) {
    result.device = 'Tablet';
  } else {
    result.device = 'Desktop';
  }

  return result;
};

// 사용자 활동 추적 로그 함수 (콘솔 + 데이터베이스)
const logUserActivity = async (req, action, details = {}, responseTimeMs = null, statusCode = null) => {
  // 사용자 정보를 여러 소스에서 가져오기
  const userInfo = req.user || {};
  const bodyInfo = req.body || {};
  
  // 우선순위: req.user > req.body > 기본값
  const userId = userInfo.empCd || userInfo.MEK_EMP_CD || bodyInfo.userId || bodyInfo.empCd || 'Anonymous';
  const userName = userInfo.empName || userInfo.MEK_EMP_NAME || bodyInfo.userName || bodyInfo.empName || 'Unknown';
  const tradeCode = userInfo.trCd || userInfo.MEK_TR_CD || bodyInfo.tradeCode || bodyInfo.trCd || bodyInfo.agencyCode || 'Unknown';
  const tradeName = userInfo.trName || userInfo.MEK_TR_NAME || bodyInfo.tradeName || bodyInfo.trName || bodyInfo.agencyName || 'Unknown';
  const accessType = userInfo.accessType || userInfo.MEK_ACCESS_TYPE || bodyInfo.accessType || 'Unknown';
  
  const clientIP = req.ip || req.connection.remoteAddress || req.headers['x-forwarded-for'] || 'Unknown';
  const userAgent = req.headers['user-agent'] || 'Unknown';
  
  // User-Agent 파싱
  const uaInfo = parseUserAgent(userAgent);
  
  const logData = {
    timestamp: new Date().toISOString(),
    clientIP: clientIP,
    userAgent: userAgent,
    method: req.method,
    url: req.originalUrl,
    userId: userId,
    userName: userName,
    tradeCode: tradeCode,
    tradeName: tradeName,
    accessType: accessType,
    action: action,
    details: details,
    responseTimeMs: responseTimeMs,
    statusCode: statusCode,
    platform: uaInfo.platform,
    browser: uaInfo.browser,
    device: uaInfo.device,
    os: uaInfo.os,
    isMobile: uaInfo.isMobile,
    isTablet: uaInfo.isTablet,
    isPc: uaInfo.isPc,
    programName: 'MSM_APP',
    sessionId: req.sessionID || req.headers['x-session-id'] || null
  };

  // 콘솔 로그 출력
  logWithTimestamp(`USER_ACTIVITY: ${JSON.stringify(logData, null, 2)}`);
  
  // 데이터베이스에 로그 저장 (비동기)
  try {
    const logId = await databaseLogger.logUserActivity(logData);
    if (logId) {
      logWithTimestamp(`Log saved to database with ID: ${logId}`);
    }
  } catch (error) {
    logWithTimestamp(`Failed to save log to database: ${error.message}`);
  }
};

// 토큰에서 사용자 정보 추출 함수
const extractUserFromToken = (req) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      // JWT 토큰 디코딩 (실제 구현에서는 jwt.verify 사용)
      // 여기서는 간단한 예시로 토큰을 파싱
      const decoded = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
      req.user = decoded;
    }
  } catch (error) {
    // 토큰 파싱 실패 시 무시
  }
};

// CORS 설정
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());

// 사용자 정보 추출 미들웨어
app.use((req, res, next) => {
  extractUserFromToken(req);
  next();
});

// 응답 시간 측정 및 로깅 미들웨어
app.use('/api/v1', (req, res, next) => {
  const startTime = Date.now();
  const userInfo = req.user || {};
  const bodyInfo = req.body || {};
  const clientIP = req.ip || req.connection.remoteAddress || req.headers['x-forwarded-for'] || 'Unknown';
  
  // 기본 요청 로그
  logWithTimestamp(`Request: ${req.method} ${req.url} from IP: ${clientIP}`);
  
  // 사용자 정보가 있는 경우 상세 로그
  const userId = userInfo.empCd || userInfo.MEK_EMP_CD || bodyInfo.userId || bodyInfo.empCd;
  const userName = userInfo.empName || userInfo.MEK_EMP_NAME || bodyInfo.userName || bodyInfo.empName;
  const tradeCode = userInfo.trCd || userInfo.MEK_TR_CD || bodyInfo.tradeCode || bodyInfo.trCd || bodyInfo.agencyCode;
  const tradeName = userInfo.trName || userInfo.MEK_TR_NAME || bodyInfo.tradeName || bodyInfo.trName || bodyInfo.agencyName;
  
  if (userId) {
    logWithTimestamp(`User: ${userId} (${userName || 'Unknown'}) from Trade: ${tradeCode || 'Unknown'} (${tradeName || 'Unknown'})`);
  }
  
  // 응답 완료 후 로깅
  res.on('finish', () => {
    const responseTime = Date.now() - startTime;
    const action = `${req.method}_${req.path.replace(/\//g, '_').replace(/^_/, '')}`;
    
    logUserActivity(req, action, {
      requestBody: req.body,
      queryParams: req.query,
      responseStatus: res.statusCode,
      responseTimeMs: responseTime
    }, responseTime, res.statusCode);
  });
  
  next();
});

// 데이터베이스 로거 초기화
const initializeDatabaseLogger = async () => {
  const dbConfig = {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT) : 1433,
    user: process.env.DB_USER || 'sa',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'msm_db'
  };
  
  await databaseLogger.initialize(dbConfig);
};

// 라우터 로드
logWithTimestamp('Loading routers...');
const authRouter = require('./routes/auth');
const noticesRouter = require('./routes/notices');
const hospitalsRouter = require('./routes/hospitals');
const proceduresRouter = require('./routes/procedures');
const stocksRouter = require('./routes/stocks');
const cellsRouter = require('./routes/cells');
const autoOrdersRouter = require('./routes/auto-orders');
const deliveryRouter = require('./routes/delivery');
const categoriesRouter = require('./routes/categories');
const stradesRouter = require('./routes/strades');
const agencyRouter = require('./routes/agencies');
const stockCloseRouter = require('./routes/stock-close');
const stockSurveyRouter = require('./routes/stock-survey');
const stockSurveyCycleRouter = require('./routes/stock-survey-cycle');
const hospitalDeliveryRouter = require('./hospital_delivery');
const userRouter = require('./routes/user');
const agencySalesRouter = require('./routes/agency-sales');
const hospitalDetailInfoRouter = require('./routes/hospital-detail-info');
const hospitalMasterRouter = require('./routes/hospital-master');

// 라우터 등록 (모두 /api/v1/ 하위로 통일)
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/notices', noticesRouter);
app.use('/api/v1/hospitals', hospitalsRouter);
app.use('/api/v1/procedures', proceduresRouter);
app.use('/api/v1/stocks', stocksRouter);
app.use('/api/v1/cells', cellsRouter);
app.use('/api/v1/auto-orders', autoOrdersRouter);
app.use('/api/v1/delivery', deliveryRouter);
app.use('/api/v1/categories', categoriesRouter);
app.use('/api/v1/strades', stradesRouter);
app.use('/api/v1/agencies', agencyRouter);
app.use('/api/v1/stock-close', stockCloseRouter);
app.use('/api/v1/stock-survey', stockSurveyRouter);
app.use('/api/v1/stock-survey-cycle', stockSurveyCycleRouter);
app.use('/api/v1', hospitalDeliveryRouter);
app.use('/api/v1/user', userRouter);
app.use('/api/v1/agency-sales', agencySalesRouter);
app.use('/api/v1/hospital-detail-info', hospitalDetailInfoRouter);
app.use('/api/v1/hospital-master', hospitalMasterRouter);

// 로그 통계 API 엔드포인트 추가
app.get('/api/v1/logs/stats', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 30;
    const stats = await databaseLogger.getActivityStats(days);
    res.json({ status: 'success', data: stats });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// 사용자별 활동 요약 API
app.get('/api/v1/logs/user-summary', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const summary = await databaseLogger.getUserActivitySummary(limit);
    res.json({ status: 'success', data: summary });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// 거래처별 활동 요약 API
app.get('/api/v1/logs/trade-summary', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const summary = await databaseLogger.getTradeActivitySummary(limit);
    res.json({ status: 'success', data: summary });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// 플랫폼별 통계 API
app.get('/api/v1/logs/platform-summary', async (req, res) => {
  try {
    const summary = await databaseLogger.getPlatformActivitySummary();
    res.json({ status: 'success', data: summary });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// 브라우저별 통계 API
app.get('/api/v1/logs/browser-summary', async (req, res) => {
  try {
    const summary = await databaseLogger.getBrowserActivitySummary();
    res.json({ status: 'success', data: summary });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// 디바이스별 통계 API
app.get('/api/v1/logs/device-summary', async (req, res) => {
  try {
    const summary = await databaseLogger.getDeviceActivitySummary();
    res.json({ status: 'success', data: summary });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// 404 핸들러
app.use((req, res, next) => {
  logUserActivity(req, 'PAGE_NOT_FOUND', { requestedUrl: req.url }, null, 404);
  logWithTimestamp(`404 Not Found: ${req.method} ${req.url}`);
  res.status(404).json({ status: 'error', message: 'Not Found' });
});

// Flutter Web 빌드 결과물 경로 (/msm으로 서비스)
const flutterWebPath = path.join(__dirname, '../build/web');
app.use('/msm', express.static(flutterWebPath));
app.get('/msm/*', (req, res) => {
  logUserActivity(req, 'WEB_APP_ACCESS', { page: req.path });
  res.sendFile(path.join(flutterWebPath, 'index.html'));
});

// 서버 시작
const startServer = async () => {
  try {
    // 데이터베이스 로거 초기화
    await initializeDatabaseLogger();
    
    app.listen(port, () => {
      logWithTimestamp(`Server running on port ${port}`);
      logWithTimestamp('User activity tracking enabled');
      logWithTimestamp('Database logging enabled');
    });
  } catch (error) {
    logWithTimestamp(`Failed to start server: ${error.message}`);
    process.exit(1);
  }
};

// 프로세스 종료 시 정리
process.on('SIGINT', async () => {
  logWithTimestamp('Shutting down server...');
  await databaseLogger.close();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logWithTimestamp('Shutting down server...');
  await databaseLogger.close();
  process.exit(0);
});

startServer(); 