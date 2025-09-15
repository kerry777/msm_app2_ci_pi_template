# Excel 뷰어 통합 프로젝트 현재 상태 보고서

**날짜**: 2025-09-15
**프로젝트**: Flutter MSM 앱 Excel 다운로드 차단 및 뷰어 통합

## 📋 프로젝트 목표

Excel 다운로드 버튼 클릭 시 파일 다운로드를 차단하고, 대신 브라우저에서 실제 MEK Excel 템플릿을 편집할 수 있는 Excel 뷰어를 열도록 하는 시스템 구현.

## ✅ 완료된 작업

### 1. BLOB URL 차단 시스템 구현
- **파일**: `C:/projects/msm_app/msm_app1/client/web/index.html`
- **기능**:
  - window.open() 오버라이드로 BLOB URL 감지 및 차단
  - location.href 설정 차단
  - anchor 태그 클릭 이벤트 차단 (download 속성 포함)
  - Flutter 버튼 동적 감지 및 이벤트 차단
- **상태**: ✅ 구현 완료, Flutter 소스에 설치됨

### 2. 디버그 로깅 시스템
- **기능**: 모든 클릭 이벤트, BLOB URL 감지, 차단 로직 상세 로깅
- **상태**: ✅ 완료

### 3. Excel 뷰어 리다이렉트
- **대상**: `http://localhost/msm/excel_template_selector.html`
- **템플릿**: quotation_kr, quotation_en, quotation_ar, sales_list, commercial_invoice, packing_list
- **상태**: ✅ 리다이렉트 로직 완료

### 4. Flutter 애플리케이션 재시작
- **포트**: 50625
- **상태**: ✅ 실행 중
- **브라우저**: Chrome 자동 열림

## ❌ 미해결 문제 및 버그

### 1. 핵심 문제: Excel 다운로드 여전히 발생
**증상**:
- 사용자 보고: "지금은 분명히 성공하지 않은 상태야"
- 이전 테스트에서 여전히 Excel 파일이 다운로드됨
- BLOB URL 차단 시스템이 실제 Flutter 버튼에서 작동하지 않는 것으로 추정

**가능한 원인**:
- Flutter에서 생성하는 BLOB URL 패턴이 예상과 다름
- 이벤트 캡처 타이밍 문제
- Flutter의 Shadow DOM 또는 가상 DOM으로 인한 이벤트 감지 실패
- 차단 시스템이 Flutter 초기화 이후에 적용되지 않음

### 2. 브라우저 콘솔 로깅 부족
- 실제 버튼 클릭 시 차단 로그가 표시되지 않음
- BLOB URL 생성 과정이 로깅되지 않음

### 3. 이벤트 캡처 범위 문제
- Flutter의 동적 DOM 생성으로 인한 이벤트 리스너 누락 가능성
- MutationObserver 필요할 수 있음

## 🔧 시도된 해결 방법

1. **Univer 라이브러리 통합** ❌
   - Constructor 오류로 실패
   - API 호환성 문제

2. **SheetJS 기반 Excel 뷰어** ✅
   - `excel_template_selector.html`에서 정상 작동
   - 실제 MEK 템플릿 파일 로드 및 편집 가능

3. **다중 차단 메커니즘 구현** ❌
   - window.open, location.href, anchor 태그 모든 방법 차단
   - 하지만 Flutter 환경에서 여전히 우회됨

4. **Flutter 소스 파일 직접 수정** ✅
   - `C:/projects/msm_app/msm_app1/client/web/index.html` 수정
   - 하지만 실제 효과 확인 안됨

## 📁 핵심 파일 현황

### 수정된 파일
- `C:/projects/msm_app/msm_app1/client/web/index.html` - BLOB URL 차단 시스템 포함

### 참조 파일
- `F:/projects/msm/web/final_blob_blocker.html` - 최종 차단 시스템 원본
- `F:/projects/msm/web/debug_excel_blocker.html` - 디버그 버전
- `F:/projects/msm/web/excel_template_selector.html` - 작동하는 Excel 뷰어

## 🎯 다음 단계 제안

### 즉시 필요한 작업
1. **실제 테스트**: 포트 50625에서 Excel 버튼 클릭하여 현재 상태 확인
2. **브라우저 개발자 도구**: 콘솔에서 차단 시스템 로그 확인
3. **네트워크 탭**: BLOB URL 생성 과정 관찰
4. **DOM 검사**: 실제 Flutter에서 생성하는 Excel 버튼 HTML 구조 확인

### 기술적 개선 방향
1. **MutationObserver 추가**: Flutter DOM 변경 감지
2. **이벤트 위임**: Document 레벨에서 모든 클릭 캡처
3. **타이밍 조정**: Flutter 완전 로드 후 차단 시스템 활성화
4. **BLOB URL 패턴 분석**: 실제 생성되는 URL 패턴 정확히 파악

## 🚨 긴급 이슈

**현재 시스템은 Excel 다운로드를 완전히 차단하지 못하고 있음**
실제 사용자 테스트에서 여전히 Excel 파일이 다운로드되는 상황으로,
근본적인 접근 방법 재검토가 필요한 상태.

---

**문서 작성**: Claude Code
**마지막 업데이트**: 2025-09-15 18:30 (KST)