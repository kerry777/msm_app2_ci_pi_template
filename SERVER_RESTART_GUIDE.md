# 서버 재시작 체크리스트 (MDM 시스템)

## 요약: 재시작 시 필수 작업 순서

1. **PM2 프로세스 재시작**
   ```bash
   pm2 restart mdm-app
   pm2 restart mdm-web
   ```
2. **nginx 재시작 (Windows)**
   ```cmd
   taskkill /F /IM nginx.exe
   nginx
   ```
3. **포트 상태 확인**
   ```cmd
   netstat -ano | findstr :4000
   netstat -ano | findstr :4003
   netstat -ano | findstr :80
   ```
4. **서비스 정상 동작 확인**
   - http://it.mek-ics.com/mdm 접속
   - API 호출 정상 여부 확인
5. **로그 확인**
   ```bash
   pm2 logs mdm-app --lines 20
   pm2 logs mdm-web --lines 20
   type F:\projects\mdm\nginx\logs\error.log
   ```

---

## 각 단계별 이유와 주의사항

### 1. PM2 프로세스 재시작
- **이유:** Node.js(Express) 서버(`mdm-app`, `mdm-web`)가 정상적으로 실행되어야 웹/API 서비스가 동작합니다.
- **주의:**
  - `pm2 list`로 프로세스 상태를 먼저 확인하세요.
  - 프로세스가 없으면 `pm2 start ecosystem.config.js`로 재등록 필요.
  - `pm2 save`로 현재 상태를 저장하면 재부팅 후 자동 복구됩니다.

### 2. nginx 재시작 (Windows)
- **이유:** nginx는 80번 포트에서 외부 요청을 받아 내부 Express 서버로 프록시합니다.
- **주의:**
  - 기존 nginx 프로세스가 남아 있으면 설정이 적용되지 않을 수 있으니 반드시 종료 후 재시작하세요.
  - 여러 번 실행하면 프로세스가 중복될 수 있으니 `taskkill /F /IM nginx.exe`로 모두 종료 후 `nginx`로 시작.
  - 설정 파일 경로가 다를 경우 `nginx -c <경로>`로 명시.

### 3. 포트 상태 확인
- **이유:** 각 서비스가 올바른 포트(4000, 4003, 80)에서 정상적으로 리스닝 중인지 확인합니다.
- **주의:**
  - 포트가 열려 있지 않으면 서비스가 정상 동작하지 않습니다.
  - 포트 충돌 시 기존 프로세스를 종료 후 재시작하세요.

### 4. 서비스 정상 동작 확인
- **이유:** 실제 웹/모바일/외부에서 서비스가 정상적으로 동작하는지 최종 확인합니다.
- **주의:**
  - 브라우저 캐시로 인해 이전 화면이 보일 수 있으니 Ctrl+F5로 강제 새로고침.
  - API 호출도 Postman 등으로 직접 테스트 권장.

### 5. 로그 확인
- **이유:** 에러, 경고, 비정상 동작 여부를 빠르게 파악할 수 있습니다.
- **주의:**
  - pm2 로그와 nginx 에러 로그를 모두 확인하세요.
  - 에러 발생 시 로그 메시지를 참고해 원인 분석.

---

## 자동 시작 설정 (권장)

### PM2 자동 시작
```bash
pm2 startup
pm2 save
```
- **이유:** 서버 재부팅 시 PM2와 모든 Node.js 프로세스가 자동으로 복구됩니다.

### nginx 자동 시작
- **방법1:** 윈도우 작업 스케줄러에 nginx 등록
- **방법2:** NSSM 등으로 nginx를 윈도우 서비스로 등록
- **이유:** 서버 재부팅 시 nginx가 자동으로 실행되어야 외부 접속이 가능합니다.

---

## 기타 주의사항
- 404 핸들러는 반드시 모든 라우팅 코드의 맨 마지막에 위치해야 합니다.
- nginx의 proxy_pass 경로는 반드시 `/mdm/`로 끝나야 합니다.
- Express의 정적 파일 경로와 실제 파일 위치(폴더 구조)가 일치해야 합니다.
- 환경변수, .env 파일, ecosystem.config.js 등 설정 파일이 최신 상태인지 항상 확인하세요. 