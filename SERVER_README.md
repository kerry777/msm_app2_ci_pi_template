# MDM 서버 - 사용자 활동 로깅 시스템

## 개요

이 서버는 MDM 애플리케이션의 사용자 활동을 추적하고 데이터베이스에 정형화된 로그를 저장하는 기능을 제공합니다.

## 주요 기능

### 1. 사용자 활동 추적
- IP 주소, 사용자 ID, 거래처 코드, 거래처명 추적
- 사용자가 실행한 작업 기록
- 응답 시간 측정
- 요청/응답 상세 정보 저장

### 2. 데이터베이스 로깅
- MySQL 데이터베이스에 정형화된 로그 저장
- 자동 테이블 생성 및 인덱스 설정
- 로그 통계 및 요약 조회 API 제공

### 3. 로그 분석
- 일별/월별 활동 통계
- 사용자별 활동 요약
- 거래처별 활동 요약
- 오래된 로그 자동 정리

## 설치 및 설정

### 1. 의존성 설치
```bash
npm install
```

### 2. 환경 변수 설정
`env.example` 파일을 `.env`로 복사하고 설정을 수정하세요:

```bash
cp env.example .env
```

### 3. 데이터베이스 설정
MySQL 데이터베이스에 로그 테이블을 생성하세요:

```sql
-- user_activity_logs.sql 파일 실행
mysql -u root -p mdm_db < user_activity_logs.sql
```

### 4. 서버 실행
```bash
# 개발 모드
npm run dev

# 프로덕션 모드
npm start
```

## 로그 데이터 구조

### user_activity_logs 테이블
| 필드 | 타입 | 설명 |
|------|------|------|
| id | BIGINT | 자동 증가 ID |
| timestamp | DATETIME | 요청 시간 |
| client_ip | VARCHAR(45) | 클라이언트 IP |
| user_agent | TEXT | 브라우저 정보 |
| method | VARCHAR(10) | HTTP 메서드 |
| url | VARCHAR(500) | 요청 URL |
| user_id | VARCHAR(50) | 사용자 ID |
| user_name | VARCHAR(100) | 사용자명 |
| trade_code | VARCHAR(50) | 거래처 코드 |
| trade_name | VARCHAR(100) | 거래처명 |
| access_type | VARCHAR(50) | 접근 타입 |
| action | VARCHAR(100) | 실행된 작업 |
| details | JSON | 상세 정보 |
| status_code | INT | HTTP 상태 코드 |
| response_time_ms | INT | 응답 시간 (ms) |

## API 엔드포인트

### 로그 통계 조회
```http
GET /api/v1/logs/stats?days=30
```

### 사용자별 활동 요약
```http
GET /api/v1/logs/user-summary?limit=50
```

### 거래처별 활동 요약
```http
GET /api/v1/logs/trade-summary?limit=50
```

## 라우터별 상세 로깅

각 라우터에서 상세한 로깅을 추가하려면 다음과 같이 구현하세요:

```javascript
// 라우터에서 상세 로깅 예시
router.post('/your-endpoint', async (req, res) => {
  const startTime = Date.now();
  const userInfo = req.user || {};
  
  try {
    // 비즈니스 로직 실행
    
    const responseTime = Date.now() - startTime;
    
    // 성공 로그
    logWithTimestamp(`OPERATION_SUCCESS: User ${userInfo.empCd} completed operation (${responseTime}ms)`);
    
    // 상세 로그 데이터
    const logDetails = {
      operation: 'your_operation',
      targetId: 'target_value',
      requestSource: 'your_route',
      success: true,
      responseTimeMs: responseTime
    };
    
    // req 객체에 로그 데이터 추가
    req.logDetails = logDetails;
    
    res.json({ status: 'success', data: result });
    
  } catch (error) {
    const responseTime = Date.now() - startTime;
    
    // 에러 로그
    logWithTimestamp(`OPERATION_ERROR: ${error.message} (${responseTime}ms)`);
    
    const logDetails = {
      operation: 'your_operation',
      error: error.message,
      success: false,
      responseTimeMs: responseTime
    };
    
    req.logDetails = logDetails;
    
    res.status(500).json({ status: 'error', message: error.message });
  }
});
```

## 로그 보관 정책

- 기본적으로 90일간 로그 보관
- `database_logger.js`의 `cleanupOldLogs()` 함수로 오래된 로그 정리
- 필요시 파티션 테이블 사용으로 성능 최적화 가능

## 모니터링 및 알림

로그 데이터를 기반으로 다음과 같은 모니터링이 가능합니다:

1. **사용자 활동 패턴 분석**
2. **시스템 성능 모니터링** (응답 시간)
3. **보안 이벤트 감지** (비정상 접근)
4. **비즈니스 인사이트 도출** (사용자 행동 분석)

## 문제 해결

### 데이터베이스 연결 실패
- 환경 변수 설정 확인
- MySQL 서버 실행 상태 확인
- 데이터베이스 사용자 권한 확인

### 로그 저장 실패
- 데이터베이스 연결 상태 확인
- 테이블 존재 여부 확인
- 디스크 공간 확인

### 성능 이슈
- 로그 인덱스 확인
- 오래된 로그 정리
- 파티션 테이블 사용 고려 