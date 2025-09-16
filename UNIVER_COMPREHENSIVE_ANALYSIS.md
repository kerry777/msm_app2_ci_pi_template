# Univer 스프레드시트 엔진 포괄적 분석 보고서

## 목차
1. [Univer 기본 개념과 아키텍처](#1-univer-기본-개념과-아키텍처)
2. [Univer 공식 문서 분석](#2-univer-공식-문서-분석)
3. [Univer 패키지 구조](#3-univer-패키지-구조)
4. [Excel 파일 처리 방식](#4-excel-파일-처리-방식)
5. [실제 구현 샘플들](#5-실제-구현-샘플들)
6. [웹 환경에서의 활용](#6-웹-환경에서의-활용)
7. [종합 결론](#종합-결론)

---

## 1. Univer 기본 개념과 아키텍처

### 1.1 핵심 정의
**Univer**는 웹과 서버 환경에서 스프레드시트를 생성하고 편집할 수 있는 풀스택 프레임워크입니다. AI 네이티브 스프레드시트 구축을 목표로 하며, MCP(Model Context Protocol)와의 통합을 통해 자연어로 직접 스프레드시트를 제어할 수 있습니다.

### 1.2 해결하는 문제
- **기존 스프레드시트 솔루션의 한계**: 확장성, 커스터마이징, 성능 문제 해결
- **협업 기능**: 실시간 다중 사용자 편집 지원
- **크로스 플랫폼**: 브라우저와 Node.js 환경 모두 지원
- **대용량 데이터**: 수천만 개 셀과 200만 개 이상의 공식 처리 가능

### 1.3 핵심 아키텍처 설계 원칙

#### 플러그인 기반 모듈 아키텍처
- **모듈성**: 100개 이상의 플러그인을 레고 블록처럼 조합
- **컴포저블**: 필요한 플러그인만 선택적으로 로드
- **커스터마이징**: 핵심 코드 변경 없이 자체 플러그인 개발 가능

#### 고성능 렌더링 엔진
- **Canvas 기반**: 자체 개발한 Canvas 렌더링 엔진
- **Web Worker 지원**: 공식 계산을 별도 워커에서 처리
- **메모리 최적화**: 대용량 데이터 효율적 처리

### 1.4 다른 스프레드시트 라이브러리와의 차이점
| 특징 | Univer | Luckysheet | SheetJS | Syncfusion |
|------|--------|------------|---------|------------|
| **아키텍처** | 플러그인 기반 모듈형 | 모노리틱 | 데이터 처리 전용 | 상용 컴포넌트 |
| **성능** | Canvas + Web Worker | Canvas | DOM 기반 | DOM/Canvas 혼합 |
| **확장성** | 100+ 플러그인 | 제한적 | 없음 | 상용 라이센스 |
| **AI 통합** | MCP 자연어 제어 | 없음 | 없음 | 없음 |
| **라이센스** | Apache 2.0 | MIT | Apache 2.0 | 상용 |

---

## 2. Univer 공식 문서 분석

### 2.1 주요 문서 구조
- **공식 사이트**: https://univer.ai/
- **개발자 문서**: https://docs.univer.ai/guides/sheets
- **API 레퍼런스**: TypeDoc 기반 API 문서 제공
- **GitHub**: https://github.com/dream-num/univer

### 2.2 Getting Started 가이드 핵심 내용

#### 빠른 시작 옵션
1. **온라인 플레이그라운드**: 설치 없이 바로 사용 가능
2. **스타터 킷**: 수초 만에 새 Univer 앱 생성
```bash
npx degit dream-num/univer-sheet-start-kit my-app
cd my-app
npm install
npm run dev
```

#### 설치 방법
```bash
npm install @univerjs/core @univerjs/design @univerjs/docs @univerjs/docs-ui @univerjs/engine-formula @univerjs/engine-render @univerjs/sheets @univerjs/sheets-formula @univerjs/sheets-formula-ui @univerjs/sheets-numfmt @univerjs/sheets-numfmt-ui @univerjs/sheets-ui @univerjs/ui
```

### 2.3 API 레퍼런스 핵심 부분
- **Facade API**: 애플리케이션 진입점 및 핵심 기능 접근
- **IWorksheetData 인터페이스**: 워크시트 데이터 구조 정의
- **플러그인 API**: 사용자 정의 플러그인 개발 인터페이스

---

## 3. Univer 패키지 구조

### 3.1 핵심 패키지별 역할

#### @univerjs/core
- **역할**: Univer의 기초 패키지
- **기능**:
  - Univer 타입 제공 (애플리케이션 진입점)
  - UniverDoc, UniverSheet 타입 관리
  - 다른 플러그인들의 마운트 포인트 역할

#### @univerjs/sheets
- **역할**: 스프레드시트 핵심 기능
- **기능**:
  - 수치 포맷팅
  - 선택 영역 관리
  - 권한 관리
  - 기본 셀 연산

#### @univerjs/sheets-ui
- **역할**: 스프레드시트 사용자 인터페이스
- **기능**:
  - 키보드 단축키 및 메뉴 아이템
  - 복사-붙여넣기 서비스
  - 자동 채우기 서비스
  - 셀 에디터 및 공식 에디터
  - Canvas에서 스프레드시트 렌더링

### 3.2 패키지 간 의존성과 관계
```
@univerjs/core (기반)
├── @univerjs/design (디자인 시스템)
├── @univerjs/engine-render (렌더링 엔진)
├── @univerjs/engine-formula (공식 엔진)
├── @univerjs/sheets (스프레드시트 로직)
│   ├── @univerjs/sheets-ui (UI 컴포넌트)
│   ├── @univerjs/sheets-formula (공식 UI)
│   └── @univerjs/sheets-numfmt (숫자 포맷)
└── @univerjs/ui (공통 UI)
```

### 3.3 최소 필수 패키지 vs 선택적 패키지

#### 최소 필수 패키지
```json
{
  "@univerjs/core": "^0.10.6",
  "@univerjs/design": "^0.10.6",
  "@univerjs/engine-render": "^0.10.6",
  "@univerjs/sheets": "^0.10.6",
  "@univerjs/sheets-ui": "^0.10.6",
  "@univerjs/ui": "^0.10.6"
}
```

#### 선택적 패키지
- `@univerjs/engine-formula`: 공식 계산 기능
- `@univerjs/sheets-formula`: 공식 UI
- `@univerjs/sheets-numfmt`: 숫자 포맷팅
- `@univerjs/docs`: 문서 편집 기능

---

## 4. Excel 파일 처리 방식

### 4.1 Excel 파일 로드 및 렌더링

#### 기본 로드 프로세스
```javascript
// Excel 파일 동적 로드 예제
async function fetchExcelFile(url) {
  const response = await fetch(url);
  const blob = await response.blob();
  return new File([blob], 'filename.xlsx', {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  });
}

// Univer로 임포트
const file = await fetchExcelFile(url);
univerAPI.importXLSXToSnapshot(file).then(snapshot => {
  console.log('Snapshot created:', snapshot);
});
```

### 4.2 복잡한 요소들 처리 방식

#### 셀 병합 (Cell Merging)
- **지원 기능**: 인접한 셀들을 하나로 병합
- **API**: `worksheet.MergeCells()` 또는 `range.Merge()` 메서드
- **옵션**: MergeCellsMode 파라미터로 병합 방식 제어

#### 서식 (Formatting)
- **지원 범위**: 폰트, 색상, 정렬, 테두리 등 모든 기본 서식
- **구현**: `@univerjs/sheets-numfmt` 패키지를 통한 숫자 포맷팅
- **확장성**: 커스텀 포맷 규칙 추가 가능

#### 차트 지원
- **플러그인 기반**: 차트 플러그인을 통한 확장
- **렌더링**: Canvas 기반 고성능 차트 렌더링
- **상호작용**: 실시간 데이터 업데이트 지원

### 4.3 원본 Excel 레이아웃 유지 메커니즘
- **XLSX 파서**: 오픈소스 XLSX 파싱 라이브러리 활용
- **IWorksheetData 변환**: Excel 구조를 Univer 데이터 구조로 변환
- **포맷 보존**: 원본 스타일과 레이아웃 정보 유지
- **공식 유지**: 원본 공식과 참조 관계 보존

---

## 5. 실제 구현 샘플들

### 5.1 공식 GitHub 저장소 예제

#### 주요 예제 저장소
1. **dream-num/univer-examples**: 기본 데모 모음
2. **dream-num/univer-cross-framework-examples**: React, Vue, Angular 프레임워크별 예제
3. **dream-num/univer-presets**: 즉시 사용 가능한 프리셋 모음
4. **dream-num/univer-event-sync-example-go**: 이벤트 동기화 예제

#### 기본 초기화 예제
```typescript
// main.ts 예제
import { Univer } from '@univerjs/core';
import { defaultTheme } from '@univerjs/design';
import { UniverSheetsPlugin } from '@univerjs/sheets';
import { UniverSheetsUIPlugin } from '@univerjs/sheets-ui';
import { UniverUIPlugin } from '@univerjs/ui';

// Univer 인스턴스 생성
const univer = new Univer({
  theme: defaultTheme,
});

// 플러그인 등록
univer.registerPlugin(UniverUIPlugin, {
  container: 'app',
});
univer.registerPlugin(UniverSheetsPlugin);
univer.registerPlugin(UniverSheetsUIPlugin);

// 워크북 생성
const workbook = univer.createUnit(UniverInstanceType.UNIVER_SHEET, {
  sheetOrder: ['sheet1'],
  name: 'MyWorkbook',
  sheets: {
    sheet1: {
      id: 'sheet1',
      name: 'Sheet1',
      cellData: {
        0: {
          0: { v: 'Hello' },
          1: { v: 'World' }
        }
      }
    }
  }
});
```

### 5.2 커뮤니티 구현 사례
- **Obsidian 플러그인**: markdown 환경에서 Excel/Word 문서 편집
- **Next.js 통합**: `sheets-nextjs-demo` 예제를 통한 React 앱 통합
- **CSV 임포트 플러그인**: 사용자 정의 파일 임포트 기능

### 5.3 다양한 사용 시나리오별 구현 패턴

#### 시나리오 1: 기본 스프레드시트 뷰어
```javascript
// 읽기 전용 뷰어 설정
const univer = new Univer({
  theme: defaultTheme,
});
// UI 플러그인만 최소한으로 로드
```

#### 시나리오 2: 풀 기능 에디터
```javascript
// 모든 기능 포함 에디터
univer.registerPlugin(UniverSheetsFormulaPlugin);
univer.registerPlugin(UniverSheetsNumfmtPlugin);
// 공식, 차트, 고급 포맷팅 모두 활성화
```

#### 시나리오 3: 협업 환경
```javascript
// 이벤트 동기화 플러그인 추가
// RabbitMQ 또는 WebSocket을 통한 실시간 동기화
```

---

## 6. 웹 환경에서의 활용

### 6.1 HTML에서 Univer 초기화 방법

#### CDN을 통한 빠른 시작
```html
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@univerjs/ui/lib/index.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@univerjs/sheets-ui/lib/index.css">
</head>
<body>
  <div id="app"></div>
  <script src="https://cdn.jsdelivr.net/npm/@univerjs/umd/lib/univer.full.umd.js"></script>
  <script>
    // UMD 빌드를 통한 접근
    const { Univer } = window;
    // 초기화 코드
  </script>
</body>
</html>
```

#### 모던 번들러를 통한 설정
```javascript
import { Univer } from '@univerjs/core';
import '@univerjs/design/lib/index.css';
import '@univerjs/ui/lib/index.css';
import '@univerjs/sheets-ui/lib/index.css';

const univer = new Univer({
  theme: defaultTheme,
  locale: LocaleType.EN_US,
});
```

### 6.2 Excel 파일을 동적으로 로드하는 방법

#### Fetch API를 통한 파일 로드
```javascript
async function loadExcelFromUrl(url) {
  try {
    const response = await fetch(url);
    const blob = await response.blob();
    const file = new File([blob], 'spreadsheet.xlsx', {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    });

    // Univer로 임포트
    const snapshot = await univerAPI.importXLSXToSnapshot(file);
    return snapshot;
  } catch (error) {
    console.error('Excel 로드 실패:', error);
  }
}

// 사용 예제
loadExcelFromUrl('/path/to/spreadsheet.xlsx')
  .then(snapshot => {
    console.log('Excel 파일 로드 완료:', snapshot);
  });
```

#### 파일 업로드를 통한 동적 로드
```javascript
function handleFileUpload(event) {
  const file = event.target.files[0];
  if (file && file.type.includes('spreadsheet')) {
    univerAPI.importXLSXToUnitId(file)
      .then(unitId => {
        console.log('새 워크북 생성:', unitId);
      });
  }
}

// HTML
// <input type="file" accept=".xlsx,.xls" onchange="handleFileUpload(event)">
```

### 6.3 사용자 인터랙션 처리 방법

#### 이벤트 리스너 설정
```javascript
// 셀 선택 이벤트
univer.getPlugin(UniverSheetsPlugin).getWorkbook('workbook-id')
  .getActiveSheet().onCellClick.subscribe((cell) => {
    console.log('셀 클릭:', cell);
  });

// 데이터 변경 이벤트
univer.getPlugin(UniverSheetsPlugin)
  .onCellDataChange.subscribe((changes) => {
    console.log('데이터 변경:', changes);
  });
```

#### 커스텀 메뉴 및 툴바 추가
```javascript
// 커스텀 메뉴 아이템 추가
const customMenuItem = {
  id: 'custom-function',
  title: '사용자 정의 기능',
  icon: 'CustomIcon',
  onClick: () => {
    // 사용자 정의 로직
  }
};

univerAPI.addMenuItem(customMenuItem);
```

---

## 종합 결론

**Univer**는 현대적인 웹 환경에서 Excel과 유사한 스프레드시트 기능을 제공하는 강력하고 확장 가능한 프레임워크입니다.

### 주요 강점
1. **모듈형 아키텍처**: 플러그인 시스템을 통한 높은 확장성
2. **고성능**: Canvas 렌더링과 Web Worker를 활용한 최적화
3. **크로스 플랫폼**: 브라우저와 Node.js 모두 지원
4. **Excel 호환성**: 원본 Excel 파일의 레이아웃과 기능 보존
5. **AI 통합**: MCP를 통한 자연어 제어 지원

### 적용 추천 시나리오
- **대용량 데이터 처리**: 수천만 개 셀 처리가 필요한 경우
- **커스터마이징**: 특별한 요구사항에 맞는 스프레드시트 기능 필요시
- **협업 환경**: 실시간 다중 사용자 편집 기능 필요시
- **웹 애플리케이션 통합**: 기존 웹 앱에 스프레드시트 기능 추가시

### 우리 프로젝트 적용 가능성
- ✅ **Excel 원본 레이아웃 유지**: SheetJS 한계 극복
- ✅ **고성능 렌더링**: Canvas 기반으로 프로펠러 문제 해결
- ✅ **Flutter 웹뷰 통합**: 웹 환경에서 동작하므로 웹뷰 연동 가능
- ✅ **확장성**: 플러그인 시스템으로 필요 기능만 선택적 사용

---

*2025년 9월 16일 작성*
*Context7 및 웹 검색을 통한 종합 분석 결과*