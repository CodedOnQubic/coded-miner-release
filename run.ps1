$ErrorActionPreference = "Stop"

Write-Host "[CODED] Windows public runner starting..."

$BaseUrl = $env:CODED_RELEASE_BASE_URL
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  $BaseUrl = "https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main"
}

$Asset = $env:CODED_ASSET
if ([string]::IsNullOrWhiteSpace($Asset)) {
  $Asset = "coded-miner-windows-amd64-scalar.zip"
}

$Wallet = $env:WALLET
if ([string]::IsNullOrWhiteSpace($Wallet)) {
  throw "WALLET env missing. Example: `$env:WALLET='YOUR_QUBIC_WALLET'"
}

$Worker = $env:WORKER
if ([string]::IsNullOrWhiteSpace($Worker)) {
  $Worker = "WinScalar_$env:COMPUTERNAME"
}

if ([string]::IsNullOrWhiteSpace($env:CODED_ANALYTICS)) {
  $env:CODED_ANALYTICS = "YES"
}
if ([string]::IsNullOrWhiteSpace($env:CODED_BACKEND)) {
  $env:CODED_BACKEND = "scalar"
}
if ([string]::IsNullOrWhiteSpace($env:CODED_FORCE_FULLSCORE)) {
  $env:CODED_FORCE_FULLSCORE = "1"
}
if ([string]::IsNullOrWhiteSpace($env:CODED_FULLSCORE_ALL_BACKENDS)) {
  $env:CODED_FULLSCORE_ALL_BACKENDS = "1"
}
if ([string]::IsNullOrWhiteSpace($env:CODED_PREFILTER_DIFFICULTY)) {
  $env:CODED_PREFILTER_DIFFICULTY = "0"
}

$env:WORKER = $Worker
$env:CODED_PLATFORM = "windows-amd64-scalar"
$env:CODED_RUNTIME_MARKER = "M1091V3_WINDOWS_SCALAR_PUBLIC_RUN"

$Root = Join-Path $env:USERPROFILE "coded-miner"
$Download = Join-Path $env:TEMP $Asset
$AssetUrl = "$BaseUrl/$Asset"

Write-Host "[CODED] worker=$Worker"
Write-Host "[CODED] backend=$env:CODED_BACKEND"
Write-Host "[CODED] analytics=$env:CODED_ANALYTICS"
Write-Host "[CODED] asset=$AssetUrl"
Write-Host "[CODED] root=$Root"

New-Item -ItemType Directory -Force -Path $Root | Out-Null

Write-Host "[CODED] downloading asset..."
Invoke-WebRequest -UseBasicParsing -Uri "$AssetUrl?cb=$([int][double]::Parse((Get-Date -UFormat %s)))" -OutFile $Download

Write-Host "[CODED] extracting..."
Remove-Item -Recurse -Force (Join-Path $Root "package") -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $Root "package") | Out-Null
Expand-Archive -Force -Path $Download -DestinationPath (Join-Path $Root "package")

$Exe = Join-Path $Root "package\coded-miner.exe"
if (!(Test-Path $Exe)) {
  throw "coded-miner.exe not found after extraction"
}

$Sidecar = Join-Path $Root "package\coded-runtime-sidecar.py"

Write-Host "[CODED] package files:"
Get-ChildItem (Join-Path $Root "package") | Format-Table Name,Length

if (Test-Path $Sidecar) {
  $PythonCmd = $null
  try {
    py -3 --version | Out-Null
    $PythonCmd = "py -3"
  } catch {
    try {
      python --version | Out-Null
      $PythonCmd = "python"
    } catch {
      $PythonCmd = $null
    }
  }

  if ($PythonCmd) {
    Write-Host "[CODED] starting analytics sidecar..."
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd `"$($Root)\package`"; $PythonCmd coded-runtime-sidecar.py"
  } else {
    Write-Host "[CODED] WARN: Python not found; analytics sidecar cannot start."
  }
} else {
  Write-Host "[CODED] WARN: coded-runtime-sidecar.py not included in asset."
}

Write-Host "[CODED] starting miner..."
Write-Host "[CODED] Press CTRL+C to stop."
& $Exe
