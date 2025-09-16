@echo off
echo FTP 업로드 시작...

REM FTP 서버 정보 설정
set FTP_SERVER=your_ftp_server.com
set FTP_USER=your_username
set FTP_PASS=your_password
set REMOTE_DIR=/path/to/remote/directory

REM 임시 FTP 스크립트 파일 생성
echo open %FTP_SERVER% > ftp_script.txt
echo %FTP_USER% >> ftp_script.txt
echo %FTP_PASS% >> ftp_script.txt
echo cd %REMOTE_DIR% >> ftp_script.txt
echo binary >> ftp_script.txt
echo prompt >> ftp_script.txt
echo mput *.* >> ftp_script.txt
echo bye >> ftp_script.txt

REM FTP 실행
ftp -s:ftp_script.txt

REM 임시 파일 삭제
del ftp_script.txt

echo FTP 업로드 완료!
pause 