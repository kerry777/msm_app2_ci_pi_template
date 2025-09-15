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