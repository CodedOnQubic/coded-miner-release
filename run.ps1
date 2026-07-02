param(
  [string]$Wallet = $env:CODED_WALLET,
  [string]$Worker = $env:CODED_WORKER,
  [int]$Threads = 0,
  [ValidateSet("auto", "scalar", "avx2", "avx512")]
  [string]$Backend = "auto",
  [string]$Pool = "pool.codedonqubic.com:7777"
)

$ErrorActionPreference = "Stop"

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

if (-not $Wallet) {
  $Wallet = Read-Host "Qubic wallet address"
}

if (-not $Worker) {
  $Worker = Read-Host "Worker name"
}

$Root = Join-Path $env:TEMP "coded-miner"
$TarPath = Join-Path $Root "coded-miner-windows-amd64-latest.tar.gz"
$ExtractDir = Join-Path $Root "latest-windows-amd64"
$Url = "https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-windows-amd64-latest.tar.gz"

New-Item -ItemType Directory -Force -Path $Root | Out-Null
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $ExtractDir
New-Item -ItemType Directory -Force -Path $ExtractDir | Out-Null

Write-Host "Downloading CODED Miner Windows AMD64 latest..."
try {
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $TarPath
} catch {
  $wc = New-Object Net.WebClient
  $wc.DownloadFile($Url, $TarPath)
}

Write-Host "Extracting CODED Miner..."
$tar = Get-Command tar -ErrorAction SilentlyContinue
if (-not $tar) {
  throw "tar.exe not found. Please use Windows 10/11 with tar.exe available."
}

& tar -xzf $TarPath -C $ExtractDir
if ($LASTEXITCODE -ne 0) {
  throw "Failed to extract $TarPath"
}

$Start = Join-Path $ExtractDir "start.ps1"
if (!(Test-Path $Start)) {
  throw "start.ps1 not found in Windows release package."
}

& $Start -Wallet $Wallet -Worker $Worker -Threads $Threads -Backend $Backend -Pool $Pool
