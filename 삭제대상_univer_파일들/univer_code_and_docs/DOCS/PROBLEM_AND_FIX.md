# Univer UMD 초기화 문제 — 원인과 해결 (전달용 텍스트)

## 증상
- `Cannot read properties of undefined (reading 'createIdentifier' | 'MUTATION' | 'COMMAND')`
- `Cannot read properties of undefined (reading 'EN_US')`
- 전역: `UniverCore`, `UniverSheets`, `UniverSheetsUi`, `initUniver`는 보임.

## 근본 원인
1) 잘못된 네임스페이스 접근  
   - UMD 환경에서는 `LocaleType`, `Univer`, `Tools` 등이 **항상 `UniverCore.*`** 아래에 있습니다.
   - `LocaleType.EN_US`를 전역 등 다른 경로에서 접근하면 `undefined` → EN_US 접근 실패.

2) 로드 순서/버전 불일치  
   - 스크립트 순서가 `core → sheets → sheets-ui`가 아니거나, 세 패키지의 버전이 서로 다르면 전역이 온전히 구성되지 않습니다.

3) 불필요한 심화 API 사용  
   - 초기 부트스트랩 단계에서 `createIdentifier`/`MUTATION`/`COMMAND` 같은 DI/커맨드 API를 호출하면 버전/시점/네임스페이스 차이로 `undefined` 발생.
   - 기본 렌더링에는 필요 없습니다.

4) UI 컨테이너/플러그인 등록 누락 또는 순서 오류

## 해결책 (체크리스트)
- **스크립트 순서 고정:** `@univerjs/core` → `@univerjs/sheets` → `@univerjs/sheets-ui` → (content.js) → `index.js`
- **버전 통일:** 세 패키지 모두 동일한 릴리스(예: `0.2.13`)로 고정.
- **정확한 네임스페이스:** `UniverCore.LocaleType.EN_US`로 로캘 설정. 필요한 심볼은 전부 `UniverCore.*`에서 가져오기.
- **초기화 최소화:** 부트스트랩에서는 `createIdentifier`/`MUTATION`/`COMMAND` 사용 금지.
- **UI 컨테이너 보장:** `<div id="app"></div>` 존재, UI 플러그인에 `{ container }` 전달.

## 빠른 진단 절차
1) `window.UniverCore && Object.keys(UniverCore)`에 `LocaleType`, `Univer`, `Tools`가 보이는지 확인
2) `UniverCore.LocaleType && UniverCore.LocaleType.EN_US` 존재 확인
3) Network/소스 순서로 core→sheets→sheets-ui 순서 확인
4) 세 UMD 파일의 버전 문자열 동일 여부 확인
5) 코드에서 `createIdentifier`/`MUTATION`/`COMMAND` 문자열 검색 및 초기화 경로에서 제거

## 정상 기대 로그
- MSM Excel 시스템 시작 → 모듈 확인 완료 → Univer 초기화 완료
