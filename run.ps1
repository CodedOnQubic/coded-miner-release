param(
  [string]$Wallet=$env:CODED_WALLET,
  [string]$Worker=$env:CODED_WORKER,
  [ValidateRange(0,1024)][int]$Threads=0,
  [ValidateSet('auto','avx2','avx512','cuda','avx2+cuda','avx512+cuda')][string]$Backend='auto',
  [string]$Pool='pool.codedonqubic.com:7777',
  [switch]$Beta,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$ExtraArgs
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if ($ExtraArgs.Count) { throw 'Unsupported arguments. Use -Backend auto, avx2, avx512, cuda, avx2+cuda or avx512+cuda; retired -gpu/-gpu_only are removed.' }
if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitProcess) { throw 'Windows x64 required.' }
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$commit='14765abd4279b90c31854a880dfe18f1bd4ceae5'
$expected='e16952109b128714ecf8e8c984145b26b903d589d203a73e712cc12b39cad1ca'
$base=Join-Path $env:LOCALAPPDATA 'CODED\bootstrap'
New-Item -ItemType Directory -Force -Path $base | Out-Null
$helper=Join-Path $base ('run-windows-'+$expected+'.ps1')
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
if (!(Test-Path -LiteralPath $helper)) {
  $temporary=Join-Path $base ('.download-'+[Guid]::NewGuid().ToString('N'))
  $url='https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/'+$commit+'/run-windows.ps1'
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temporary -TimeoutSec 30
  if ((Sha $temporary) -ne $expected) { throw 'Pinned Windows bootstrap integrity failed.' }
  try { [IO.File]::Move($temporary,$helper) } catch { if (!(Test-Path -LiteralPath $helper)) { throw } }
}
if ((Sha $helper) -ne $expected) { throw 'Cached Windows bootstrap integrity failed; preserve for inspection.' }
$params=@{Wallet=$Wallet;Worker=$Worker;Threads=$Threads;Backend=$Backend;Pool=$Pool;Beta=$Beta}
& $helper @params
exit $LASTEXITCODE
