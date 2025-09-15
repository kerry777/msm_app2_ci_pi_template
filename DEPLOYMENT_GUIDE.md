# MSM Flutter 애플리케이션 배포 가이드

## 프로젝트 구조 및 용도

### 개발 환경
```
C:\projects\msm_app\msm_app1\client\
├── lib\
│   ├── screens\               # Flutter 화면들
│   │   ├── main_screen.dart   # 메인 메뉴 화면
│   │   ├── product_order_screen.dart     # 주문 등록 (기존)
│   │   ├── order_management_screen.dart  # 주문 관리 대시보드 (신규)
│   │   ├── order_list_screen.dart        # 주문 목록 관리 (신규)
│   │   ├── order_analytics_screen.dart   # 주문 분석 (신규)
│   │   └── quote_management_screen.dart  # 견적 관리 (신규)
│   ├── utils\
│   │   └── order_report_generator.dart   # PDF/Excel 생성 (견적 기능 추가)
│   ├── l10n\                 # 다국어 지원
│   ├── config\
│   │   └── app_config.dart   # 서버 URL 설정
│   └── main.dart             # 앱 진입점
├── build\web\                # Flutter 빌드 결과물
└── pubspec.yaml              # 패키지 의존성
```

### 배포 환경 (운영)
```
F:\projects\msm\web\          # Nginx가 서빙하는 웹 파일들
├── index.html                # Flutter 웹 앱 진입점
├── main.dart.js              # Flutter 컴파일된 JS
├── assets\                   # 앱 리소스들
├── icons\                    # 앱 아이콘들
└── flutter_service_worker.js # PWA 서비스 워커
```

### Nginx 설정
```
F:\projects\mdm\nginx\
├── nginx.exe                 # Nginx 실행 파일
├── conf\
│   └── nginx.conf           # 설정 파일 (중요!)
└── logs\                    # 로그 파일들
```

### 백엔드 서버
- **포트**: 4100 (Node.js 서버)
- **프로세스 관리**: PM2
- **데이터베이스**: MSSQL/MySQL

## 오늘 발생한 주요 문제와 해결책

### 1. 주요 문제: API 라우팅 실패 (405 Method Not Allowed)

#### 문제 상황
- 클라이언트: `/msm/api/v1/auth/login`으로 POST 요청
- Nginx 설정: `/api/` 경로만 프록시 설정됨
- 결과: 405 Method Not Allowed 에러 발생

#### 근본 원인
```nginx
# 기존 설정 (문제)
location /api/ {
    proxy_pass http://localhost:4100/api/;
}
```
- `/msm/api/` 경로는 프록시되지 않음
- 정적 파일로 처리되어 POST 메소드 거부

#### 해결책
```nginx
# 추가된 설정 (해결)
location /msm/api/ {
    proxy_pass http://localhost:4100/api/;
    # CORS 헤더 설정
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    # ... 기타 CORS 설정
}
```

### 2. 브라우저 캐싱 문제

#### 문제 상황
- 새로 빌드된 Flutter 앱이 브라우저에 반영되지 않음
- 기존 캐시된 파일들이 계속 사용됨

#### 해결책
```html
<!-- F:\projects\msm\web\index.html에 추가 -->
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
```

### 3. 배포 프로세스 혼란

#### 문제 상황
- 개발 환경과 배포 환경 경로 혼동
- 수동 파일 복사 과정에서 실수 발생

#### 표준 배포 프로세스 확립
```bash
# 1. Flutter 앱 빌드
cd C:\projects\msm_app\msm_app1\client
flutter build web

# 2. 빌드 결과물 배포 위치로 복사
cp -r build/web/* /f/projects/msm/web/

# 3. PM2 서비스 재시작
pm2 restart all

# 4. Nginx 설정 변경 시 리로드
cd /f/projects/mdm/nginx
./nginx.exe -s reload
```

## Nginx 설정 주요사항

### 중요 설정 포인트

1. **API 프록시 설정**
```nginx
# MSM 앱 전용 API 프록시
location /msm/api/ {
    proxy_pass         http://localhost:4100/api/;
    proxy_http_version 1.1;
    proxy_set_header   Host $host;
    proxy_set_header   X-Real-IP $remote_addr;
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}

# 일반 API 프록시 (호환성 유지)
location /api/ {
    proxy_pass         http://localhost:4100/api/;
}
```

2. **정적 파일 서빙**
```nginx
location /msm/ {
    alias F:/projects/msm/web/;
    index index.html;
    try_files $uri $uri/ @msm_fallback;
}

location @msm_fallback {
    rewrite ^.*$ /msm/index.html last;
}
```

3. **CORS 설정 (필수)**
```nginx
add_header 'Access-Control-Allow-Origin' '*' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
```

### Nginx 관리 명령어

```bash
# 설정 테스트
cd /f/projects/mdm/nginx
./nginx.exe -t

# 설정 리로드 (무중단)
./nginx.exe -s reload

# 완전 재시작
./nginx.exe -s stop
./nginx.exe

# 로그 확인
tail -f logs/access.log
tail -f logs/error.log
```

## 시행착오 분석

### 주요 실수들

1. **경로 혼동**
   - 개발: `C:\projects\msm_app\msm_app1\client`
   - 배포: `F:\projects\msm\web`
   - Nginx: `F:\projects\mdm\nginx`

2. **API 경로 불일치**
   - 클라이언트 요청: `/msm/api/v1/auth/login`
   - Nginx 프록시: `/api/` 만 설정
   - **해결**: `/msm/api/` 프록시 추가

3. **캐싱 문제 무시**
   - 브라우저 캐시로 인한 업데이트 미반영
   - **해결**: 캐시 무효화 메타태그 추가

4. **설정 변경 후 리로드 누락**
   - Nginx 설정 변경 후 리로드 안함
   - **해결**: `nginx -s reload` 필수

## 예방 조치

### 1. 배포 자동화 스크립트 작성
```bash
#!/bin/bash
# deploy.sh
echo "=== MSM Flutter 앱 배포 시작 ==="

# 1. 빌드
cd C:\projects\msm_app\msm_app1\client
flutter build web

# 2. 배포
cp -r build/web/* /f/projects/msm/web/

# 3. 서비스 재시작
pm2 restart all

# 4. Nginx 리로드 (설정 변경시에만)
# cd /f/projects/mdm/nginx && ./nginx.exe -s reload

echo "=== 배포 완료 ==="
```

### 2. 환경별 설정 분리
- 개발: `http://localhost:59333`
- 운영: `http://localhost/msm`
- 서버 URL을 환경변수로 관리

### 3. 로그 모니터링
- Nginx 액세스 로그 확인
- PM2 애플리케이션 로그 확인
- 브라우저 개발자 도구 네트워크 탭 활용

## 주요 URL 및 포트

| 서비스 | URL | 포트 | 용도 |
|--------|-----|------|------|
| Nginx | http://localhost/msm | 80 | 운영 환경 |
| Flutter Dev | http://localhost:59333 | 59333 | 개발 서버 |
| Backend API | http://localhost:4100 | 4100 | Node.js 서버 |
| MDM | http://localhost/mdm | 4003 | MDM 시스템 |

## 문제 발생시 점검 사항

1. **로그인 실패**
   - Nginx 설정에서 `/msm/api/` 프록시 확인
   - PM2 프로세스 상태 확인: `pm2 status`
   - Backend 서버 로그 확인

2. **새 기능이 보이지 않을 때**
   - Flutter 빌드 후 배포 여부 확인
   - 브라우저 캐시 클리어 (Ctrl+F5)
   - `index.html` 캐시 무효화 메타태그 확인

3. **API 요청 실패**
   - Nginx 로그 확인: `logs/error.log`
   - CORS 헤더 설정 확인
   - 프록시 경로 매칭 확인

## 오늘 추가된 기능

### 새로운 화면들
1. **주문 관리** (`order_management_screen.dart`)
   - 대시보드, 통계, 차트 포함

2. **주문 목록** (`order_list_screen.dart`)
   - 주문 조회, 수정, 삭제, 상태 관리

3. **주문 분석** (`order_analytics_screen.dart`)
   - 다양한 차트와 분석 데이터

4. **견적 관리** (`quote_management_screen.dart`)
   - 견적서 발행, 승인, 주문 전환

### 기존 화면 개선
- **주문 등록** (`product_order_screen.dart`)
  - 견적서 생성 기능 추가 (PDF/Excel)

**이 문서는 향후 배포 시 필수 참고 자료로 활용하여 동일한 시행착오를 방지하시기 바랍니다.**