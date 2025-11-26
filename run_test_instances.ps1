# Script để chạy 2 instances và lưu logs

$projectPath = "D:\D_A_T_A\Du_an\DACS4\study-p2p\flutter-app\flutter_application_1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STUDY P2P - TEST 2 INSTANCES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Cách 1: Chạy Manual" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow
Write-Host "1. Mở VS Code -> F5 (chạy instance 1)"
Write-Host "2. Mở PowerShell mới -> chạy lệnh:"
Write-Host "   cd $projectPath" -ForegroundColor Green
Write-Host "   flutter run -d chrome" -ForegroundColor Green
Write-Host ""

Write-Host "Cách 2: Script Auto (sẽ mở 2 terminals)" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow
Write-Host "Nhấn phím bất kỳ để bắt đầu..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "Mở Terminal 1 (Windows)..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectPath'; Write-Host 'INSTANCE 1 - Windows' -ForegroundColor Cyan; flutter run -d windows 2>&1 | Tee-Object -FilePath '$PSScriptRoot\logs_instance1.txt'"

Write-Host "Chờ 3 giây..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

Write-Host "Mở Terminal 2 (Chrome)..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectPath'; Write-Host 'INSTANCE 2 - Chrome' -ForegroundColor Cyan; flutter run -d chrome 2>&1 | Tee-Object -FilePath '$PSScriptRoot\logs_instance2.txt'"

Write-Host ""
Write-Host "✅ Đã mở 2 terminals!" -ForegroundColor Green
Write-Host ""
Write-Host "Logs sẽ được lưu vào:" -ForegroundColor Yellow
Write-Host "  - logs_instance1.txt" -ForegroundColor Cyan
Write-Host "  - logs_instance2.txt" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sau khi test xong, gửi 2 file logs này!" -ForegroundColor Yellow
