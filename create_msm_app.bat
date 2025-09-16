@echo off
echo Creating MPM App...

REM 현재 디렉토리에서 상위로 이동
cd ..

REM MPM 앱 디렉토리 생성
if not exist "mpm_app" mkdir mpm_app
cd mpm_app

REM Flutter 프로젝트 생성
flutter create mpm_app

REM MPM 앱 디렉토리로 이동
cd mpm_app

REM pubspec.yaml 수정
echo name: mpm_app > pubspec.yaml
echo description: "MEKICS Production Management project." >> pubspec.yaml
echo publish_to: 'none' >> pubspec.yaml
echo. >> pubspec.yaml
echo version: 1.0.0+20250101001 >> pubspec.yaml
echo. >> pubspec.yaml
echo environment: >> pubspec.yaml
echo   sdk: '>=3.2.3 ^<4.0.0' >> pubspec.yaml
echo. >> pubspec.yaml
echo dependencies: >> pubspec.yaml
echo   flutter: >> pubspec.yaml
echo     sdk: flutter >> pubspec.yaml
echo   flutter_localizations: >> pubspec.yaml
echo     sdk: flutter >> pubspec.yaml
echo   cupertino_icons: ^1.0.8 >> pubspec.yaml
echo   provider: ^6.1.5 >> pubspec.yaml
echo   http: ^1.4.0 >> pubspec.yaml
echo   shared_preferences: ^2.5.3 >> pubspec.yaml
echo   intl: ^0.20.2 >> pubspec.yaml
echo   dio: ^5.4.3+1 >> pubspec.yaml
echo   path_provider: ^2.1.3 >> pubspec.yaml
echo   open_file: ^3.3.2 >> pubspec.yaml
echo   share_plus: ^7.2.1 >> pubspec.yaml
echo   excel: ^4.0.2 >> pubspec.yaml
echo   responsive_framework: ^1.4.0 >> pubspec.yaml
echo   url_launcher: ^6.2.5 >> pubspec.yaml
echo   universal_html: ^2.2.4 >> pubspec.yaml
echo   uuid: ^4.2.1 >> pubspec.yaml
echo   permission_handler: ^11.3.1 >> pubspec.yaml
echo   data_table_2: ^2.6.0 >> pubspec.yaml
echo   syncfusion_flutter_datagrid: ^30.1.39 >> pubspec.yaml
echo   package_info_plus: ^8.3.0 >> pubspec.yaml
echo   path: ^1.9.1 >> pubspec.yaml
echo   collection: ^1.19.1 >> pubspec.yaml
echo   flutter_lints: ^6.0.0 >> pubspec.yaml
echo   lints: ^6.0.0 >> pubspec.yaml
echo   meta: ^1.16.0 >> pubspec.yaml
echo   mime: ^1.0.6 >> pubspec.yaml
echo   xml: ^6.5.0 >> pubspec.yaml
echo   vector_math: ^2.1.4 >> pubspec.yaml
echo   test_api: ^0.7.4 >> pubspec.yaml
echo   image: ^4.3.0 >> pubspec.yaml
echo   petitparser: ^6.1.0 >> pubspec.yaml
echo   syncfusion_flutter_charts: ^30.1.39 >> pubspec.yaml
echo   csv: ^6.0.0 >> pubspec.yaml
echo. >> pubspec.yaml
echo dev_dependencies: >> pubspec.yaml
echo   flutter_test: >> pubspec.yaml
echo     sdk: flutter >> pubspec.yaml
echo. >> pubspec.yaml
echo flutter: >> pubspec.yaml
echo   uses-material-design: true >> pubspec.yaml
echo   assets: >> pubspec.yaml
echo     - assets/ >> pubspec.yaml
echo. >> pubspec.yaml
echo flutter_web: >> pubspec.yaml
echo   renderer: html >> pubspec.yaml
echo   use_skia: false >> pubspec.yaml
echo   use_canvaskit: false >> pubspec.yaml

REM 기본 디렉토리 구조 생성
if not exist "lib\screens" mkdir lib\screens
if not exist "lib\models" mkdir lib\models
if not exist "lib\services" mkdir lib\services
if not exist "lib\providers" mkdir lib\providers
if not exist "lib\utils" mkdir lib\utils
if not exist "lib\widgets" mkdir lib\widgets
if not exist "assets" mkdir assets

REM 기본 main.dart 생성
echo import 'package:flutter/material.dart'; > lib\main.dart
echo import 'package:provider/provider.dart'; >> lib\main.dart
echo import 'package:flutter_localizations/flutter_localizations.dart'; >> lib\main.dart
echo. >> lib\main.dart
echo void main() { >> lib\main.dart
echo   runApp(const MpmApp()); >> lib\main.dart
echo } >> lib\main.dart
echo. >> lib\main.dart
echo class MpmApp extends StatelessWidget { >> lib\main.dart
echo   const MpmApp({super.key}); >> lib\main.dart
echo. >> lib\main.dart
echo   @override >> lib\main.dart
echo   Widget build(BuildContext context) { >> lib\main.dart
echo     return MaterialApp( >> lib\main.dart
echo       title: 'MPM App', >> lib\main.dart
echo       theme: ThemeData( >> lib\main.dart
echo         primarySwatch: Colors.blue, >> lib\main.dart
echo         useMaterial3: true, >> lib\main.dart
echo       ), >> lib\main.dart
echo       localizationsDelegates: const [ >> lib\main.dart
echo         GlobalMaterialLocalizations.delegate, >> lib\main.dart
echo         GlobalWidgetsLocalizations.delegate, >> lib\main.dart
echo         GlobalCupertinoLocalizations.delegate, >> lib\main.dart
echo       ], >> lib\main.dart
echo       supportedLocales: const [ >> lib\main.dart
echo         Locale('ko', 'KR'), >> lib\main.dart
echo         Locale('en', 'US'), >> lib\main.dart
echo       ], >> lib\main.dart
echo       home: const MpmHomePage(), >> lib\main.dart
echo     ); >> lib\main.dart
echo   } >> lib\main.dart
echo } >> lib\main.dart
echo. >> lib\main.dart
echo class MpmHomePage extends StatelessWidget { >> lib\main.dart
echo   const MpmHomePage({super.key}); >> lib\main.dart
echo. >> lib\main.dart
echo   @override >> lib\main.dart
echo   Widget build(BuildContext context) { >> lib\main.dart
echo     return Scaffold( >> lib\main.dart
echo       appBar: AppBar( >> lib\main.dart
echo         title: const Text('MPM App'), >> lib\main.dart
echo       ), >> lib\main.dart
echo       body: const Center( >> lib\main.dart
echo         child: Text('Welcome to MPM App!'), >> lib\main.dart
echo       ), >> lib\main.dart
echo     ); >> lib\main.dart
echo   } >> lib\main.dart
echo } >> lib\main.dart

echo MPM App created successfully!
echo.
echo Next steps:
echo 1. cd mpm_app\mpm_app
echo 2. flutter pub get
echo 3. flutter run -d chrome
echo.
pause 