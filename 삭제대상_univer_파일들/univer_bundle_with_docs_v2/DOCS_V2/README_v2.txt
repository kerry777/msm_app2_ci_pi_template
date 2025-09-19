# MSM Excel - Univer Minimal (V2 Robust)
- 다양한 UMD 네임스페이스 변형을 런타임에서 자동 탐지하여 초기화합니다.
- 그래도 실패한다면, 세 패키지(@univerjs/core, sheets, sheets-ui)의 버전을 동일한 릴리스로 고정하세요.
- 스크립트 로드 순서는 항상 core → sheets → sheets-ui → (content) → index.js 입니다.
