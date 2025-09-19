# Univer + Flutter WebView 통합 상세 가이드

## ChatGPT 대화에서 얻은 핵심 정보

### 1. Univer의 핵심 능력 확인

#### ✅ 원본 Excel 스타일 완벽 유지
- **폰트, 색상, 배경, 테두리, 병합 셀** 모두 그대로 로드
- **견적서 같은 양식**: 제목 크게 굵게, 셀 병합 포함 → **완벽 지원**
- **숫자 서식**: 통화, 날짜, 소수점 자릿수 등 유지
- **행/열 높이·너비**: 기본 레이아웃 그대로 반영

#### ✅ 수식 처리 엔진 내장
- **기본 함수**: SUM(), SUBTOTAL(), SUMIF(), SUMIFS()
- **통계 함수**: AVERAGE, COUNT, MAX, MIN
- **논리 함수**: IF, AND, OR
- **텍스트 함수**: CONCAT, LEFT, RIGHT
- **여러 시트 참조**: Sheet2!A1 형태도 지원
- **견적서 합계/소계**: 모든 계산 함수 정상 동작

#### ✅ 편집 및 내보내기
- **실시간 편집**: 셀 편집, 수식 계산, 행/열 추가/삭제
- **서식 변경**: 스타일 수정 가능
- **협업 기능**: 여러 사용자 동시 편집 지원
- **Excel 내보내기**: 수정된 내용을 .xlsx로 저장
- **PDF 내보내기**: 인쇄 미리보기 + PDF 저장

#### ⚠️ 제한사항
- **VBA 매크로**: 완벽 지원 안됨
- **고급 차트**: 제한적 지원
- **피벗 테이블**: 현재 제한적
- **Excel 애드인 함수**: 로딩 안됨

### 2. Flutter 통합 아키텍처

```
Flutter App → WebView → HTML Page → Univer Engine → Excel File
```

#### 구조 설명
1. **Flutter**: 메인 앱 UI, 버튼 이벤트 처리
2. **WebView**: JavaScript 브릿지 역할
3. **HTML + Univer**: 실제 스프레드시트 렌더링
4. **메시지 브릿지**: Flutter ↔ JavaScript 통신

### 3. 실제 구현 코드

#### 3.1 Flutter 측 구현

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class UniverViewerPage extends StatefulWidget {
  const UniverViewerPage({super.key});

  @override
  State<UniverViewerPage> createState() => _UniverViewerPageState();
}

class _UniverViewerPageState extends State<UniverViewerPage> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Univer 견적서 편집'),
        actions: [
          IconButton(
            tooltip: 'PDF로 내보내기',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _ready ? () async {
              await _controller.runJavaScriptReturningResult("""
                window.postMessage({ action: 'exportPDF' }, '');
                true;
              """);
            } : null,
          ),
        ],
      ),
      body: WebViewWidget(controller: _buildController()),
      floatingActionButton: FloatingActionButton(
        tooltip: '샘플 견적서 로드',
        onPressed: _ready ? () async {
          await _controller.runJavaScriptReturningResult("""
            window.postMessage({
              action: 'loadExcelAsset',
              data: { path: 'assets/templates/견적서_샘플.xlsx' }
            }, '');
            true;
          """);
        } : null,
        child: const Icon(Icons.file_open),
      ),
    );
  }

  WebViewController _buildController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) {
          // WebView -> Flutter 콜백
          debugPrint('[WebView] ${msg.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            setState(() => _ready = true);
          },
        ),
      )
      ..loadFlutterAsset('assets/univer/index.html');
    return _controller;
  }
}
```

#### 3.2 HTML + JavaScript 구현

```html
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Univer in Flutter</title>
  <style>
    html, body, #univer-container {
      height: 100%;
      margin: 0;
    }
  </style>

  <!-- Univer UMD bundles via CDN -->
  <script src="https://unpkg.com/@univerjs/core@latest/dist/umd/index.js"></script>
  <script src="https://unpkg.com/@univerjs/engine-render@latest/dist/umd/index.js"></script>
  <script src="https://unpkg.com/@univerjs/sheets@latest/dist/umd/index.js"></script>
  <script src="https://unpkg.com/@univerjs/sheets-ui@latest/dist/umd/index.js"></script>
  <script src="https://unpkg.com/@univerjs/sheets-formula@latest/dist/umd/index.js"></script>
  <script src="https://unpkg.com/@univerjs/xlsx@latest/dist/umd/index.js"></script>
</head>
<body>
  <div id="univer-container"></div>

  <script>
    // Create Univer instance & register plugins
    const univer = new UniverCore.Univer();

    univer.registerPlugin(UniverEngineRender.UniverEngineRenderPlugin, {
      container: 'univer-container',
    });
    univer.registerPlugin(UniverSheets.UniverSheetsPlugin);
    univer.registerPlugin(UniverSheetsUI.UniverSheetsUIPlugin);
    univer.registerPlugin(UniverFormula.UniverFormulaPlugin);
    univer.registerPlugin(UniverXLSX.UniverXLSXPlugin);

    // 새 빈 워크북 생성 (초기화)
    const workbook = univer.createUniverSheet();

    async function loadExcelFromArrayBuffer(buffer) {
      // XLSX 플러그인으로 버퍼 로드
      const xlsx = univer.getPluginByName('UniverXLSXPlugin') || univer.getPluginByName('xlsx');
      if (!xlsx || !xlsx.open) {
        console.warn('XLSX plugin not found or open() missing');
        alert('XLSX 플러그인 로드 실패. 버전을 고정해 주세요.');
        return;
      }
      try {
        await xlsx.open(buffer);
      } catch (e) {
        console.error(e);
        alert('엑셀 로드 중 오류: ' + e);
      }
    }

    // Flutter -> WebView 메시지 브리지
    window.addEventListener('message', async (event) => {
      const { action, data } = event.data || {};

      if (action === 'exportPDF') {
        window.print();
        return;
      }

      if (action === 'loadExcelAsset' && data && data.path) {
        try {
          const resp = await fetch(data.path);
          const buf = await resp.arrayBuffer();
          await loadExcelFromArrayBuffer(buf);

          if (window.FlutterChannel) {
            FlutterChannel.postMessage('loaded:' + data.path);
          }
        } catch (e) {
          if (window.FlutterChannel) {
            FlutterChannel.postMessage('error:' + e);
          }
        }
      }
    });
  </script>
</body>
</html>
```

### 4. pubspec.yaml 설정

```yaml
dependencies:
  flutter:
    sdk: flutter
  webview_flutter: ^4.7.0  # 또는 최신 4.x

flutter:
  assets:
    - assets/univer/index.html
    - assets/templates/견적서_샘플.xlsx
```

### 5. 샘플 Excel 파일 구조

ChatGPT가 제공한 샘플 견적서는 다음 요소들을 포함:

- **병합된 제목 셀** (A1:E2): "견적서 (Quotation)"
- **헤더 행**: 품번, 품명, 수량, 단가, 금액
- **데이터 행들**: 실제 제품 정보
- **수식이 포함된 금액 계산**: `=C4*D4` (수량 × 단가)
- **소계 계산**: `=SUBTOTAL(9,E4:E6)`
- **부가세 계산**: `=E7*0.1` (소계의 10%)
- **총합계**: `=E7+E8` (소계 + 부가세)

### 6. 핵심 기능 정리

#### ✅ 지원되는 기능
1. **스타일 완벽 유지**: 폰트, 색상, 병합셀, 테두리
2. **수식 자동 계산**: SUM, SUBTOTAL, IF 등 기본 함수
3. **실시간 편집**: 셀 값 변경 시 수식 자동 재계산
4. **인쇄 미리보기**: `window.print()` 호출
5. **PDF 내보내기**: 브라우저 기본 인쇄 → PDF
6. **Excel 저장**: 편집된 내용을 .xlsx로 내보내기

#### ⚠️ 주의사항
1. **CDN 버전 고정**: @latest 대신 특정 버전 사용 권장
2. **네트워크 의존성**: CDN 접근 불가 시 로딩 실패
3. **VBA 매크로**: 지원되지 않음
4. **고급 Excel 기능**: 피벗 테이블, 고급 차트 제한적

### 7. 버전 고정 방법 (문제 발생 시)

```html
<!-- 버전 고정 예시 -->
<script src="https://unpkg.com/@univerjs/core@0.2.11/dist/umd/index.js"></script>
<script src="https://unpkg.com/@univerjs/engine-render@0.2.11/dist/umd/index.js"></script>
<script src="https://unpkg.com/@univerjs/sheets@0.2.11/dist/umd/index.js"></script>
<script src="https://unpkg.com/@univerjs/sheets-ui@0.2.11/dist/umd/index.js"></script>
<script src="https://unpkg.com/@univerjs/sheets-formula@0.2.11/dist/umd/index.js"></script>
<script src="https://unpkg.com/@univerjs/xlsx@0.2.11/dist/umd/index.js"></script>
```

### 8. 실제 사용 시나리오

1. **Flutter 앱에서 견적서 버튼 클릭**
2. **UniverViewerPage 열기**
3. **FAB 클릭하여 Excel 템플릿 로드**
4. **Univer에서 스타일/수식 유지된 상태로 표시**
5. **웹에서 직접 편집 (수량, 단가 등)**
6. **수식 자동 재계산 (합계, 소계 등)**
7. **PDF 버튼으로 인쇄 미리보기/PDF 저장**

이 방식으로 구현하면 기존의 Excel 템플릿을 그대로 활용하면서 웹/앱에서 편집이 가능한 견적서 시스템을 만들 수 있습니다.

## 결론

ChatGPT 대화에서 확인된 가장 중요한 점:

1. **Univer는 단순 뷰어가 아니라 완전한 스프레드시트 엔진**
2. **원본 Excel 스타일과 수식을 거의 완벽하게 유지**
3. **Flutter WebView 통합이 실제로 가능하고 구체적인 구현 방법 제공**
4. **견적서 같은 양식 문서에 최적화된 솔루션**

이제 실제 구현에 필요한 모든 정보가 확보되었습니다! 🚀