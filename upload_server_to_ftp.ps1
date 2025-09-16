# 서버 폴더 FTP 업로드 PowerShell 스크립트

param(
    [string]$FtpServer = "your_ftp_server.com",
    [string]$FtpUser = "your_username", 
    [string]$FtpPass = "your_password",
    [string]$RemoteDir = "/path/to/remote/directory"
)

Write-Host "서버 폴더 FTP 업로드 시작..." -ForegroundColor Green

# FTP 연결 생성
$ftp = [System.Net.FtpWebRequest]::Create("ftp://$FtpServer$RemoteDir")
$ftp.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $FtpPass)
$ftp.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
$ftp.UseBinary = $true

# 현재 디렉토리의 모든 파일 업로드
$files = Get-ChildItem -File
foreach ($file in $files) {
    try {
        Write-Host "업로드 중: $($file.Name)" -ForegroundColor Yellow
        
        $ftp = [System.Net.FtpWebRequest]::Create("ftp://$FtpServer$RemoteDir/$($file.Name)")
        $ftp.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $FtpPass)
        $ftp.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $ftp.UseBinary = $true
        
        $fileStream = [System.IO.File]::OpenRead($file.FullName)
        $ftpStream = $ftp.GetRequestStream()
        
        $buffer = New-Object byte[] 8192
        $bytesRead = 0
        
        while (($bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $ftpStream.Write($buffer, 0, $bytesRead)
        }
        
        $fileStream.Close()
        $ftpStream.Close()
        
        Write-Host "완료: $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "오류: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "서버 폴더 FTP 업로드 완료!" -ForegroundColor Green 