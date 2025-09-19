# Univer 샘플 코드 모음집

## 1. 기본 Hello World 예제

### 1.1 최소한의 동작 예제
```html
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Univer Hello World</title>
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/design/lib/index.css" />
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/sheets-ui/lib/index.css" />
    <style>
        #univer-container {
            width: 100%;
            height: 600px;
            border: 1px solid #ccc;
        }
    </style>
</head>
<body>
    <h1>Univer 기본 예제</h1>
    <div id="univer-container"></div>

    <script src="https://unpkg.com/@univerjs/core/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/design/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/engine-render/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/engine-formula/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets-ui/lib/umd/index.js"></script>

    <script>
        // 1. Univer 인스턴스 생성
        const univer = new Univer.Univer({
            theme: Univer.defaultTheme,
            locale: Univer.LocaleType.ZH_CN,
            container: 'univer-container'
        });

        // 2. 플러그인 등록
        univer.registerPlugin(UniverseDesign.UniverDesignPlugin);
        univer.registerPlugin(UniverseEngineRender.UniverRenderEnginePlugin);
        univer.registerPlugin(UniverseEngineFormula.UniverFormulaEnginePlugin);
        univer.registerPlugin(UniverseSheets.UniverSheetsPlugin);
        univer.registerPlugin(UniverseSheetsUi.UniverSheetsUIPlugin);

        // 3. 워크북 생성
        univer.createUniverSheet({
            name: '데모 워크북',
            sheetOrder: ['sheet1'],
            sheets: {
                sheet1: {
                    name: '시트1',
                    cellData: {
                        0: {
                            0: { v: 'Hello' },
                            1: { v: 'Univer!' },
                            2: { v: '안녕하세요' }
                        },
                        1: {
                            0: { v: 'World' },
                            1: { v: '세계' },
                            2: { v: 'Korean' }
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
```

## 2. Excel 파일 로드 예제

### 2.1 파일 업로드 방식
```html
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>Excel 파일 로드</title>
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/design/lib/index.css" />
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/sheets-ui/lib/index.css" />
    <style>
        .upload-area {
            border: 2px dashed #ccc;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            margin-bottom: 20px;
            cursor: pointer;
        }
        .upload-area:hover {
            border-color: #007bff;
            background-color: #f8f9fa;
        }
        #univer-container {
            width: 100%;
            height: 600px;
            border: 1px solid #ddd;
        }
    </style>
</head>
<body>
    <div class="upload-area" onclick="document.getElementById('excel-file').click();">
        <input type="file" id="excel-file" accept=".xlsx,.xls" style="display: none;">
        <p>📁 Excel 파일을 클릭하여 선택하거나 드래그하여 놓으세요</p>
        <p><small>지원 형식: .xlsx, .xls</small></p>
    </div>

    <div id="status"></div>
    <div id="univer-container"></div>

    <script src="https://unpkg.com/@univerjs/core/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/design/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/engine-render/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets-ui/lib/umd/index.js"></script>

    <script>
        let univerInstance = null;

        // Univer 초기화
        function initUniver() {
            univerInstance = new Univer.Univer({
                theme: Univer.defaultTheme,
                locale: Univer.LocaleType.KO_KR,
                container: 'univer-container'
            });

            univerInstance.registerPlugin(UniverseDesign.UniverDesignPlugin);
            univerInstance.registerPlugin(UniverseEngineRender.UniverRenderEnginePlugin);
            univerInstance.registerPlugin(UniverseSheets.UniverSheetsPlugin);
            univerInstance.registerPlugin(UniverseSheetsUi.UniverSheetsUIPlugin);
        }

        // 파일 로드 함수
        async function loadExcelFile(file) {
            const status = document.getElementById('status');
            status.textContent = '📄 Excel 파일을 읽는 중...';

            try {
                // ArrayBuffer로 파일 읽기
                const arrayBuffer = await file.arrayBuffer();

                // 기존 워크북이 있으면 제거
                if (univerInstance.getWorkbook) {
                    const existingWorkbook = univerInstance.getWorkbook();
                    if (existingWorkbook) {
                        univerInstance.disposeUnit(existingWorkbook.getUnitId());
                    }
                }

                // Excel 파일을 Univer로 로드 (실제 API는 다를 수 있음)
                const workbookData = await parseExcelToUniver(arrayBuffer);
                univerInstance.createUniverSheet(workbookData);

                status.innerHTML = `✅ 파일 로드 완료: <strong>${file.name}</strong>`;
            } catch (error) {
                console.error('Excel 파일 로드 실패:', error);
                status.innerHTML = `❌ 파일 로드 실패: ${error.message}`;
            }
        }

        // Excel 파일을 Univer 형식으로 변환 (SheetJS 사용)
        async function parseExcelToUniver(arrayBuffer) {
            // 이 부분은 실제로는 별도의 파서가 필요합니다.
            // 여기서는 개념적인 예제입니다.
            return {
                name: 'Loaded Excel',
                sheetOrder: ['Sheet1'],
                sheets: {
                    Sheet1: {
                        name: 'Sheet1',
                        cellData: {
                            0: {
                                0: { v: 'Loaded' },
                                1: { v: 'from' },
                                2: { v: 'Excel' }
                            }
                        }
                    }
                }
            };
        }

        // 파일 선택 이벤트
        document.getElementById('excel-file').addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file) {
                loadExcelFile(file);
            }
        });

        // 드래그 앤 드롭 지원
        const uploadArea = document.querySelector('.upload-area');

        uploadArea.addEventListener('dragover', function(e) {
            e.preventDefault();
            this.style.backgroundColor = '#e3f2fd';
        });

        uploadArea.addEventListener('dragleave', function(e) {
            e.preventDefault();
            this.style.backgroundColor = '';
        });

        uploadArea.addEventListener('drop', function(e) {
            e.preventDefault();
            this.style.backgroundColor = '';

            const files = e.dataTransfer.files;
            if (files.length > 0) {
                const file = files[0];
                if (file.name.endsWith('.xlsx') || file.name.endsWith('.xls')) {
                    loadExcelFile(file);
                } else {
                    document.getElementById('status').textContent = '❌ Excel 파일만 지원됩니다.';
                }
            }
        });

        // 페이지 로드 시 Univer 초기화
        window.addEventListener('load', initUniver);
    </script>
</body>
</html>
```

## 3. 동적 데이터 조작 예제

### 3.1 실시간 데이터 업데이트
```html
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>실시간 데이터 업데이트</title>
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/design/lib/index.css" />
    <link rel="stylesheet" href="https://unpkg.com/@univerjs/sheets-ui/lib/index.css" />
    <style>
        .controls {
            margin-bottom: 20px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        .controls button {
            margin: 5px;
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        .btn-primary { background: #007bff; color: white; }
        .btn-success { background: #28a745; color: white; }
        .btn-warning { background: #ffc107; color: black; }
        #univer-container { width: 100%; height: 500px; }
    </style>
</head>
<body>
    <div class="controls">
        <h3>📊 실시간 데이터 제어</h3>
        <button class="btn-primary" onclick="addSampleData()">샘플 데이터 추가</button>
        <button class="btn-success" onclick="updateRandomData()">랜덤 데이터 업데이트</button>
        <button class="btn-warning" onclick="applyFormatting()">서식 적용</button>
        <button onclick="clearData()">데이터 초기화</button>
    </div>

    <div id="univer-container"></div>

    <script src="https://unpkg.com/@univerjs/core/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/design/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/engine-render/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/engine-formula/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets/lib/umd/index.js"></script>
    <script src="https://unpkg.com/@univerjs/sheets-ui/lib/umd/index.js"></script>

    <script>
        let univerInstance;
        let currentWorkbook;
        let currentSheet;

        // Univer 초기화
        function initUniver() {
            univerInstance = new Univer.Univer({
                theme: Univer.defaultTheme,
                locale: Univer.LocaleType.KO_KR,
                container: 'univer-container'
            });

            univerInstance.registerPlugin(UniverseDesign.UniverDesignPlugin);
            univerInstance.registerPlugin(UniverseEngineRender.UniverRenderEnginePlugin);
            univerInstance.registerPlugin(UniverseEngineFormula.UniverFormulaEnginePlugin);
            univerInstance.registerPlugin(UniverseSheets.UniverSheetsPlugin);
            univerInstance.registerPlugin(UniverseSheetsUi.UniverSheetsUIPlugin);

            // 초기 워크북 생성
            currentWorkbook = univerInstance.createUniverSheet({
                name: '실시간 데이터 시트',
                sheetOrder: ['데이터시트'],
                sheets: {
                    데이터시트: {
                        name: '데이터시트',
                        cellData: {}
                    }
                }
            });

            currentSheet = currentWorkbook.getSheetByName('데이터시트');
        }

        // 샘플 데이터 추가
        function addSampleData() {
            const sampleData = [
                ['제품명', '가격', '수량', '합계'],
                ['사과', 1500, 10, '=B2*C2'],
                ['바나나', 2000, 8, '=B3*C3'],
                ['오렌지', 1800, 12, '=B4*C4'],
                ['포도', 3000, 5, '=B5*C5'],
                ['총합계', '', '', '=SUM(D2:D5)']
            ];

            // 데이터를 셀에 설정
            for (let row = 0; row < sampleData.length; row++) {
                for (let col = 0; col < sampleData[row].length; col++) {
                    const value = sampleData[row][col];

                    // 수식인지 확인
                    if (typeof value === 'string' && value.startsWith('=')) {
                        currentSheet.getRange(row, col).setFormula(value);
                    } else {
                        currentSheet.getRange(row, col).setValue(value);
                    }
                }
            }

            console.log('✅ 샘플 데이터 추가 완료');
        }

        // 랜덤 데이터 업데이트
        function updateRandomData() {
            const products = ['사과', '바나나', '오렌지', '포도', '키위', '망고'];

            for (let row = 1; row <= 5; row++) {
                const randomProduct = products[Math.floor(Math.random() * products.length)];
                const randomPrice = Math.floor(Math.random() * 3000) + 1000;
                const randomQuantity = Math.floor(Math.random() * 20) + 1;

                currentSheet.getRange(row, 0).setValue(randomProduct);
                currentSheet.getRange(row, 1).setValue(randomPrice);
                currentSheet.getRange(row, 2).setValue(randomQuantity);
                // 수식은 자동으로 다시 계산됨
            }

            console.log('🔄 랜덤 데이터 업데이트 완료');
        }

        // 서식 적용
        function applyFormatting() {
            // 헤더 스타일
            const headerRange = currentSheet.getRange(0, 0, 0, 3); // A1:D1
            headerRange.setStyle({
                bold: true,
                fontSize: 12,
                fontColor: '#ffffff',
                backgroundColor: '#4472C4',
                horizontalAlignment: 'center'
            });

            // 가격 열 통화 형식
            const priceRange = currentSheet.getRange(1, 1, 5, 1); // B2:B6
            priceRange.setNumberFormat('#,##0"원"');

            // 합계 행 스타일
            const totalRange = currentSheet.getRange(5, 0, 5, 3); // A6:D6
            totalRange.setStyle({
                bold: true,
                backgroundColor: '#E7E6E6',
                borderTop: '2px solid #000000'
            });

            console.log('🎨 서식 적용 완료');
        }

        // 데이터 초기화
        function clearData() {
            // 전체 시트 데이터 클리어
            currentSheet.clear();
            console.log('🗑️ 데이터 초기화 완료');
        }

        // 자동 데이터 업데이트 (5초마다)
        let autoUpdateInterval;

        function startAutoUpdate() {
            autoUpdateInterval = setInterval(() => {
                // 수량 열만 랜덤 업데이트
                for (let row = 1; row <= 5; row++) {
                    const currentQuantity = currentSheet.getRange(row, 2).getValue();
                    if (currentQuantity) {
                        const newQuantity = Math.max(1, currentQuantity + (Math.random() > 0.5 ? 1 : -1));
                        currentSheet.getRange(row, 2).setValue(newQuantity);
                    }
                }
            }, 5000);
        }

        function stopAutoUpdate() {
            if (autoUpdateInterval) {
                clearInterval(autoUpdateInterval);
                autoUpdateInterval = null;
            }
        }

        // 이벤트 리스너
        window.addEventListener('load', () => {
            initUniver();

            // 페이지 언로드 시 자동 업데이트 정지
            window.addEventListener('beforeunload', stopAutoUpdate);
        });
    </script>
</body>
</html>
```

## 4. 고급 기능 예제

### 4.1 차트와 그래프
```javascript
// 차트 생성 예제 (차트 플러그인 필요)
function createChart() {
    const sheet = univerInstance.getActiveWorkbook().getActiveSheet();

    // 데이터 범위 선택
    const dataRange = sheet.getRange('A1:D6');

    // 차트 생성
    const chart = sheet.addChart({
        type: 'column', // 세로 막대 차트
        range: dataRange,
        position: {
            row: 7,
            col: 0,
            width: 400,
            height: 300
        },
        options: {
            title: {
                text: '제품별 매출 현황',
                fontSize: 16,
                bold: true
            },
            xAxis: {
                title: '제품명',
                categories: ['사과', '바나나', '오렌지', '포도']
            },
            yAxis: {
                title: '매출액 (원)',
                format: '#,##0"원"'
            },
            legend: {
                position: 'bottom'
            }
        }
    });

    console.log('📊 차트 생성 완료');
    return chart;
}
```

### 4.2 조건부 서식
```javascript
function applyConditionalFormatting() {
    const sheet = univerInstance.getActiveWorkbook().getActiveSheet();

    // 가격 열에 조건부 서식 적용
    const priceRange = sheet.getRange('B2:B6');

    // 2000원 이상은 초록색, 미만은 빨간색
    priceRange.addConditionalFormat({
        condition: {
            type: 'cellValue',
            operator: 'greaterThanOrEqual',
            value: 2000
        },
        format: {
            backgroundColor: '#C6EFCE', // 연한 초록색
            fontColor: '#006100'        // 진한 초록색
        }
    });

    priceRange.addConditionalFormat({
        condition: {
            type: 'cellValue',
            operator: 'lessThan',
            value: 2000
        },
        format: {
            backgroundColor: '#FFC7CE', // 연한 빨간색
            fontColor: '#9C0006'        // 진한 빨간색
        }
    });

    console.log('🎯 조건부 서식 적용 완료');
}
```

## 5. 이벤트 처리 예제

### 5.1 셀 변경 감지
```javascript
function setupEventHandlers() {
    const sheet = univerInstance.getActiveWorkbook().getActiveSheet();

    // 셀 값 변경 이벤트
    sheet.onBeforeEdit((range, value) => {
        console.log(`📝 편집 시작: ${range.getA1Notation()} = ${value}`);

        // 특정 조건에서 편집 차단
        if (range.getRow() === 0) { // 헤더 행 편집 차단
            console.log('❌ 헤더는 편집할 수 없습니다.');
            return false; // 편집 취소
        }

        return true; // 편집 허용
    });

    sheet.onAfterEdit((range, newValue, oldValue) => {
        console.log(`✅ 편집 완료: ${range.getA1Notation()} ${oldValue} → ${newValue}`);

        // 가격이나 수량이 변경되면 합계 자동 계산
        const row = range.getRow();
        const col = range.getColumn();

        if ((col === 1 || col === 2) && row > 0 && row <= 5) { // 가격 또는 수량 열
            const price = sheet.getRange(row, 1).getValue();
            const quantity = sheet.getRange(row, 2).getValue();

            if (price && quantity) {
                const total = price * quantity;
                sheet.getRange(row, 3).setValue(total);
                console.log(`🧮 자동 계산: ${price} × ${quantity} = ${total}`);
            }
        }
    });

    // 셀 선택 변경 이벤트
    sheet.onSelectionChange((range) => {
        const cellInfo = `선택된 셀: ${range.getA1Notation()}`;
        const value = range.getValue();

        console.log(`🎯 ${cellInfo}, 값: ${value}`);

        // 상태 표시 (UI가 있다면)
        const statusElement = document.getElementById('cell-status');
        if (statusElement) {
            statusElement.textContent = `${cellInfo} | 값: ${value || '(빈 셀)'}`;
        }
    });
}
```

## 6. 데이터 유효성 검증

### 6.1 입력 유효성 검사
```javascript
function setupDataValidation() {
    const sheet = univerInstance.getActiveWorkbook().getActiveSheet();

    // 가격 열 유효성 검사 (0보다 큰 숫자만)
    const priceRange = sheet.getRange('B2:B100');
    priceRange.setDataValidation({
        condition: {
            type: 'number',
            operator: 'greaterThan',
            value: 0
        },
        errorMessage: '가격은 0보다 큰 숫자여야 합니다.',
        showErrorAlert: true,
        showInputMessage: true,
        inputMessage: '가격을 입력하세요 (예: 1500)'
    });

    // 수량 열 유효성 검사 (1-100 사이의 정수)
    const quantityRange = sheet.getRange('C2:C100');
    quantityRange.setDataValidation({
        condition: {
            type: 'number',
            operator: 'between',
            min: 1,
            max: 100
        },
        errorMessage: '수량은 1~100 사이의 정수여야 합니다.',
        showErrorAlert: true
    });

    // 제품명 드롭다운 목록
    const productRange = sheet.getRange('A2:A100');
    productRange.setDataValidation({
        condition: {
            type: 'list',
            source: ['사과', '바나나', '오렌지', '포도', '키위', '망고', '딸기']
        },
        showDropdown: true,
        errorMessage: '목록에서 제품을 선택하세요.'
    });

    console.log('✅ 데이터 유효성 검사 설정 완료');
}
```

## 7. 내보내기 및 인쇄

### 7.1 다양한 형식으로 내보내기
```javascript
// Excel 파일로 내보내기
async function exportToExcel() {
    const workbook = univerInstance.getActiveWorkbook();

    try {
        const excelBuffer = await workbook.saveAsExcel({
            format: 'xlsx',
            includeStyles: true,
            includeFormulas: true
        });

        downloadFile(excelBuffer, 'export.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (error) {
        console.error('Excel 내보내기 실패:', error);
    }
}

// CSV 파일로 내보내기
function exportToCSV() {
    const sheet = univerInstance.getActiveWorkbook().getActiveSheet();
    const data = sheet.getUsedRange().getValues();

    const csvContent = data.map(row =>
        row.map(cell => `"${String(cell || '').replace(/"/g, '""')}"`).join(',')
    ).join('\n');

    const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    downloadFile(blob, 'export.csv');
}

// 이미지로 내보내기
async function exportToImage() {
    const sheet = univerInstance.getActiveWorkbook().getActiveSheet();

    try {
        const imageBlob = await sheet.exportAsImage({
            format: 'png',
            quality: 1.0,
            range: 'A1:D10' // 특정 범위만
        });

        downloadFile(imageBlob, 'sheet-export.png', 'image/png');
    } catch (error) {
        console.error('이미지 내보내기 실패:', error);
    }
}

// 파일 다운로드 헬퍼 함수
function downloadFile(data, filename, mimeType = 'application/octet-stream') {
    const blob = data instanceof Blob ? data : new Blob([data], { type: mimeType });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}
```

이 샘플들을 통해 Univer의 다양한 기능을 실제로 구현하고 테스트해볼 수 있습니다. 각 예제는 독립적으로 실행 가능하며, 프로젝트 요구사항에 맞게 조합하여 사용할 수 있습니다.