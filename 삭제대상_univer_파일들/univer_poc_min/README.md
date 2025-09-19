# Univer POC (안전 초기화 + 폴백)

## 구성
- `index.html` : Univer 번들이 있으면 사용, 없으면 폴백 테이블 표시 (오류 없음)
- `univer-loader.js` : `window.Univer`가 실제로 준비될 때까지 대기
- `app.js` : 초기화/로그/파일 선택 예제

## 사용 방법
1. `index.html` 상단의 **주석 처리된** 3개 `<script data-univer>`를 실제 프로젝트의 Univer UMD 번들 경로로 교체하고 주석을 해제하세요.
2. 로컬 서버(예: `npx http-server`)로 띄워서 Network 탭에서 번들이 200 OK인지 확인하세요.
3. 페이지는 Univer가 준비되면 초기화 메시지를, 아니면 **폴백 테이블**을 보여줍니다. 어떤 경우에도 콘솔 에러 없이 동작합니다.

> 기존 프로젝트에선 `univer-loader.js`를 포함하고, 초기화 직전에 `await UniverLoader.ensureUniverReady()`만 추가하면 됩니다.
