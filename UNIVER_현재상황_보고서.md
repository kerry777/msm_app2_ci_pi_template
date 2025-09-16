# Univer Excel 뷰어 현재 상황 보고서

## 📋 프로젝트 개요

Flutter 웹 애플리케이션에서 **Univer 라이브러리만 사용**하여 Excel 뷰어를 구현하는 프로젝트입니다.

## 🚨 현재 핵심 문제

### 주요 오류: "ReferenceError: UniverCore is not defined"

**발생 위치**: `assets/univer/index.html:87`
```javascript
const { LocaleType } = window.UniverCore;
```

**오류 원인**: Univer CDN 스크립트가 제대로 로드되지 않아 전역 객체가 생성되지 않음

## 🔍 시도한 해결 방법들

### 1. 공식 문서 기반 CDN 구성 (현재 적용)
**출처**: https://docs.univer.ai/guides/sheets/getting-started/installation/cdn

```html
<!-- 현재 적용된 CDN 스크립트들 -->
<script src="https://unpkg.com/react@18.3.1/umd/react.production.min.js"></script>
<script src="https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js"></script>
<script src="https://unpkg.com/rxjs/dist/bundles/rxjs.umd.min.js"></script>
<script src="https://unpkg.com/echarts@5.6.0/dist/echarts.min.js"></script>
<script src="https://unpkg.com/@univerjs/presets/lib/umd/index.js"></script>
<script src="https://unpkg.com/@univerjs/preset-sheets-core/lib/umd/index.js"></script>
<script src="https://unpkg.com/@univerjs/preset-sheets-core/lib/umd/locales/en-US.js"></script>
```

### 2. 초기화 코드 (공식 문서 기반)
```javascript
const { createUniver } = window.UniverPresets;
const { LocaleType } = window.UniverCore;
const { UniverSheetsCorePreset } = window.UniverPresetSheetsCore;

const { univerAPI } = createUniver({
    container: 'univer-container',
    locale: LocaleType.EN_US,
    presets: [UniverSheetsCorePreset()],
});
```

### 3. 이전 시도된 방법들
- `@univerjs/umd@0.1.16` 특정 버전 사용
- UMD 번들 방식 시도
- 플러그인 방식 초기화 시도
- 스크립트 로딩 순서 조정

## 📁 프로젝트 파일 구조

```
C:\projects\msm_app\msm_app1\client\
├── assets/univer/index.html          # 메인 Excel 뷰어 (1,946줄)
├── lib/main_univer_test.dart          # Flutter 테스트 앱 진입점
├── lib/screens/simple_univer_test_screen.dart  # WebView 통합 화면
├── web/univer_test.html               # CDN 테스트 파일
├── UNIVER_EXCEL_VIEWER_COMPLETE.md   # 프로젝트 완료 문서
└── assets/excel_templates/            # 테스트용 Excel 파일들
    ├── quotation_kr.xlsx
    ├── pi_template.xlsx
    ├── commercial_invoice.xlsx
    └── packing_list.xlsx
```

## 🔧 기술 스펙

### Flutter 측
- **WebView**: `dart:html` + `ui_web` 패키지
- **통신**: JavaScript ↔ Flutter 메시지 브리지
- **라우팅**: HtmlElementView를 통한 iframe 임베딩

### Univer 측 (목표)
- **라이브러리**: Univer Preset Sheets Core
- **기능**: Excel 파일 로딩, 편집, 내보내기
- **API**: createUniver, createWorkbook, exportWorkbook

## 🎯 구현 요구사항

### 핵심 제약사항
1. **Univer 라이브러리만 사용** (SheetJS, ExcelJS, Syncfusion 금지)
2. **실제 Excel 파일 로딩** (하드코딩 샘플 아님)
3. **원본 스타일 보존** 필수
4. **편집 기능** 포함

### 기능 목표
- ✅ 실제 .xlsx 파일 로딩
- ✅ 수식 보존 및 계산
- ✅ 스타일 및 서식 유지
- ✅ 실시간 셀 편집
- ✅ Excel/CSV 내보내기

## 📊 현재 상태

### 작동하는 부분
- ✅ Flutter WebView 통합
- ✅ JavaScript ↔ Flutter 통신 브리지
- ✅ 파일 경로 감지 및 로딩 로직
- ✅ UI 툴바 및 인터페이스

### 작동하지 않는 부분
- ❌ Univer CDN 라이브러리 로딩
- ❌ UniverCore 전역 객체 생성
- ❌ Univer 초기화 및 인스턴스 생성
- ❌ Excel 파일 실제 로딩

## 🔍 디버깅 정보

### 브라우저 콘솔 로그
```
🚀 Univer Excel 뷰어 시작...
window.UniverPresets: object
window.UniverCore: undefined     ← 핵심 문제
window.UniverPresetSheetsCore: object
❌ Univer 초기화 실패: UniverCore is not defined
```

### 분석
- `UniverPresets`와 `UniverPresetSheetsCore`는 로드됨
- `UniverCore`만 undefined 상태
- CDN 스크립트 로딩 순서나 의존성 문제로 추정

## 📝 다음 단계 권장사항

### 1. CDN 스크립트 검증
- unpkg.com에서 실제 파일 존재 확인
- 네트워크 탭에서 스크립트 로딩 상태 확인
- 각 스크립트의 의존성 관계 분석

### 2. 대안 CDN 소스 시도
- jsdelivr.net 사용
- 특정 버전 명시 (최신 stable)
- 로컬 파일 다운로드 후 테스트

### 3. 커뮤니티 리소스 활용
- Univer GitHub: dream-num/univer
- Univer 공식 예제: dream-num/univer-examples
- Luckysheet 커뮤니티 (관련 라이브러리)

## 📧 추가 조사 필요 영역

1. **Univer Preset vs Plugin 모드 차이점**
2. **CDN UMD 번들의 정확한 전역 객체 구조**
3. **React/ReactDOM 의존성 요구사항**
4. **브라우저 호환성 이슈**

---

**생성일**: 2025-01-17
**상태**: CDN 로딩 문제로 중단
**다음 액션**: GPT 상담 및 커뮤니티 리소스 활용