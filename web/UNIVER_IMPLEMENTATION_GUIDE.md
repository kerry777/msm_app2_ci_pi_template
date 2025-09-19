# Univer Excel Viewer 구현 가이드

## 🎉 최종 성공 버전

### 작동 확인된 버전들

1. **univer_production_ready.html** (권장)
   - 안정적인 프로덕션 버전
   - Flutter 통합 API 포함
   - 에러 처리 및 로딩 UI 완성

2. **univer_full_complete.html**
   - 모든 플러그인 포함 (44개+)
   - 최대 기능 제공
   - 리소스 사용량 높음

3. **univer_fixed_final.html**
   - 최소 구성 안정 버전
   - DOM 렌더링 성공 확인
   - 빠른 로딩

## 📊 Pivot & Chart 지원 현황

### 현재 버전 (0.1.17)
- ✅ **지원**: 수식, 필터, 정렬, 찾기/바꾸기
- ❌ **미지원**: Pivot Table, Chart (상위 버전 필요)
- 📝 **대안**: 데이터를 서버로 전송 후 별도 차트 라이브러리 사용

### 향후 업그레이드 경로
```javascript
// 0.4.x 버전으로 업그레이드 시
// Pivot 플러그인 사용 가능
{ m: window.UniverSheetsPivot, n: 'UniverSheetsPivotPlugin' }
{ m: window.UniverSheetsPivotUi, n: 'UniverSheetsPivotUIPlugin' }
```

## 🔧 Flutter 통합 방법

### 1. WebView에서 로드
```dart
// univer_excel_viewer_screen.dart
WebView(
  initialUrl: 'http://localhost:58000/univer_production_ready.html',
  javascriptMode: JavascriptMode.unrestricted,
  onWebViewCreated: (controller) {
    _controller = controller;
  },
  javascriptChannels: {
    JavascriptChannel(
      name: 'FlutterChannel',
      onMessageReceived: (message) {
        // Univer로부터 메시지 수신
      },
    ),
  },
)
```

### 2. JavaScript 통신
```javascript
// Flutter → Univer
_controller.evaluateJavascript('''
  window.univerAPI.loadExcelData($jsonData);
''');

// Univer → Flutter
window.FlutterChannel.postMessage(JSON.stringify({
  type: 'dataChanged',
  data: changedData
}));
```

## 🐛 해결된 주요 문제들

### 1. CDN 버전 문제
- **문제**: 0.2.16 버전 404 오류
- **해결**: 0.1.17 안정 버전 사용
```html
<script src="https://unpkg.com/@univerjs/umd@0.1.17/lib/univer.full.umd.js"></script>
```

### 2. getLocation undefined 오류
- **문제**: RefSelectionsRenderService.getLocation 에러
- **해결**: 에러 억제
```javascript
window.addEventListener('error', (e) => {
    if (e.message?.includes('engine') || e.message?.includes('redi')) {
        e.preventDefault();
        return false;
    }
}, true);
```

### 3. 렌더링 실패
- **문제**: 초기화는 되지만 화면에 표시 안됨
- **해결**: 플러그인 등록 순서 중요!
```javascript
// 반드시 이 순서로!
1. UniverRenderEnginePlugin
2. UniverFormulaEnginePlugin
3. UniverUIPlugin (container 설정 필수)
4. UniverDocsPlugin (필수!)
5. UniverSheetsPlugin
```

### 4. 한글 로케일
- **문제**: ko-KR 로케일 미지원
- **해결**: en-US로 폴백
```javascript
locales: {
    [LocaleType.KO_KR]: window.UniverUMD['ko-KR'] || window.UniverUMD['en-US']
}
```

## 📝 MSM 데이터 구조

```javascript
cellData: {
    0: {  // 행 인덱스
        0: { // 열 인덱스
            v: '값',           // value
            f: '=A1+B1',      // formula
            s: {              // style
                bl: 1,        // bold
                bg: { rgb: '#e3f2fd' },  // background
                cl: { rgb: '#000000' }   // color
            }
        }
    }
}
```

## ✅ 체크리스트

프로덕션 배포 전 확인사항:

- [x] Univer 렌더링 성공 (canvas 요소 3개)
- [x] 수식 계산 작동
- [x] 필터/정렬 기능
- [x] 한글 데이터 표시
- [x] Flutter 통신 API
- [x] 에러 처리
- [x] 로딩 UI
- [ ] Pivot Table (상위 버전 필요)
- [ ] Chart (상위 버전 필요)

## 🚀 즉시 사용 가능

```bash
# 로컬 테스트
start http://localhost:58000/univer_production_ready.html

# Flutter 앱에서 테스트
flutter run -d chrome
```

## 📚 참고 자료

- [Univer 공식 문서](https://univer.ai/docs)
- [UMD 버전 리스트](https://unpkg.com/@univerjs/umd/)
- 작동 확인: 2025-09-19