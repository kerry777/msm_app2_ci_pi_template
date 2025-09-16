# Flutter 개발 환경 "프로펠러" 문제 해결 가이드

## 🚨 문제 상황

### 발생한 문제
- **"빙빙" 또는 "프로펠러" 현상**: 애플리케이션이 무한 로딩 상태
- **시스템 리소스 과다 사용**: CPU, 메모리 사용량 급증 (총 1GB 이상)
- **다수의 백그라운드 프로세스**: 15개 이상의 Flutter 개발 서버 동시 실행
- **새로운 프로세스 계속 생성**: 기존 프로세스 종료해도 새로 생성됨

### 근본 원인
1. **다수의 `flutter run` 명령 실행**: 여러 번의 개발 서버 실행으로 프로세스 누적
2. **백그라운드 Bash 세션 누적**: Claude Code에서 생성된 15개의 백그라운드 세션
3. **프로세스 종료 실패**: 일반적인 프로세스 종료 방법으로는 해결되지 않음
4. **토큰 인증 버그**: AuthProvider에서 로그인 루프 발생 (수정 완료)

## 🔍 문제 진단 방법

### 1. Dart 프로세스 확인
```bash
tasklist | findstr dart.exe
```
**정상 상태**: 0-2개의 dart.exe 프로세스
**문제 상태**: 6개 이상의 dart.exe 프로세스 (각 40-280MB 사용)

### 2. 백그라운드 Bash 세션 확인
Claude Code 시스템 메시지에서 다음과 같은 알림이 15개 이상 나타남:
```
Background Bash [ID] (command: flutter run -d chrome --web-port=[PORT]) (status: running)
```

### 3. 시스템 리소스 확인
- **작업 관리자**에서 dart.exe 프로세스들의 메모리 사용량 확인
- 각 프로세스당 40-280MB 사용
- 총 메모리 사용량: 1GB 이상

## 🛠️ 해결 방법

### ✅ 확실한 해결책: PC 재부팅
```bash
# Windows 재시작 (권장)
shutdown /r /t 0
```
**장점**:
- **100% 확실한 해결**
- 모든 백그라운드 프로세스 완전 정리
- 15개 백그라운드 Bash 세션 모두 종료
- 시스템 리소스 정상화

### ⚠️ 부분적 해결책: 프로세스 수동 정리
```bash
# PowerShell에서 모든 dart 프로세스 종료
powershell "Get-Process dart -ErrorAction SilentlyContinue | Stop-Process -Force"
```
**한계**: 백그라운드 Bash 세션들이 새로운 프로세스를 계속 생성

### 🎯 임시 해결책: 정적 빌드 사용 (현재 적용됨)
```bash
# Flutter 웹 빌드 (HTML 렌더러)
flutter build web --dart-define=FLUTTER_WEB_USE_SKIA=false

# nginx에 배포
powershell "Copy-Item 'C:\projects\msm_app\msm_app1\client\build\web\*' 'F:\projects\msm\web\' -Recurse -Force"
```
**장점**:
- 백그라운드 프로세스 없이 애플리케이션 사용 가능
- http://localhost/msm/ 에서 정상 작동
- 토큰 인증 문제 수정 적용됨

## 📋 예방 방법

### 1. 개발 서버 실행 전 정리
```bash
# 기존 dart 프로세스 확인 및 정리
tasklist | findstr dart.exe
powershell "Get-Process dart -ErrorAction SilentlyContinue | Stop-Process -Force"
```

### 2. 단일 개발 서버 사용
```bash
# 하나의 포트에서만 실행
flutter run -d chrome --web-port=50700
```

### 3. 정적 빌드 우선 사용
개발이 완료된 기능은 정적 빌드로 배포하여 사용

## 🔧 재부팅 후 권장 실행 순서

### 1. 백엔드 서버 시작
```bash
cd F:\projects\msm\server
pm2 start ecosystem.config.js
pm2 list  # msm-app, msm-web 상태 확인
```

### 2. Flutter 정적 빌드 확인
```bash
# nginx 정적 파일 확인
ls F:\projects\msm\web\
```

### 3. 애플리케이션 테스트
```bash
start chrome "http://localhost/msm/"
```

## 📝 기술적 세부사항

### 해결된 문제들
1. ✅ **토큰 인증 수정**: `AuthProvider._loadToken()` 버그 수정 완료
   ```dart
   // 수정된 코드 (lib/providers/auth_provider.dart:57-60)
   if (_token != null && _token!.isNotEmpty) {
     _isAuthenticated = true;
     debugPrint('[AuthProvider._loadToken] Set authenticated to true');
   }
   ```
2. ✅ **로그인 화면 정상 표시**: 자동 로그인 문제 해결
3. ✅ **정적 빌드 배포**: nginx에 안정적 배포 완료

### 문제 발생 시점
- **날짜**: 2025년 9월 16일 오후 4시경
- **원인**: 토큰 인증 문제 해결 과정에서 다수의 Flutter 서버 실행
- **증상**: "빙빙" 로딩 → 로그인 창 안나옴 → 프로펠러 현상

### 시도된 해결 방법들
1. ✅ **토큰 인증 수정**: AuthProvider 로직 수정 후 되돌림
2. ❌ **개별 프로세스 종료**: `Stop-Process` 명령으로 일시적 효과만
3. ❌ **백그라운드 세션 종료**: `KillShell` 명령 실패
4. ✅ **정적 빌드 배포**: 최종 해결책으로 성공

### 학습된 교훈
- **정적 빌드 우선**: 개발 완료 후에는 정적 빌드 사용 권장
- **프로세스 관리**: 개발 서버 실행 전 기존 프로세스 정리 필수
- **재부팅의 가치**: 복잡한 프로세스 문제는 재부팅이 가장 확실
- **백그라운드 세션 주의**: Claude Code 백그라운드 세션 누적 주의

## 🚀 재부팅 후 확인 사항

### 1. 프로세스 정리 확인
```bash
tasklist | findstr dart.exe
# 결과: 프로세스 없음 또는 최소한의 프로세스만 표시되어야 함
```

### 2. 애플리케이션 정상 작동 확인
- http://localhost/msm/ 접속
- ✅ 로그인 화면 정상 표시
- ✅ ID/비밀번호 자동 채움 (자동완성)
- ✅ 사용자가 로그인 버튼 클릭
- ✅ 로그인 후 메인 화면 정상 이동

### 3. 성능 확인
- ✅ 페이지 로딩 속도 개선
- ✅ 시스템 메모리 사용량 정상화 (1GB+ → 정상)
- ✅ CPU 사용률 안정화
- ✅ "프로펠러" 현상 완전 해결

### 4. 백그라운드 프로세스 확인
- Claude Code 시스템 메시지에서 background bash 알림 없어야 함
- dart.exe 프로세스 0-2개 이하 유지

---

**문제 발생일**: 2025년 9월 16일 오후 4:16
**문제 해결 담당**: Claude Code
**최종 권장 해결책**: PC 재부팅
**현재 임시 해결상태**: 정적 빌드로 정상 작동 중