Write-Host "[DEBUG] Starting backend build..." -ForegroundColor Cyan

# 1. Build backend
Set-Location "D:\D_A_T_A\Du_an\DACS4\study-p2p\server-java\demo"
$mvn = Start-Process "mvn" -ArgumentList "clean", "package" -NoNewWindow -Wait -PassThru

if ($mvn.ExitCode -ne 0) {
    Write-Host "[ERROR] Maven build failed!" -ForegroundColor Red
    exit
}

Write-Host "[DEBUG] BUILD SUCCESS! Starting server..." -ForegroundColor Green

# 2. Start backend server (background)
$jarPath = "target/demo-1.0-SNAPSHOT-shaded.jar"

Start-Process "java" -ArgumentList "-jar", $jarPath `
    -WorkingDirectory (Get-Location) `
    -WindowStyle Minimized

Write-Host "[DEBUG] Server started (background). Waiting in 5s..." -ForegroundColor Yellow
Start-Sleep -Seconds 5


# 3. Start Flutter
Write-Host "[DEBUG] Starting Flutter..." -ForegroundColor Cyan
Set-Location "D:\D_A_T_A\Du_an\DACS4\study-p2p\flutter-app\flutter_application_1"

flutter run -d edge

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter failed!" -ForegroundColor Red
    exit
}

Write-Host "[DONE] Everything running!" -ForegroundColor Green
