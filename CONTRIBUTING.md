# 기여 가이드 (Contributing Guide)

## 개요
MSM (MEKICS Sales Management) 프로젝트에 기여해주셔서 감사합니다. 이 문서는 프로젝트에 기여하는 방법을 안내합니다.

## 개발 환경 설정

### 필수 요구사항
- Flutter SDK 3.2.3 이상
- Node.js 16.x 이상
- MySQL 8.0 이상
- Git

### 로컬 개발 환경 구축

#### 1. 저장소 클론
```bash
git clone [repository-url]
cd msm_app
```

#### 2. Flutter 의존성 설치
```bash
flutter pub get
```

#### 3. 서버 의존성 설치
```bash
# 루트 디렉토리
npm install

# 서버 디렉토리
cd server
npm install
```

#### 4. 환경 변수 설정
```bash
# 루트 디렉토리에 .env 파일 생성
cp env.example .env

# 서버 디렉토리에 .env 파일 생성
cd server
cp .env.example .env
```

#### 5. 데이터베이스 설정
```bash
# MySQL에 데이터베이스 생성 및 테이블 설정
mysql -u root -p < lib/database_ddl.sql
mysql -u root -p < user_activity_logs.sql
```

## 개발 워크플로우

### 브랜치 전략
- `main`: 프로덕션 브랜치
- `develop`: 개발 브랜치
- `feature/[기능명]`: 새로운 기능 개발
- `bugfix/[버그명]`: 버그 수정
- `hotfix/[수정명]`: 긴급 수정

### 커밋 메시지 규칙
```
type(scope): subject

body

footer
```

**타입:**
- `feat`: 새로운 기능
- `fix`: 버그 수정
- `docs`: 문서 수정
- `style`: 코드 스타일 변경
- `refactor`: 코드 리팩토링
- `test`: 테스트 추가/수정
- `chore`: 빌드 프로세스 또는 보조 도구 변경

**예시:**
```
feat(auth): 사용자 로그인 기능 추가

- JWT 토큰 기반 인증 구현
- 로그인 상태 유지 기능 추가
- 비밀번호 암호화 적용

Closes #123
```

### 코드 스타일

#### Flutter/Dart
- `flutter analyze` 통과 필수
- `dart format` 적용
- 변수명: camelCase
- 클래스명: PascalCase
- 파일명: snake_case

#### Node.js/JavaScript
- ESLint 규칙 준수
- 변수명: camelCase
- 상수명: UPPER_SNAKE_CASE
- 함수명: camelCase

## 테스트

### Flutter 테스트
```bash
# 단위 테스트 실행
flutter test

# 위젯 테스트 실행
flutter test test/widget_test.dart
```

### 서버 테스트
```bash
# 서버 테스트 실행
cd server
npm test
```

## Pull Request 가이드

### PR 생성 전 체크리스트
- [ ] 코드 스타일 가이드 준수
- [ ] 테스트 통과
- [ ] 문서 업데이트 (필요시)
- [ ] 커밋 메시지 규칙 준수

### PR 템플릿
```markdown
## 변경 사항
- 

## 테스트
- [ ] 단위 테스트 통과
- [ ] 통합 테스트 통과
- [ ] 수동 테스트 완료

## 스크린샷 (UI 변경시)


## 관련 이슈
Closes #

## 추가 정보

```

## 이슈 리포팅

### 버그 리포트
- 재현 단계 명시
- 예상 결과 vs 실제 결과
- 환경 정보 (OS, Flutter 버전 등)
- 스크린샷 또는 로그 첨부

### 기능 요청
- 기능의 필요성 설명
- 예상 사용 시나리오
- 참고 자료 (있다면)

## 코드 리뷰 가이드

### 리뷰어 가이드
- 코드 품질 및 성능 검토
- 보안 취약점 확인
- 테스트 커버리지 확인
- 문서화 적절성 검토

### 리뷰이 가이드
- 피드백에 대한 적극적인 대응
- 변경 사항에 대한 명확한 설명
- 테스트 결과 공유

## 릴리스 프로세스

1. `develop` 브랜치에서 `release/v[버전]` 브랜치 생성
2. 버전 번호 업데이트 (`pubspec.yaml`, `package.json`)
3. 릴리스 노트 작성
4. 테스트 및 QA
5. `main` 브랜치로 머지
6. 태그 생성 및 릴리스

## 문의 및 지원

- 이슈 트래커: [GitHub Issues]
- 이메일: [개발팀 이메일]
- 문서: [프로젝트 위키]

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 LICENSE 파일을 참조하세요.