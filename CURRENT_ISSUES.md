# MSM Flutter App - 현재 문제점 및 해결 필요 사항

## 📋 프로젝트 개요
- **프로젝트**: MSM (Medical Sales Management) Flutter 웹 애플리케이션
- **주요 기능**: Excel 견적서 편집기, MEK 템플릿 시스템
- **개발 환경**: Flutter Web + Node.js 백엔드 (PM2)
- **현재 상태**: 로그인 완료, Excel 뷰어 구현됨

## 🚨 현재 발생 중인 문제들

### 1. Flutter 렌더링 오류
**문제**: RenderFlex unbounded width constraints 오류
```
RenderFlex children have non-zero flex but incoming width constraints are unbounded.
The relevant error-causing widget was:
Row Row:file:///C:/projects/msm_app/msm_app1/client/lib/screens/excel_quotation_screen.dart:505:20
```

**위치**: `lib/screens/excel_quotation_screen.dart:505:20`
**원인**: DataTable 헤더의 Row 위젯에서 Expanded 사용 시 무한대 너비 제약 조건
**영향**: UI 렌더링 실패, 사용자 경험 저하

### 2. Excel 파일 다운로드 의도치 않은 동작
**문제**: 원본 템플릿 뷰어에서 다운로드 버튼 클릭 시 자동으로 Excel 파일 다운로드됨
**위치**: `_OriginalTemplateViewer` 클래스의 다운로드 기능
**사용자 기대사항**: Excel 파일을 브라우저에서 직접 보기/편집 (다운로드 없이)

### 3. CORS 문제 (해결됨, 하지만 임시 방편)
**현재 해결책**: Chrome CORS 비활성화 플래그 사용
```bash
flutter run -d chrome --web-browser-flag="--disable-web-security"
```
**문제점**: 프로덕션 환경에서 사용 불가능한 해결책
**필요한 해결책**: 백엔드 CORS 설정 또는 프록시 구성

## 🔧 현재 구현된 기능들

### ✅ 작동하는 기능
1. **로그인 시스템**: API 연동 완료 (msmtest/0001)
2. **기본 Excel 편집기**: 스프레드시트 편집 및 자동 계산
3. **MEK 템플릿 시스템**: 6개 템플릿 지원 (한/영/아랍어)
4. **실제 Excel 파일 로드**: Syncfusion xlsio 사용하여 asset에서 로드
5. **파일 내보내기**: Excel, CSV, PDF 지원

### ⚠️ 부분적으로 작동하는 기능
1. **원본 템플릿 뷰어**: 데이터는 로드되지만 UI 렌더링 오류
2. **외부 웹 편집기**: 팝업은 뜨지만 추가 검증 필요

## 📁 주요 파일 구조
```
C:\projects\msm_app\msm_app1\client\
├── lib\screens\excel_quotation_screen.dart (메인 Excel 편집기)
├── assets\ (Excel 템플릿 파일들 - 6개)
├── lib\providers\auth_provider.dart (인증 관리)
├── lib\services\api_service.dart (API 통신)
└── lib\config\app_config.dart (서버 설정)
```

## 🔍 기술적 세부사항

### 사용 중인 주요 패키지
- `syncfusion_flutter_xlsio`: Excel 파일 처리
- `provider`: 상태 관리
- `http`: API 통신
- `shared_preferences`: 로컬 저장소

### 백엔드 정보
- **서버**: Node.js Express (PM2로 관리)
- **포트**: 80 (nginx), 4100 (API)
- **API 엔드포인트**: `http://localhost/msm/api/v1/`
- **상태**: 정상 작동 중

### 개발 서버 실행 명령
```bash
# 백엔드 서버 시작
cd F:\projects\msm\server
pm2 start ecosystem.config.js

# Flutter 앱 실행 (CORS 비활성화)
cd C:\projects\msm_app\msm_app1\client
flutter run -d chrome --web-browser-flag="--disable-web-security"
```

## 🎯 해결이 필요한 우선순위

### 높음 (High Priority)
1. **Flutter UI 렌더링 오류 수정**
   - DataTable Row 위젯의 Expanded → Flexible 변경
   - mainAxisSize: MainAxisSize.min 적용

2. **Excel 파일 뷰어 개선**
   - 다운로드 대신 브라우저 내 뷰어 구현
   - iframe 또는 Syncfusion 웹 컴포넌트 사용 고려

### 중간 (Medium Priority)
1. **CORS 프로덕션 해결책**
   - Express.js CORS 미들웨어 설정
   - 또는 Flutter 웹 프록시 구성

2. **UI/UX 개선**
   - 반응형 레이아웃 최적화
   - 모바일 지원 강화

### 낮음 (Low Priority)
1. **성능 최적화**
2. **추가 기능 구현**

## 💻 개발 환경 정보
- **운영체제**: Windows 10/11
- **Flutter**: 3.35.1
- **Chrome**: CORS 비활성화 모드로 실행
- **IDE**: 현재 사용 중인 개발 환경

## 🤝 추가 지원 요청사항
1. Flutter DataTable 렌더링 오류 해결 방법
2. Excel 파일을 브라우저에서 직접 편집할 수 있는 방법
3. CORS 없이 Flutter 웹에서 API 호출하는 방법
4. Syncfusion Excel 뷰어의 대안 솔루션

## 📞 참고 정보
- **프로젝트 경로**: `C:\projects\msm_app\msm_app1\client\`
- **로그인 정보**: msmtest / 0001
- **개발 서버**: http://localhost (Flutter 앱은 동적 포트)
- **API 서버**: http://localhost/msm

---
**작성일**: 2025-01-16
**작성자**: 개발팀
**상태**: 해결 필요