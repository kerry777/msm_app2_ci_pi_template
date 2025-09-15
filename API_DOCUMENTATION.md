# MSM Flutter App API Documentation

## 🔗 API 구성 및 엔드포인트

### 📡 기본 설정
- **Base URL**: `http://localhost/msm` (AppConfig에서 관리)
- **API Version**: v1
- **Authentication**: JWT Token 기반

### 🏥 MSM 데이터 API

#### 1. 매출 요약 데이터
```dart
// 엔드포인트: /api/v1/sales/summary
// 메서드: GET
// 파라미터: startDate, endDate, groupBy

Future<List<Map<String, dynamic>>> getSalesSummary({
  String? startDate,
  String? endDate,
  String? groupBy,
}) async {
  final queryParams = <String, String>{};
  if (startDate != null) queryParams['startDate'] = startDate;
  if (endDate != null) queryParams['endDate'] = endDate;
  if (groupBy != null) queryParams['groupBy'] = groupBy;

  final response = await _dio.get(
    '/api/v1/sales/summary',
    queryParameters: queryParams,
  );
  return List<Map<String, dynamic>>.from(response.data);
}
```

**응답 형식**:
```json
[
  {
    "CUSTOM_NAME": "삼성서울병원",
    "CONTINENT": "아시아",
    "NATION_NAME": "한국",
    "거래처분류": "종합병원",
    "SUM_SALE_AMT_WON": 45000000,
    "SALE_Q": 150,
    "SALE_P": 300000
  }
]
```

#### 2. 지역별 매출 데이터
```dart
// 엔드포인트: /api/v1/sales/by-region
// 메서드: GET

Future<List<Map<String, dynamic>>> getSalesByRegion() async {
  final response = await _dio.get('/api/v1/sales/by-region');
  return List<Map<String, dynamic>>.from(response.data);
}
```

#### 3. 제품별 매출 데이터
```dart
// 엔드포인트: /api/v1/sales/by-product
// 메서드: GET

Future<List<Map<String, dynamic>>> getSalesByProduct() async {
  final response = await _dio.get('/api/v1/sales/by-product');
  return List<Map<String, dynamic>>.from(response.data);
}
```

#### 4. 병원별 매출 데이터
```dart
// 엔드포인트: /api/v1/sales/by-hospital
// 메서드: GET

Future<List<Map<String, dynamic>>> getSalesByHospital() async {
  final response = await _dio.get('/api/v1/sales/by-hospital');
  return List<Map<String, dynamic>>.from(response.data);
}
```

### 🛒 주문 관리 API

#### 1. 주문 목록 조회
```dart
// 엔드포인트: /api/v1/orders
// 메서드: GET

GET ${AppConfig.apiBaseUrl}/api/v1/orders
```

#### 2. 주문 등록
```dart
// 엔드포인트: /api/v1/orders
// 메서드: POST

POST ${AppConfig.apiBaseUrl}/api/v1/orders
Content-Type: application/json

{
  "customerId": "string",
  "items": [
    {
      "productId": "string",
      "quantity": number,
      "price": number
    }
  ],
  "deliveryDate": "yyyy-mm-dd"
}
```

#### 3. 견적서 관리
```dart
// 엔드포인트: /api/v1/quotes
// 메서드: GET, POST, PUT, DELETE

GET ${AppConfig.apiBaseUrl}/api/v1/quotes
POST ${AppConfig.apiBaseUrl}/api/v1/quotes
PUT ${AppConfig.apiBaseUrl}/api/v1/quotes/{id}
DELETE ${AppConfig.apiBaseUrl}/api/v1/quotes/{id}
```

### 📊 분석 API

#### 1. 피벗 테이블 데이터
```dart
// Enhanced API Service에서 구현
// 다양한 그룹핑 옵션 지원

Future<List<Map<String, dynamic>>> getPivotData({
  List<String> rowFields = const [],
  List<String> valueFields = const [],
  String aggregationType = 'sum',
}) async {
  // 동적 쿼리 생성 및 데이터 반환
}
```

#### 2. 드릴다운 분석 데이터
```dart
// 계층적 데이터 구조 지원
Map<String, Map<String, Map<String, double>>> hierarchicalData = {
  '서울': {
    '삼성서울병원': {'의료기기A': 45000000, '진단장비B': 38000000},
    '서울대병원': {'의료기기A': 42000000, '진단장비B': 35000000},
  },
  '경기': {
    '분당서울대': {'의료기기A': 35000000, '진단장비B': 28000000},
  }
};
```

### 🔐 인증 API

#### 1. 로그인
```dart
// 엔드포인트: /api/v1/auth/login
// 메서드: POST

POST ${AppConfig.apiBaseUrl}/api/v1/auth/login
Content-Type: application/json

{
  "username": "msmtest",
  "password": "0001",
  "country": "KR"  // 국가 코드
}
```

**응답**:
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "username": "msmtest",
    "role": "admin",
    "country": "KR"
  }
}
```

#### 2. 토큰 갱신
```dart
// 엔드포인트: /api/v1/auth/refresh
// 메서드: POST
// Headers: Authorization: Bearer {token}

POST ${AppConfig.apiBaseUrl}/api/v1/auth/refresh
Authorization: Bearer {current_token}
```

### 🛠️ Enhanced API Service 구조

#### 기본 구성
```dart
class EnhancedApiService {
  static final EnhancedApiService _instance = EnhancedApiService._internal();
  factory EnhancedApiService() => _instance;
  EnhancedApiService._internal();

  late Dio _dio;

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      timeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 토큰 인터셉터 추가
    _dio.interceptors.add(TokenInterceptor());

    // 로깅 인터셉터 추가
    _dio.interceptors.add(LogInterceptor(
      request: true,
      response: true,
      error: true,
    ));
  }
}
```

#### 에러 처리
```dart
try {
  final response = await _dio.get(endpoint);
  return response.data;
} on DioException catch (e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      throw ApiException('연결 시간 초과');
    case DioExceptionType.receiveTimeout:
      throw ApiException('응답 시간 초과');
    case DioExceptionType.badResponse:
      throw ApiException('서버 오류: ${e.response?.statusCode}');
    default:
      throw ApiException('네트워크 오류: ${e.message}');
  }
}
```

### 📈 피벗 테이블 API 상세

#### 필드 구성 옵션
```dart
class PivotConfiguration {
  final List<String> rowFields;      // 행 필드
  final List<String> columnFields;   // 열 필드
  final List<String> valueFields;    // 값 필드
  final String aggregationType;      // 집계 방식 (sum, avg, count)

  // 사용 가능한 필드들
  static const List<String> availableFields = [
    'CONTINENT',        // 대륙
    'NATION_NAME',      // 국가
    'CUSTOM_NAME',      // 거래처명
    '거래처분류',         // 거래처분류
    'SUM_SALE_AMT_WON', // 매출액
    'SALE_Q',           // 수량
    'SALE_P',           // 단가
  ];
}
```

#### 동적 쿼리 생성
```dart
String _buildGroupByClause(List<String> fields) {
  if (fields.isEmpty) return '';
  return 'GROUP BY ${fields.join(', ')}';
}

String _buildSelectClause(List<String> rowFields, List<String> valueFields, String aggregationType) {
  final selectParts = <String>[];

  // 행 필드 추가
  selectParts.addAll(rowFields);

  // 값 필드에 집계 함수 적용
  for (final field in valueFields) {
    selectParts.add('${aggregationType.toUpperCase()}($field) as $field');
  }

  return 'SELECT ${selectParts.join(', ')}';
}
```

### 🌐 국제화 지원

#### 지원 언어
- **한국어 (ko)**: 기본 언어
- **영어 (en)**: 글로벌 지원

#### API 헤더
```dart
headers: {
  'Accept-Language': currentLocale, // 'ko' 또는 'en'
  'Content-Type': 'application/json',
}
```

### 🔧 개발 환경 구성

#### 로컬 개발
```yaml
development:
  api_base_url: "http://localhost/msm"
  debug_mode: true
  log_level: "debug"
```

#### 프로덕션
```yaml
production:
  api_base_url: "https://api.msm.com"
  debug_mode: false
  log_level: "error"
```

### 📋 API 테스트

#### Postman 컬렉션
```json
{
  "info": {
    "name": "MSM Flutter App API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Auth",
      "item": [
        {
          "name": "Login",
          "request": {
            "method": "POST",
            "url": "{{baseUrl}}/api/v1/auth/login",
            "body": {
              "raw": "{\n  \"username\": \"msmtest\",\n  \"password\": \"0001\"\n}"
            }
          }
        }
      ]
    }
  ]
}
```

### 🚨 에러 코드

| 코드 | 설명 | 해결 방안 |
|------|------|-----------|
| 401 | 인증 실패 | 토큰 갱신 또는 재로그인 |
| 403 | 권한 없음 | 관리자 문의 |
| 404 | 리소스 없음 | URL 확인 |
| 500 | 서버 오류 | 서버 관리자 문의 |
| 503 | 서비스 불가 | 잠시 후 재시도 |

### 📊 성능 지표

- **평균 응답 시간**: < 500ms
- **타임아웃**: 30초
- **재시도 횟수**: 3회
- **캐시 유지 시간**: 5분