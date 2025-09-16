@echo off
echo 서버 파일 정리 및 FTP 업로드 준비 시작...

REM 서버 전용 폴더 생성
if not exist "server_files" mkdir server_files
if not exist "server_files\routes" mkdir server_files\routes
if not exist "server_files\src" mkdir server_files\src

REM 핵심 서버 파일들 복사
echo 핵심 서버 파일 복사 중...
copy "server.js" "server_files\"
copy "package.json" "server_files\"
copy "package-lock.json" "server_files\"
copy "database_logger.js" "server_files\"
copy "hospital_delivery.js" "server_files\"
copy "env.example" "server_files\"
copy "SERVER_README.md" "server_files\"

REM SQL 파일들 복사
echo SQL 파일 복사 중...
copy "*.sql" "server_files\"

REM routes 폴더 복사
echo routes 폴더 복사 중...
xcopy "routes\*" "server_files\routes\" /E /I /Y

REM src 폴더 복사
echo src 폴더 복사 중...
xcopy "src\*" "server_files\src\" /E /I /Y

REM .gitignore 파일 생성 (서버용)
echo 서버용 .gitignore 생성...
echo node_modules/ > server_files\.gitignore
echo .env >> server_files\.gitignore
echo logs/ >> server_files\.gitignore
echo *.log >> server_files\.gitignore

echo 서버 파일 정리 완료!
echo FTP 업로드할 폴더: server_files
pause 