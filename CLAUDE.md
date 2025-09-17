# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Flutter Commands
```bash
# Run the app
flutter run

# Build for web
flutter build web

# Build for Android
flutter build apk

# Analyze code
flutter analyze

# Run tests
flutter test

# Clean and get dependencies
flutter clean && flutter pub get
```

### Node.js Server Commands
```bash
# Server location: F:\projects\msm\server\

# Start the server using PM2 (recommended)
cd F:\projects\msm\server
pm2 start ecosystem.config.js

# Check PM2 status
pm2 list

# Restart services
pm2 restart msm-app
pm2 restart msm-web

# Alternative: npm commands (if needed)
npm start
npm run dev
npm install
```

## Architecture Overview

This is a Flutter-based MSM (Medical Sales Management) application with a Node.js backend server. The system manages hospital and agency inventory operations.

### Flutter App Architecture

**State Management**: Uses Provider pattern with multiple specialized providers:
- `AuthProvider`: JWT token-based authentication with SharedPreferences persistence
- `LanguageProvider`: Korean/English internationalization support
- Domain-specific providers for different functional areas (sales, stock, etc.)

**Navigation**: Complex menu-driven system with two-level hierarchical navigation:
- Main screen (`main_screen.dart`) contains extensive menu structure
- Dynamic screen routing based on menu selections
- Menu completion tracking with visual indicators

**Service Layer**: 
- `ApiService`: Singleton HTTP client with automatic token injection and retry logic
- Platform-specific services with web/mobile implementations (especially Excel export)
- Environment-based configuration for development/production

**Screen Organization**:
- Hospital management: Stock surveys, delivery, cycle settings
- Agency operations: Stock status, analytics, sales reporting  
- Stock management: Registration, history, analytics
- Administrative functions: Item export/return, help system

### Key Files and Patterns

**Main Entry**: `lib/main.dart` sets up MultiProvider with core dependencies and routing
**Routing**: `lib/routes.dart` contains static named routes by functional area
**Large Screens**: `lib/screens/main_screen.dart` (1000+ lines) - consider breaking down for maintenance
**API**: `lib/services/api_service.dart` handles all HTTP communication with centralized error handling
**Models**: Simple JSON serializable classes in `lib/models/`

### Development Guidelines

**Code Analysis**: Always run `flutter analyze` before committing - uses `package:flutter_lints/flutter.yaml`
**Internationalization**: Support Korean (ko) and English (en) - check `lib/l10n/` and `lib/translations.dart`
**Platform Support**: Multi-platform app with platform-specific implementations in `lib/utils/`
**Authentication**: JWT tokens stored in SharedPreferences - check auth state in providers before API calls

### Dependencies Note

**Critical Dependencies**:
- `provider: ^6.1.5` for state management
- `syncfusion_flutter_*` for charts and data grids
- `dio: ^5.4.3+1` and `http: ^1.4.0` for API communication
- `excel: ^4.0.2` for file export functionality

**Web Configuration**: Uses HTML renderer (`flutter_web.renderer: html`) for better compatibility

### Cursor Rules Integration

This project has specific Cursor rules that emphasize:
- Always analyze actual code before providing solutions
- Focus on current implementation rather than theoretical possibilities
- Provide concrete fixes based on code review, not general suggestions

### Backend Server

**Node.js Server**: Express-based server with MSSQL/MySQL database connectivity
**Server Location**: `F:\projects\msm\server\` (PM2 managed services)
**Key Files**: `server.js`, database logging in `database_logger.js`, user activity tracking
**FTP Integration**: Automated file upload scripts for deployment

### Complete System Startup Process

**Step 1: Start Backend Server**
```bash
cd F:\projects\msm\server
pm2 start ecosystem.config.js
pm2 list  # Verify msm-app and msm-web are online
```

**Step 2: Start Flutter Development Server**
```bash
cd C:\projects\msm_app\msm_app1\client
flutter run -d chrome
```

**Step 3: Verify Services**
```bash
# Check ports
powershell "netstat -ano | Select-String ':4100'"  # Backend API
powershell "netstat -ano | Select-String ':4103'"  # Web service
pm2 logs msm-app --lines 10  # Check logs if needed
```

**Step 4: Test Login**
- Open Chrome browser to Flutter app
- Verify empty ID/Password fields (auto-login disabled)
- Test manual login with credentials

## Univer Excel Viewer Integration (최종 해결됨)

### 문제 해결 완료 (2025-09-17)

**이전 문제점들:**
1. CDN 번들 혼용/구버전 사용 (univer.full.umd.js → Preset Mode UMD)
2. 전역 네임스페이스 접근 실수 (window 루트 → 패키지별 네임스페이스)
3. XLSX 파일을 createWorkbook()로 직접 로딩 시도 (서버 처리 구조임)
4. 초기화 세팅 미흡 (컨테이너/로케일 병합)

**해결 방법:**
- **index.fixed.html**: 최신 Preset UMD + 값-only 임포트/익스포트 기능 완성
- **univer_test.fixed.html**: 공식 예제 기반 미니멀 테스트 버전
- **문제_원인_해결_가이드.md**: 상세한 문제 분석 및 해결 과정 문서화

### 로컬 테스트 방법
```bash
# 간단 HTTP 서버로 테스트
python -m http.server 50577
# 브라우저에서 http://localhost:50577/index.fixed.html 접속
```

### 기능 제한사항
- **현재 버전**: 값-only 임포트/익스포트 (셀 값만 보존)
- **스타일/수식/차트 보존**: 서버 구성 필요 (Univer Import/Export API)

### 향후 확장 방안
1. **서버 기반 완전 임포트/익스포트**: Univer 공식 Import/Export API 사용
2. **오픈소스 변환기**: Luckyexcel 또는 univer-import-export 패키지 활용
3. **Flutter 앱 통합**: WebView로 Univer 뷰어 임베드 또는 별도 웹 서비스