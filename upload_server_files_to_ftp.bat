@echo off
echo ========================================
echo 서버 파일 FTP 업로드 시작
echo ========================================

REM FTP 서버 정보 설정 (실제 정보로 변경하세요)
set FTP_SERVER=your_ftp_server.com
set FTP_USER=your_username
set FTP_PASS=your_password
set REMOTE_DIR=/path/to/remote/directory

echo FTP 서버: %FTP_SERVER%
echo 사용자: %FTP_USER%
echo 원격 디렉토리: %REMOTE_DIR%
echo.

REM 서버 파일 정리 먼저 실행
echo 서버 파일 정리 중...
call prepare_server_files.bat

REM FTP 스크립트 파일 생성
echo FTP 스크립트 생성 중...
echo open %FTP_SERVER% > ftp_script.txt
echo %FTP_USER% >> ftp_script.txt
echo %FTP_PASS% >> ftp_script.txt
echo cd %REMOTE_DIR% >> ftp_script.txt
echo binary >> ftp_script.txt
echo prompt >> ftp_script.txt

REM 서버 파일들 업로드
echo mput server_files\*.js >> ftp_script.txt
echo mput server_files\*.json >> ftp_script.txt
echo mput server_files\*.sql >> ftp_script.txt
echo mput server_files\*.md >> ftp_script.txt
echo mput server_files\*.gitignore >> ftp_script.txt

REM routes 폴더 업로드
echo cd routes >> ftp_script.txt
echo mput server_files\routes\*.js >> ftp_script.txt
echo cd .. >> ftp_script.txt

REM src 폴더 업로드
echo cd src >> ftp_script.txt
echo mput server_files\src\*.js >> ftp_script.txt
echo cd .. >> ftp_script.txt

echo bye >> ftp_script.txt

echo FTP 업로드 시작...
ftp -s:ftp_script.txt

REM 임시 파일 삭제
del ftp_script.txt

echo.
echo ========================================
echo 서버 파일 FTP 업로드 완료!
echo ========================================
pause 