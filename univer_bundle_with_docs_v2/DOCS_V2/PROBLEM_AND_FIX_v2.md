# Univer UMD 초기화 문제 — V2 분석 및 해결

## 관찰된 추가 증상
- `UniverCore 전체 구조: Object`, `UniverCore 키들: Array(0)` → `Object.keys(UniverCore)`가 빈 배열
- `LocaleType이 UniverCore에 없음`
- `UniverCore.Univer is not a constructor`

## 해석
- 사용 중인 UMD 빌드/버전에 따라 전역 네임스페이스가 **`UniverCore`가 아닌 다른 루트(`Univer.core`, `Univer.Core`, default export 등)** 아래에 배치될 수 있습니다.
- 어떤 빌드는 `Object.keys`로 열거되지 않는 프로퍼티(비열거)로 심볼을 노출하거나, `default` 아래에 넣기도 합니다.
- 결과적으로 `UniverCore.LocaleType`/`UniverCore.Univer`가 비어 있거나 생성자가 아닌 값으로 보일 수 있습니다.

## 대응 전략(V2)
1) **런타임 탐색(robust resolver)**  
   - 다음 후보에서 Core/Sheets/SheetsUI 네임스페이스를 순차 탐지:  
     - `window.UniverCore`  
     - `window.Univer.core` / `window.Univer.Core` / `...default`  
   - 같은 방식으로 Sheets / SheetsUI 후보를 탐지.

2) **심볼 추출 시 다중 경로 시도**  
   - `LocaleType` → `Core.LocaleType || Core.locale?.LocaleType || Core.Locales || Core.LOCALE`  
   - `Univer` 생성자 → `Core.Univer || Core.default?.Univer || Core.Core?.Univer`  
   - `Tools` → `Core.Tools || Core.utils || Core.Helpers`  
   - `UniverInstanceType` → `Core.UniverInstanceType || Core.InstanceType`

3) **로캘 fallback**  
   - `EN_US`/`enUS`/`en-US` 중 존재하는 것을 사용. 없으면 로캘 없이 부트스트랩.

4) **플러그인 클래스 명 탐지**  
   - `Sheets` → `UniverSheetsPlugin` (또는 default 하위)  
   - `SheetsUI` → `UniverSheetsUIPlugin` (또는 default 하위)

5) **여전히 실패 시**  
   - 세 UMD의 버전을 동일 릴리스로 고정하고, UMD 빌드 종류(ESM/UMD) 혼용이 없는지 재확인.

## 기대 효과
- UMD 네임스페이스 차이/비열거 속성 문제/`default` 래핑 여부에 상관없이 대부분의 빌드 조합에서 초기화 성공률을 크게 높입니다.
