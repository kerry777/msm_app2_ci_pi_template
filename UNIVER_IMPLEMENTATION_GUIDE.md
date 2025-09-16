# Univer 구현 가이드

## 1. 기본 설치 및 설정

### CDN 방식 (가장 간단)
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Univer Spreadsheet</title>
    <!-- Univer 핵심 CSS -->
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/design/lib/index.css" />
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/sheets-ui/lib/index.css" />
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/sheets-formula/lib/index.css" />
</head>
<body>
    <div id="univer-container" style="width: 100%; height: 600px;"></div>

    <!-- Univer 핵심 JavaScript -->
    <script src="https://unpkg.com/@univerjs/core/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/design/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/engine-render/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/engine-formula/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets-ui/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets-formula/lib/umd/index.js"></script>
</body>
</html>
```

### npm 패키지 설치 방식
```bash
npm install @univerjs/core @univerjs/design @univerjs/engine-render @univerjs/engine-formula @univerjs/sheets @univerjs/sheets-ui @univerjs/sheets-formula @univerjs/facade
```

## 2. 기본 Univer 인스턴스 생성

### 2.1 최소한의 설정
```javascript
// 1. Univer 인스턴스 생성
const univer = new Univer.Univer({
    theme: Univer.defaultTheme,
    locale: Univer.LocaleType.ZH_CN,
    logLevel: Univer.LogLevel.VERBOSE,
});

// 2. 필수 플러그인 등록
univer.registerPlugin(UniverseDesign.UniverDesignPlugin);
univer.registerPlugin(UniverseEngineRender.UniverRenderEnginePlugin);
univer.registerPlugin(UniverseEngineFormula.UniverFormulaEnginePlugin);
univer.registerPlugin(UniverseSheets.UniverSheetsPlugin);
univer.registerPlugin(UniverseSheetsUi.UniverSheetsUIPlugin);
univer.registerPlugin(UniverseSheetsFormula.UniverSheetsFormulaPlugin);

// 3. 워크북 생성
univer.createUniverSheet({
    name: 'Demo',
    sheetOrder: ['sheet1'],
    sheets: {
        sheet1: {
            name: 'sheet1',
            cellData: {
                0: {
                    0: { v: 'Hello' },
                    1: { v: 'World' },
                },
            },
        },
    },
});
```

### 2.2 고급 설정
```javascript
const univerInstance = new Univer.Univer({
    theme: Univer.defaultTheme,
    locale: Univer.LocaleType.KO_KR, // 한국어 로케일
    logLevel: Univer.LogLevel.WARN,
    // 컨테이너 지정
    container: 'univer-container'
});

// 플러그인 등록 (순서 중요!)
const corePlugins = [
    UniverseDesign.UniverDesignPlugin,
    UniverseEngineRender.UniverRenderEnginePlugin,
    UniverseEngineFormula.UniverFormulaEnginePlugin
];

const sheetPlugins = [
    UniverseSheets.UniverSheetsPlugin,
    UniverseSheetsUi.UniverSheetsUIPlugin,
    UniverseSheetsFormula.UniverSheetsFormulaPlugin
];

[...corePlugins, ...sheetPlugins].forEach(plugin => {
    univerInstance.registerPlugin(plugin);
});
```

## 3. Excel 파일 로드하기

### 3.1 파일 업로드 방식
```javascript
async function loadExcelFile(file) {
    try {
        // File API로 ArrayBuffer 읽기
        const arrayBuffer = await file.arrayBuffer();

        // Univer에서 Excel 파일 파싱
        const workbookData = await univerInstance.createUniverSheetFromExcel(arrayBuffer);

        console.log('Excel file loaded successfully:', workbookData);
        return workbookData;
    } catch (error) {
        console.error('Failed to load Excel file:', error);
        throw error;
    }
}

// 파일 입력 요소와 연결
document.getElementById('excel-upload').addEventListener('change', async (event) => {
    const file = event.target.files[0];
    if (file && (file.type === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' || file.name.endsWith('.xlsx'))) {
        await loadExcelFile(file);
    }
});
```

### 3.2 URL에서 Excel 파일 로드
```javascript
async function loadExcelFromUrl(url) {
    try {
        // Fetch API로 파일 다운로드
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const arrayBuffer = await response.arrayBuffer();

        // Univer로 파일 로드
        const workbookData = await univerInstance.createUniverSheetFromExcel(arrayBuffer);

        return workbookData;
    } catch (error) {
        console.error('Failed to load Excel from URL:', error);
        throw error;
    }
}

// 사용 예제
loadExcelFromUrl('/assets/sample.xlsx')
    .then(workbook => console.log('Loaded:', workbook))
    .catch(error => console.error('Error:', error));
```

## 4. 데이터 조작 및 편집

### 4.1 셀 값 설정
```javascript
// 특정 셀에 값 설정
univerInstance.getActiveWorkbook().getActiveSheet().getRange('A1').setValue('Hello Univer!');

// 여러 셀에 한 번에 값 설정
univerInstance.getActiveWorkbook().getActiveSheet().getRange('A1:C3').setValues([
    ['Name', 'Age', 'City'],
    ['John', 25, 'Seoul'],
    ['Jane', 30, 'Busan']
]);
```

### 4.2 셀 스타일 적용
```javascript
const sheet = univerInstance.getActiveWorkbook().getActiveSheet();
const range = sheet.getRange('A1:C1');

// 헤더 스타일 적용
range.setStyle({
    bold: true,
    fontSize: 14,
    fontColor: '#ffffff',
    backgroundColor: '#4472C4',
    horizontalAlignment: 'center'
});
```

### 4.3 수식 사용
```javascript
const sheet = univerInstance.getActiveWorkbook().getActiveSheet();

// 수식 설정
sheet.getRange('D2').setFormula('=B2*C2');
sheet.getRange('D3').setFormula('=SUM(D2:D2)');

// 함수 체인
sheet.getRange('E2').setFormula('=IF(D2>100,"High","Low")');
```

## 5. 이벤트 처리

### 5.1 셀 변경 이벤트
```javascript
// 셀 값이 변경될 때 이벤트 처리
univerInstance.getActiveWorkbook().getActiveSheet().onCellValueChange((range, value) => {
    console.log(`Cell ${range.getA1Notation()} changed to: ${value}`);
});
```

### 5.2 선택 변경 이벤트
```javascript
// 셀 선택이 변경될 때 이벤트 처리
univerInstance.getActiveWorkbook().getActiveSheet().onSelectionChange((range) => {
    console.log(`Selection changed to: ${range.getA1Notation()}`);
});
```

## 6. 내보내기 및 저장

### 6.1 Excel 파일로 내보내기
```javascript
async function exportToExcel() {
    try {
        // Univer 데이터를 Excel 형식으로 변환
        const excelBuffer = await univerInstance.getActiveWorkbook().saveAsExcel();

        // Blob 생성 및 다운로드
        const blob = new Blob([excelBuffer], {
            type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        });

        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'export.xlsx';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    } catch (error) {
        console.error('Export failed:', error);
    }
}
```

### 6.2 JSON 형식으로 저장
```javascript
function saveAsJSON() {
    const workbookData = univerInstance.getActiveWorkbook().getSnapshot();
    const jsonString = JSON.stringify(workbookData, null, 2);

    console.log('Workbook data:', jsonString);
    return workbookData;
}
```

## 7. Flutter와 연동

### 7.1 WebView 사용 방식
```dart
// pubspec.yaml에 추가
// webview_flutter: ^4.4.2

import 'package:webview_flutter/webview_flutter.dart';

class UniverWidget extends StatefulWidget {
  final String excelUrl;

  const UniverWidget({Key? key, required this.excelUrl}) : super(key: key);

  @override
  State<UniverWidget> createState() => _UniverWidgetState();
}

class _UniverWidgetState extends State<UniverWidget> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // 페이지 로드 완료 후 Excel 파일 로드
            _loadExcelFile();
          },
        ),
      )
      ..loadRequest(Uri.parse('assets/univer.html'));
  }

  void _loadExcelFile() {
    _controller.runJavaScript('''
      loadExcelFromUrl('${widget.excelUrl}')
        .then(() => console.log('Excel loaded'))
        .catch(error => console.error('Load failed:', error));
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
```

### 7.2 JavaScript 채널 통신
```dart
// Flutter에서 JavaScript 함수 호출
void _callJavaScriptFunction(String functionName, List<dynamic> args) {
  final argsJson = jsonEncode(args);
  _controller.runJavaScript('$functionName.apply(null, $argsJson)');
}

// JavaScript에서 Flutter로 메시지 전송
_controller.addJavaScriptChannel(
  'FlutterChannel',
  onMessageReceived: (JavaScriptMessage message) {
    print('Message from JavaScript: ${message.message}');
    // 메시지 처리 로직
  },
);
```

## 8. 성능 최적화

### 8.1 대용량 데이터 처리
```javascript
// 가상화 옵션 활성화
const univer = new Univer.Univer({
    theme: Univer.defaultTheme,
    locale: Univer.LocaleType.KO_KR,
    // 가상화 설정
    virtualization: {
        enabled: true,
        rowHeight: 25,
        columnWidth: 100
    }
});
```

### 8.2 메모리 관리
```javascript
// 인스턴스 정리
function cleanup() {
    if (univerInstance) {
        univerInstance.dispose();
        univerInstance = null;
    }
}

// 페이지 언로드 시 정리
window.addEventListener('beforeunload', cleanup);
```

## 9. 오류 처리 및 디버깅

### 9.1 기본 오류 처리
```javascript
try {
    const univer = new Univer.Univer({
        theme: Univer.defaultTheme,
        locale: Univer.LocaleType.KO_KR,
        logLevel: Univer.LogLevel.VERBOSE, // 디버그용
    });
} catch (error) {
    console.error('Univer initialization failed:', error);

    // 폴백 처리
    document.getElementById('univer-container').innerHTML =
        '<p>스프레드시트를 불러올 수 없습니다. 페이지를 새로고침해주세요.</p>';
}
```

### 9.2 로딩 상태 관리
```javascript
function showLoadingSpinner() {
    document.getElementById('loading').style.display = 'block';
}

function hideLoadingSpinner() {
    document.getElementById('loading').style.display = 'none';
}

async function loadExcelWithLoading(url) {
    showLoadingSpinner();
    try {
        await loadExcelFromUrl(url);
    } finally {
        hideLoadingSpinner();
    }
}
```

## 10. 고급 기능

### 10.1 차트 생성
```javascript
// 차트 플러그인 추가 필요
univer.registerPlugin(UniverseSheetsChart.UniverSheetsChartPlugin);

// 차트 생성
const sheet = univerInstance.getActiveWorkbook().getActiveSheet();
sheet.addChart({
    type: 'column',
    range: 'A1:C10',
    position: 'E1',
    title: 'Sales Chart'
});
```

### 10.2 조건부 서식
```javascript
const range = sheet.getRange('A1:A10');
range.addConditionalFormat({
    condition: {
        type: 'cellValue',
        operator: 'greaterThan',
        value: 100
    },
    format: {
        backgroundColor: '#90EE90',
        fontColor: '#006400'
    }
});
```

이 가이드를 통해 Univer를 단계별로 구현할 수 있습니다. 각 단계를 차근차근 따라가면서 프로젝트에 맞게 수정하여 사용하세요.