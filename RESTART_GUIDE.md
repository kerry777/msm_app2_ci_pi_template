# 🔄 시스템 재시작 및 깔끔한 시작 가이드

## 📋 현재 상황
- 22개의 Flutter 개발 서버가 동시 실행 중
- 메모리 및 포트 충돌로 인한 불안정 상태
- 임시 파일들로 인한 변경사항 감지

## 🎯 해결 방법

### 1단계: 수동 컴퓨터 재시작
```
Windows + R → shutdown /r /t 0
또는
시작 메뉴 → 전원 → 다시 시작
```

### 2단계: 재시작 후 실행할 명령들
```bash
# 1. 프로젝트 폴더로 이동
cd C:\projects\msm_app\msm_app1\client

# 2. Flutter 캐시 정리
flutter clean
flutter pub get

# 3. 백엔드 서버 확인
cd F:\projects\msm\server
pm2 list

# 4. 단일 Flutter 서버만 실행
cd C:\projects\msm_app\msm_app1\client
flutter run -d chrome --web-browser-flag="--disable-web-security"
```

## ✅ 완료 후 상태
- 단일 Flutter 개발 서버만 실행
- 깔끔한 메모리 상태
- 포트 충돌 없음
- 안정적인 개발 환경

---
**작성일**: 2025-01-16
**목적**: 시스템 정리 및 안정화