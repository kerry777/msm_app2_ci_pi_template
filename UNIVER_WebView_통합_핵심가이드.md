
# UNIVER WebView 통합 **핵심 구현 가이드** (Flutter & Windows WebView2)
작성일: 2025-09-17 00:00

이 문서는 **클라이언트(WebView) 기반 Univer 임베딩**을 빠르게 구현/수정하기 위한 **핵심 방법**만 정리했습니다.  
코드는 예시이며, 실제 프로젝트에 맞춰 경로나 네임스페이스만 조정하면 됩니다.

---

## 0. 목표/전제
- Univer **Preset UMD**를 WebView 내부 HTML에서 로드하여 **엑셀 유사 편집기**를 띄운다.
- **값-only 임·익스포트**(서식/수식 미보존)는 **SheetJS**로 처리한다.
- **WebView ↔ HTML(JS)** 간 메시지 브리지를 통해 **파일 열기/저장**을 네이티브에서 수행한다.
- (옵션) **완전 보존형(서식/수식/인쇄설정 등)**은 **서버 임·익스포트**를 붙인다.

---

## 1. 아키텍처(요약)

```
[Host App]
  ├─ Flutter(WebView)  또는  Windows(WebView2)
  ├─ 파일 선택 / 저장(네이티브) / 권한 처리
  └─ JS 호출(runJavaScript / ExecuteScriptAsync)

        ⇅ postMessage(JSON)

[HTML in WebView]
  ├─ Univer Preset UMD (CDN) 로드
  ├─ SheetJS 로드
  ├─ Univer 초기화(createUniver + UniverSheetsCorePreset)
  ├─ Range API로 값-only set/get
  └─ window.UniverHostAPI (호스트가 호출할 JS API)
```

---

## 2. HTML(에셋) 필수 요소

### 2.1 CDN 의존성(최소)
- `@univerjs/presets`  
- `@univerjs/preset-sheets-core` (+ locale, CSS)  
- `react`, `react-dom`, `rxjs`, `echarts`  
- `xlsx.full.min.js` (SheetJS)

### 2.2 Univer 초기화(핵심)
```html
<script>
  const { createUniver } = UniverPresets;
  const { LocaleType, mergeLocales } = UniverCore;
  const { UniverSheetsCorePreset } = UniverPresetSheetsCore;

  const { univerAPI } = createUniver({
    locale: LocaleType.EN_US,
    locales: { [LocaleType.EN_US]: mergeLocales(UniverPresetSheetsCoreEnUS) },
    presets: [UniverSheetsCorePreset({ container: 'univer' })],
  });

  univerAPI.createWorkbook({ name: 'WebView Demo' });
</script>
```

### 2.3 값-only 임포트(핵심 흐름)
```js
async function importXlsxValuesOnly(file) {
  const buf = await file.arrayBuffer();
  const wb  = XLSX.read(new Uint8Array(buf), { type: 'array', cellDates: true });
  const ws  = wb.Sheets[wb.SheetNames[0]];
  const aoa = XLSX.utils.sheet_to_json(ws, { header: 1, raw: true });

  const rows = aoa.length;
  const cols = Math.max(0, ...aoa.map(r => r.length));
  const values = Array.from({length: rows}, (_, r) => {
    const row = aoa[r] || [];
    return Array.from({length: cols}, (_, c) => row[c] === undefined ? null : row[c]);
  });

  const wbk   = univerAPI.getActiveWorkbook();
  const sheet = wbk.getActiveSheet();
  sheet.getRange(0, 0, rows, cols).setValues(values);
}
```

### 2.4 값-only 익스포트(핵심 흐름)
```js
async function exportXlsxBlob() {
  const wbk   = univerAPI.getActiveWorkbook();
  const sheet = wbk.getActiveSheet();
  const values = sheet.getRange(0, 0, 200, 50).getValues(); // 안전영역 예시
  const ws = XLSX.utils.aoa_to_sheet(values);
  const outWb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(outWb, ws, 'Sheet1');
  const ab = XLSX.write(outWb, { bookType: 'xlsx', type: 'array' });
  return new Blob([ab], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
}
```

### 2.5 브리지(API 계약)
**JS가 노출:** (호스트가 호출)
```js
window.UniverHostAPI = {
  importXlsxValuesOnlyFromBase64: async (b64, filename='import.xlsx') => {
    const bin = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
    const blob = new Blob([bin], {type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
    await importXlsxValuesOnly(new File([blob], filename, {type: blob.type}));
  },
  exportXlsxValuesOnly: async () => {
    const blob = await exportXlsxBlob();
    const reader = new FileReader();
    reader.onload = () => {
      const b64 = reader.result.split(',')[1];
      sendToHost('download-xlsx-base64', { filename: 'export_values_only.xlsx', base64: b64 });
    };
    reader.readAsDataURL(blob);
  }
};
```

**JS가 호출:** (호스트로 메시지 전송)
```js
function sendToHost(type, payload) {
  if (window.chrome?.webview?.postMessage) {
    window.chrome.webview.postMessage({ type, payload }); // WebView2
  } else if (window.Host?.postMessage) {
    window.Host.postMessage(JSON.stringify({ type, payload })); // Flutter
  }
}
```

---

## 3. Flutter(WebView) 핵심 구현

### 3.1 의존성
- `webview_flutter` (필수)
- `file_saver` (선택: 내보낸 파일 저장 시)

### 3.2 메시지 수신(HTML → Flutter)
```dart
..addJavaScriptChannel(
  'Host',
  onMessageReceived: (m) async {
    final data = jsonDecode(m.message);
    if (data['type'] == 'download-xlsx-base64') {
      final p = data['payload'];
      final name = p['filename'] ?? 'export.xlsx';
      final b64  = p['base64'];
      final bytes = base64Decode(b64);
      await FileSaver.instance.saveFile(
        name: name, bytes: Uint8List.fromList(bytes), mimeType: MimeType.microsoftExcel,
      );
    }
  },
)
```

### 3.3 메시지 송신(Flutter → HTML)
```dart
await controller.runJavaScript(
  "window.UniverHostAPI && window.UniverHostAPI.importXlsxValuesOnlyFromBase64('${b64}', 'import.xlsx')"
);
```

---

## 4. Windows(WebView2) 핵심 구현

### 4.1 메시지 수신(HTML → 네이티브)
```csharp
web.CoreWebView2.WebMessageReceived += (s, e) => {
  var root = JsonDocument.Parse(e.WebMessageAsJson).RootElement;
  var type = root.GetProperty("type").GetString();
  if (type == "download-xlsx-base64") {
    var p = root.GetProperty("payload");
    var name = p.GetProperty("filename").GetString() ?? "export.xlsx";
    var b64  = p.GetProperty("base64").GetString() ?? "";
    File.WriteAllBytes(name, Convert.FromBase64String(b64));
  }
};
```

### 4.2 메시지 송신(네이티브 → HTML)
```csharp
await web.CoreWebView2.ExecuteScriptAsync(
  "window.UniverHostAPI && window.UniverHostAPI.exportXlsxValuesOnly()"
);
```

### 4.3 로컬 자산 로드(가상 호스트 매핑)
```csharp
web.CoreWebView2.SetVirtualHostNameToFolderMapping(
  "appassets.example",
  Path.Combine(AppContext.BaseDirectory, "assets"),
  CoreWebView2HostResourceAccessKind.Allow
);
web.Source = new Uri("https://appassets.example/index_webview.html");
```

---

## 5. 완전 보존형 임·익스포트(선택)

- **서버 임·익스포트** 사용 권장(수식/서식/인쇄설정/차트 보존).
- 브라우저(JS)에서는 업로드/다운로드 **엔드포인트**를 호출:
  - `POST /api/import-xlsx` → 서버가 Univer 문서/스냅샷 생성 → unitId 반환
  - `GET /api/export-xlsx?unitId=...` → 서버가 현재 스냅샷을 xlsx로 직렬화
- WebView에서는 `fetch` 또는 네이티브 HTTP 클라이언트 사용.

---

## 6. 체크리스트 & 디버깅

- [ ] HTML에서 `UniverPresets`, `UniverCore`, `UniverPresetSheetsCore` **전역 네임스페이스** 확인(console)  
- [ ] `createUniver` 초기화 및 `univerAPI.createWorkbook({name})` 호출  
- [ ] 버튼 이벤트가 `importXlsxValuesOnly` / `exportXlsxValuesOnly`에 연결  
- [ ] WebView 채널/메시지 핸들러 등록(Flutter: `JavaScriptChannel`, WebView2: `WebMessageReceived`)  
- [ ] Base64 디코딩/파일 저장 과정 누락 여부  
- [ ] 로컬 파일을 HTML에서 직접 `fetch` 시 CORS 이슈 → **가상 호스트 매핑** 또는 **Flutter 에셋** 사용

---

## 7. 한계/주의
- 값-only 임·익스포트: **수식/서식/인쇄설정/차트 미보존**  
- 대용량 처리 시 서버 계산/스냅샷 스트리밍 고려  
- 모바일(Android/iOS): 파일 저장 권한/경로 정책 확인

---

## 8. 파일 구성(권장)
```
/assets
  └─ index_webview.html   # 위 요건을 만족하는 HTML
/lib (Flutter)
/... (WebView2: assets 매핑)
```

---

이 문서를 클로드에 전달하면, 아래를 즉시 수행할 수 있습니다:
1) HTML을 **요건대로 보강**  
2) Flutter/WebView2의 메시지 브리지 **연결/검증**  
3) (옵션) 서버 임·익스포트 **엔드포인트** 연결
