# Univer 최적 실습 가이드 (Best Practices)

## 1. 아키텍처 설계 원칙

### 1.1 플러그인 로드 순서
```javascript
// ✅ 올바른 플러그인 로드 순서
const PLUGIN_LOAD_ORDER = [
    // 1단계: 핵심 엔진
    UniverseDesign.UniverDesignPlugin,
    UniverseEngineRender.UniverRenderEnginePlugin,

    // 2단계: 계산 엔진 (옵션)
    UniverseEngineFormula.UniverFormulaEnginePlugin,

    // 3단계: 시트 기능
    UniverseSheets.UniverSheetsPlugin,
    UniverseSheetsUi.UniverSheetsUIPlugin,

    // 4단계: 고급 기능 (순서대로)
    UniverseSheetsFormula.UniverSheetsFormulaPlugin,
    // UniverseSheetsChart.UniverSheetsChartPlugin, // 차트 기능
    // UniverseSheetsPivot.UniverSheetsPivotPlugin,  // 피벗 테이블
];

// 순차적으로 등록
PLUGIN_LOAD_ORDER.forEach(plugin => {
    univerInstance.registerPlugin(plugin);
});
```

### 1.2 인스턴스 생명주기 관리
```javascript
class UniverManager {
    constructor() {
        this.instance = null;
        this.workbooks = new Map();
        this.isInitialized = false;
    }

    async initialize(containerId, options = {}) {
        if (this.isInitialized) {
            console.warn('Univer is already initialized');
            return this.instance;
        }

        try {
            this.instance = new Univer.Univer({
                theme: options.theme || Univer.defaultTheme,
                locale: options.locale || Univer.LocaleType.KO_KR,
                container: containerId,
                logLevel: options.logLevel || Univer.LogLevel.WARN,
                ...options
            });

            // 플러그인 등록
            this.registerPlugins();
            this.isInitialized = true;

            console.log('✅ Univer 초기화 완료');
            return this.instance;
        } catch (error) {
            console.error('❌ Univer 초기화 실패:', error);
            throw error;
        }
    }

    registerPlugins() {
        PLUGIN_LOAD_ORDER.forEach(plugin => {
            try {
                this.instance.registerPlugin(plugin);
            } catch (error) {
                console.warn(`플러그인 등록 실패: ${plugin.name}`, error);
            }
        });
    }

    dispose() {
        if (this.instance) {
            // 모든 워크북 정리
            this.workbooks.forEach(workbook => {
                try {
                    this.instance.disposeUnit(workbook.getUnitId());
                } catch (error) {
                    console.warn('워크북 정리 실패:', error);
                }
            });

            this.workbooks.clear();
            this.instance.dispose();
            this.instance = null;
            this.isInitialized = false;

            console.log('🗑️ Univer 인스턴스 정리 완료');
        }
    }
}

// 전역 인스턴스 (싱글톤 패턴)
const univerManager = new UniverManager();

// 페이지 언로드 시 정리
window.addEventListener('beforeunload', () => {
    univerManager.dispose();
});
```

## 2. 성능 최적화

### 2.1 대용량 데이터 처리
```javascript
// ✅ 배치 처리 방식 (권장)
function setBulkData(sheet, startRow, startCol, data) {
    // 한 번에 여러 셀 업데이트
    const range = sheet.getRange(startRow, startCol, data.length, data[0].length);
    range.setValues(data);
}

// ❌ 개별 셀 처리 (비효율적)
function setCellData(sheet, data) {
    for (let row = 0; row < data.length; row++) {
        for (let col = 0; col < data[row].length; col++) {
            sheet.getRange(row, col).setValue(data[row][col]); // 매우 느림
        }
    }
}
```

### 2.2 가상화 설정 (대용량 시트)
```javascript
const univerInstance = new Univer.Univer({
    theme: Univer.defaultTheme,
    locale: Univer.LocaleType.KO_KR,
    container: 'univer-container',

    // 가상화 옵션 (대용량 데이터용)
    virtualization: {
        enabled: true,           // 가상화 활성화
        rowHeight: 25,          // 기본 행 높이
        columnWidth: 100,       // 기본 열 너비
        overscan: 10,           // 화면 밖 렌더링할 행/열 수
        threshold: {            // 가상화 활성화 임계값
            rows: 1000,         // 1000행 이상일 때
            columns: 50         // 50열 이상일 때
        }
    },

    // 렌더링 최적화
    rendering: {
        enableLayerCache: true,  // 레이어 캐싱
        enableGPU: true,        // GPU 가속 (지원되는 경우)
        throttleRender: 16      // 렌더링 스로틀링 (60fps)
    }
});
```

### 2.3 메모리 관리
```javascript
class DataManager {
    constructor(univerInstance) {
        this.univer = univerInstance;
        this.cache = new Map();
        this.maxCacheSize = 100; // 최대 캐시 항목 수
    }

    // 캐시된 데이터 로드
    loadCachedData(key) {
        if (this.cache.has(key)) {
            console.log(`📊 캐시에서 데이터 로드: ${key}`);
            return this.cache.get(key);
        }
        return null;
    }

    // 데이터 캐싱 (LRU 방식)
    cacheData(key, data) {
        if (this.cache.size >= this.maxCacheSize) {
            // 가장 오래된 항목 삭제
            const firstKey = this.cache.keys().next().value;
            this.cache.delete(firstKey);
        }

        this.cache.set(key, data);
        console.log(`💾 데이터 캐시: ${key}`);
    }

    // 메모리 정리
    clearCache() {
        this.cache.clear();
        console.log('🗑️ 캐시 정리 완료');
    }

    // 사용하지 않는 워크시트 정리
    cleanupUnusedSheets() {
        const workbook = this.univer.getActiveWorkbook();
        const sheets = workbook.getSheets();

        sheets.forEach(sheet => {
            if (!sheet.isActive() && sheet.isEmpty()) {
                workbook.removeSheet(sheet.getSheetId());
                console.log(`🗑️ 빈 시트 정리: ${sheet.getName()}`);
            }
        });
    }
}
```

## 3. 오류 처리 및 복구

### 3.1 견고한 오류 처리
```javascript
class ErrorHandler {
    static async safeExecute(operation, fallback = null, context = 'Unknown') {
        try {
            return await operation();
        } catch (error) {
            console.error(`❌ ${context} 실행 실패:`, error);

            // 오류 보고 (옵션)
            this.reportError(error, context);

            // 폴백 실행
            if (typeof fallback === 'function') {
                try {
                    return await fallback();
                } catch (fallbackError) {
                    console.error(`❌ ${context} 폴백도 실패:`, fallbackError);
                }
            }

            throw error;
        }
    }

    static reportError(error, context) {
        // 오류 로깅 서비스로 전송 (예: Sentry, LogRocket)
        console.log('📊 오류 보고:', {
            message: error.message,
            context: context,
            stack: error.stack,
            timestamp: new Date().toISOString(),
            userAgent: navigator.userAgent,
            url: window.location.href
        });
    }
}

// 사용 예제
async function loadExcelFileSafely(file) {
    return await ErrorHandler.safeExecute(
        // 메인 실행
        async () => {
            const arrayBuffer = await file.arrayBuffer();
            return await parseExcelToUniver(arrayBuffer);
        },
        // 폴백 함수
        async () => {
            console.log('🔄 폴백: 기본 템플릿 로드');
            return createDefaultWorkbook();
        },
        'Excel 파일 로드'
    );
}
```

### 3.2 자동 복구 메커니즘
```javascript
class AutoRecovery {
    constructor(univerInstance) {
        this.univer = univerInstance;
        this.saveInterval = 30000; // 30초마다 자동 저장
        this.maxBackups = 10;
        this.autoSaveTimer = null;

        this.startAutoSave();
    }

    startAutoSave() {
        this.autoSaveTimer = setInterval(() => {
            this.createBackup();
        }, this.saveInterval);

        console.log('💾 자동 저장 시작 (30초 간격)');
    }

    stopAutoSave() {
        if (this.autoSaveTimer) {
            clearInterval(this.autoSaveTimer);
            this.autoSaveTimer = null;
            console.log('⏹️ 자동 저장 중지');
        }
    }

    createBackup() {
        try {
            const workbook = this.univer.getActiveWorkbook();
            if (!workbook) return;

            const snapshot = workbook.getSnapshot();
            const backupKey = `univer_backup_${Date.now()}`;

            localStorage.setItem(backupKey, JSON.stringify(snapshot));

            // 오래된 백업 삭제
            this.cleanOldBackups();

            console.log('💾 자동 백업 생성:', backupKey);
        } catch (error) {
            console.error('❌ 자동 백업 실패:', error);
        }
    }

    cleanOldBackups() {
        const keys = Object.keys(localStorage)
            .filter(key => key.startsWith('univer_backup_'))
            .sort()
            .reverse();

        if (keys.length > this.maxBackups) {
            const toDelete = keys.slice(this.maxBackups);
            toDelete.forEach(key => localStorage.removeItem(key));
            console.log(`🗑️ 오래된 백업 ${toDelete.length}개 삭제`);
        }
    }

    async recoverFromBackup() {
        const keys = Object.keys(localStorage)
            .filter(key => key.startsWith('univer_backup_'))
            .sort()
            .reverse();

        if (keys.length === 0) {
            console.log('📭 복구 가능한 백업이 없습니다');
            return false;
        }

        try {
            const latestBackup = keys[0];
            const snapshot = JSON.parse(localStorage.getItem(latestBackup));

            // 현재 워크북을 백업으로 복원
            this.univer.createUniverSheet(snapshot);

            console.log('🔄 백업에서 복구 완료:', latestBackup);
            return true;
        } catch (error) {
            console.error('❌ 백업 복구 실패:', error);
            return false;
        }
    }
}
```

## 4. 사용자 경험 향상

### 4.1 로딩 상태 관리
```javascript
class LoadingManager {
    constructor() {
        this.loadingStates = new Set();
        this.createLoadingUI();
    }

    createLoadingUI() {
        const loadingHTML = `
            <div id="univer-loading" class="univer-loading hidden">
                <div class="loading-spinner"></div>
                <div class="loading-message">로딩 중...</div>
                <div class="loading-progress">
                    <div class="progress-bar"></div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', loadingHTML);

        // CSS 스타일 추가
        const style = document.createElement('style');
        style.textContent = `
            .univer-loading {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(255, 255, 255, 0.9);
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                z-index: 10000;
            }
            .univer-loading.hidden { display: none; }
            .loading-spinner {
                width: 40px;
                height: 40px;
                border: 4px solid #f3f3f3;
                border-top: 4px solid #3498db;
                border-radius: 50%;
                animation: spin 1s linear infinite;
            }
            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
            .loading-message {
                margin-top: 20px;
                font-size: 16px;
                color: #333;
            }
            .loading-progress {
                width: 300px;
                height: 4px;
                background: #f0f0f0;
                margin-top: 20px;
                border-radius: 2px;
                overflow: hidden;
            }
            .progress-bar {
                height: 100%;
                background: #3498db;
                width: 0%;
                transition: width 0.3s ease;
            }
        `;
        document.head.appendChild(style);
    }

    show(message = '로딩 중...', taskId = 'default') {
        this.loadingStates.add(taskId);

        const loadingElement = document.getElementById('univer-loading');
        const messageElement = loadingElement.querySelector('.loading-message');

        messageElement.textContent = message;
        loadingElement.classList.remove('hidden');

        console.log(`⏳ 로딩 시작: ${message} (${taskId})`);
    }

    updateProgress(percentage, taskId = 'default') {
        if (!this.loadingStates.has(taskId)) return;

        const progressBar = document.querySelector('.progress-bar');
        progressBar.style.width = `${Math.min(100, Math.max(0, percentage))}%`;
    }

    hide(taskId = 'default') {
        this.loadingStates.delete(taskId);

        if (this.loadingStates.size === 0) {
            const loadingElement = document.getElementById('univer-loading');
            loadingElement.classList.add('hidden');
            console.log('✅ 모든 로딩 완료');
        }
    }
}

// 전역 로딩 매니저
const loadingManager = new LoadingManager();
```

### 4.2 사용자 피드백 시스템
```javascript
class FeedbackManager {
    static showSuccess(message, duration = 3000) {
        this.showToast(message, 'success', duration);
    }

    static showError(message, duration = 5000) {
        this.showToast(message, 'error', duration);
    }

    static showWarning(message, duration = 4000) {
        this.showToast(message, 'warning', duration);
    }

    static showToast(message, type = 'info', duration = 3000) {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;

        const toastContainer = this.getToastContainer();
        toastContainer.appendChild(toast);

        // 애니메이션
        setTimeout(() => toast.classList.add('show'), 100);

        // 자동 제거
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => {
                if (toast.parentNode) {
                    toast.parentNode.removeChild(toast);
                }
            }, 300);
        }, duration);
    }

    static getToastContainer() {
        let container = document.getElementById('toast-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'toast-container';
            container.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                z-index: 10001;
            `;
            document.body.appendChild(container);

            // CSS 추가
            const style = document.createElement('style');
            style.textContent = `
                .toast {
                    padding: 12px 20px;
                    margin-bottom: 10px;
                    border-radius: 4px;
                    color: white;
                    font-size: 14px;
                    opacity: 0;
                    transform: translateX(100%);
                    transition: all 0.3s ease;
                    max-width: 300px;
                    word-wrap: break-word;
                }
                .toast.show {
                    opacity: 1;
                    transform: translateX(0);
                }
                .toast-success { background: #28a745; }
                .toast-error { background: #dc3545; }
                .toast-warning { background: #ffc107; color: #212529; }
                .toast-info { background: #17a2b8; }
            `;
            document.head.appendChild(style);
        }
        return container;
    }
}
```

## 5. 데이터 검증 및 보안

### 5.1 입력 데이터 검증
```javascript
class DataValidator {
    static validateExcelFile(file) {
        const errors = [];

        // 파일 타입 검사
        const validTypes = [
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-excel'
        ];

        if (!validTypes.includes(file.type) && !file.name.match(/\.(xlsx|xls)$/i)) {
            errors.push('Excel 파일만 업로드 가능합니다 (.xlsx, .xls)');
        }

        // 파일 크기 검사 (100MB 제한)
        const maxSize = 100 * 1024 * 1024;
        if (file.size > maxSize) {
            errors.push('파일 크기는 100MB를 초과할 수 없습니다');
        }

        // 파일 이름 검사
        if (file.name.length > 255) {
            errors.push('파일명이 너무 깁니다 (최대 255자)');
        }

        return {
            isValid: errors.length === 0,
            errors: errors
        };
    }

    static validateCellValue(value, type, constraints = {}) {
        if (value === null || value === undefined || value === '') {
            return constraints.required ? ['값이 필수입니다'] : [];
        }

        const errors = [];

        switch (type) {
            case 'number':
                const num = parseFloat(value);
                if (isNaN(num)) {
                    errors.push('숫자가 아닙니다');
                } else {
                    if (constraints.min !== undefined && num < constraints.min) {
                        errors.push(`최소값은 ${constraints.min}입니다`);
                    }
                    if (constraints.max !== undefined && num > constraints.max) {
                        errors.push(`최대값은 ${constraints.max}입니다`);
                    }
                }
                break;

            case 'text':
                const str = String(value);
                if (constraints.minLength && str.length < constraints.minLength) {
                    errors.push(`최소 ${constraints.minLength}자 이상이어야 합니다`);
                }
                if (constraints.maxLength && str.length > constraints.maxLength) {
                    errors.push(`최대 ${constraints.maxLength}자까지 가능합니다`);
                }
                if (constraints.pattern && !constraints.pattern.test(str)) {
                    errors.push('올바른 형식이 아닙니다');
                }
                break;

            case 'date':
                const date = new Date(value);
                if (isNaN(date.getTime())) {
                    errors.push('올바른 날짜 형식이 아닙니다');
                }
                break;
        }

        return errors;
    }
}
```

### 5.2 보안 설정
```javascript
class SecurityManager {
    static sanitizeHTML(html) {
        const div = document.createElement('div');
        div.textContent = html;
        return div.innerHTML;
    }

    static validateFormula(formula) {
        // 위험한 함수 목록
        const dangerousFunctions = [
            'EXEC', 'SYSTEM', 'SHELL', 'CMD',
            'IMPORT', 'INCLUDE', 'EVAL'
        ];

        const upperFormula = formula.toUpperCase();
        for (const func of dangerousFunctions) {
            if (upperFormula.includes(func)) {
                throw new Error(`보안상 위험한 함수가 감지되었습니다: ${func}`);
            }
        }

        return true;
    }

    static createSecureUniver(containerId, options = {}) {
        const secureOptions = {
            ...options,

            // XSS 방지
            sanitizeHTML: true,

            // 외부 리소스 로드 제한
            allowExternalResources: false,

            // 스크립트 실행 제한
            allowScripts: false,

            // 파일 접근 제한
            fileAccessPolicy: 'restricted',

            // 네트워크 요청 제한
            networkPolicy: 'same-origin'
        };

        return new Univer.Univer(secureOptions);
    }
}
```

## 6. 국제화 및 접근성

### 6.1 다국어 지원
```javascript
const LOCALES = {
    ko: {
        loading: '로딩 중...',
        error: '오류가 발생했습니다',
        success: '작업이 완료되었습니다',
        fileUpload: '파일을 선택하세요',
        exportExcel: 'Excel로 내보내기'
    },
    en: {
        loading: 'Loading...',
        error: 'An error occurred',
        success: 'Task completed',
        fileUpload: 'Select a file',
        exportExcel: 'Export to Excel'
    }
};

class LocalizationManager {
    constructor(locale = 'ko') {
        this.currentLocale = locale;
    }

    t(key, params = {}) {
        const messages = LOCALES[this.currentLocale] || LOCALES['ko'];
        let message = messages[key] || key;

        // 매개변수 치환
        Object.keys(params).forEach(param => {
            message = message.replace(`{${param}}`, params[param]);
        });

        return message;
    }

    setLocale(locale) {
        if (LOCALES[locale]) {
            this.currentLocale = locale;
            this.updateUIText();
        }
    }

    updateUIText() {
        document.querySelectorAll('[data-i18n]').forEach(element => {
            const key = element.getAttribute('data-i18n');
            element.textContent = this.t(key);
        });
    }
}

// 전역 로컬라이제이션 인스턴스
const i18n = new LocalizationManager();
```

### 6.2 접근성 개선
```javascript
class AccessibilityManager {
    static enhanceUniver(univerInstance) {
        // 키보드 내비게이션 개선
        this.setupKeyboardNavigation(univerInstance);

        // ARIA 라벨 추가
        this.addAriaLabels();

        // 고대비 모드 지원
        this.setupHighContrastMode();

        // 스크린 리더 지원
        this.setupScreenReaderSupport(univerInstance);
    }

    static setupKeyboardNavigation(univerInstance) {
        const container = document.getElementById(univerInstance.containerId);

        container.addEventListener('keydown', (e) => {
            const sheet = univerInstance.getActiveWorkbook()?.getActiveSheet();
            if (!sheet) return;

            switch (e.key) {
                case 'Tab':
                    e.preventDefault();
                    // 다음 셀로 이동
                    this.moveToNextCell(sheet, e.shiftKey ? 'prev' : 'next');
                    break;

                case 'Enter':
                    // 편집 모드 진입/완료
                    this.toggleEditMode(sheet);
                    break;

                case 'Escape':
                    // 편집 취소
                    this.cancelEdit(sheet);
                    break;

                case 'F2':
                    // 셀 편집
                    this.startEdit(sheet);
                    break;
            }
        });
    }

    static addAriaLabels() {
        const container = document.querySelector('.univer-container');
        if (container) {
            container.setAttribute('role', 'grid');
            container.setAttribute('aria-label', '스프레드시트');
            container.setAttribute('tabindex', '0');
        }

        // 셀에 aria-label 추가
        container.querySelectorAll('.cell').forEach((cell, index) => {
            cell.setAttribute('role', 'gridcell');
            cell.setAttribute('aria-describedby', `cell-description-${index}`);
        });
    }

    static setupHighContrastMode() {
        // 시스템 고대비 모드 감지
        const mediaQuery = window.matchMedia('(prefers-contrast: high)');

        const applyHighContrast = (isHighContrast) => {
            document.body.classList.toggle('high-contrast', isHighContrast);
        };

        applyHighContrast(mediaQuery.matches);
        mediaQuery.addEventListener('change', (e) => {
            applyHighContrast(e.matches);
        });
    }

    static setupScreenReaderSupport(univerInstance) {
        const sheet = univerInstance.getActiveWorkbook()?.getActiveSheet();
        if (!sheet) return;

        // 셀 선택 변경 시 음성 피드백
        sheet.onSelectionChange((range) => {
            const cellValue = range.getValue();
            const position = range.getA1Notation();
            const message = `${position}, ${cellValue || '빈 셀'}`;

            this.announceToScreenReader(message);
        });

        // 셀 값 변경 시 음성 피드백
        sheet.onAfterEdit((range, newValue) => {
            const position = range.getA1Notation();
            const message = `${position}에 ${newValue} 입력됨`;

            this.announceToScreenReader(message);
        });
    }

    static announceToScreenReader(message) {
        // aria-live 영역을 통한 음성 피드백
        let announcer = document.getElementById('screen-reader-announcer');
        if (!announcer) {
            announcer = document.createElement('div');
            announcer.id = 'screen-reader-announcer';
            announcer.setAttribute('aria-live', 'polite');
            announcer.setAttribute('aria-atomic', 'true');
            announcer.style.cssText = `
                position: absolute;
                left: -9999px;
                width: 1px;
                height: 1px;
                overflow: hidden;
            `;
            document.body.appendChild(announcer);
        }

        announcer.textContent = message;
    }
}
```

이 best practices 가이드를 따르면 Univer를 더욱 안정적이고 효율적으로 사용할 수 있습니다. 각 패턴은 실제 프로덕션 환경에서 검증된 방법들을 기반으로 작성되었습니다.