# M1091V34A_WINDOWS_PUBLIC_RUNNER
# CODED public Windows runner: public console + silent raw logs + 60s release autoupdate.
# Supports official one-liners:
#   & r.ps1 -Wallet YOUR_WALLET -Worker YOUR_WORKER
#   & r.ps1 -Wallet YOUR_WALLET -Worker YOUR_WORKER -avx2 -10

$ErrorActionPreference = "Stop"

try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  [Net.ServicePointManager]::SecurityProtocol = 3072
} catch {}

$Wallet = $env:WALLET
if (-not $Wallet) { $Wallet = $env:QUBIC_WALLET }
if (-not $Wallet) { $Wallet = $env:CODED_WALLET }

$Worker = $env:WORKER
if (-not $Worker) { $Worker = $env:QUBIC_WORKER }
if (-not $Worker) { $Worker = $env:CODED_WORKER }

$Threads = 0
if ($env:THREADS) { try { $Threads = [int]$env:THREADS } catch {} }
if ($Threads -le 0 -and $env:QUBIC_THREADS) { try { $Threads = [int]$env:QUBIC_THREADS } catch {} }
if ($Threads -le 0 -and $env:CODED_THREADS) { try { $Threads = [int]$env:CODED_THREADS } catch {} }

$Backend = "auto"
if ($env:BACKEND) { $Backend = $env:BACKEND.ToLowerInvariant() }
if ($env:CODED_BACKEND) { $Backend = $env:CODED_BACKEND.ToLowerInvariant() }

$Pool = "pool.codedonqubic.com:7777"
if ($env:POOL) { $Pool = $env:POOL }
if ($env:CODED_POOL) { $Pool = $env:CODED_POOL }

for ($i = 0; $i -lt $args.Count; $i++) {
  $a = [string]$args[$i]
  switch -Regex ($a) {
    '^-Wallet$' {
      if ($i + 1 -lt $args.Count) { $i++; $Wallet = [string]$args[$i] }
      continue
    }
    '^-Worker$' {
      if ($i + 1 -lt $args.Count) { $i++; $Worker = [string]$args[$i] }
      continue
    }
    '^-Pool$' {
      if ($i + 1 -lt $args.Count) { $i++; $Pool = [string]$args[$i] }
      continue
    }
    '^-Threads$' {
      if ($i + 1 -lt $args.Count) { $i++; try { $Threads = [int]$args[$i] } catch {} }
      continue
    }
    '^-Backend$' {
      if ($i + 1 -lt $args.Count) { $i++; $Backend = ([string]$args[$i]).ToLowerInvariant() }
      continue
    }
    '^-avx512$' { $Backend = "avx512"; continue }
    '^-avx2$' { $Backend = "avx2"; continue }
    '^-scalar$' { $Backend = "scalar"; continue }
    '^-\d+$' {
      try { $Threads = [int]($a.TrimStart("-")) } catch {}
      continue
    }
  }
}

if (-not $Wallet) { $Wallet = Read-Host "Qubic wallet address" }
if (-not $Worker) { $Worker = Read-Host "Worker name" }

if ($Threads -le 0) {
  $Threads = [Math]::Max(1, [Environment]::ProcessorCount - 1)
}

if (@("auto","scalar","avx2","avx512") -notcontains $Backend) {
  $Backend = "auto"
}

$WorkerSafe = ($Worker -replace '[^A-Za-z0-9_.-]', '_')
$Base = Join-Path $env:TEMP "coded-miner\public\$WorkerSafe"
$LogDir = Join-Path $Base "logs"
$PidDir = Join-Path $Base "pids"
$StateDir = Join-Path $Base "state"
$DownloadDir = Join-Path $StateDir "download"
$ExtractDir = Join-Path $StateDir "latest"
$TarPath = Join-Path $StateDir "coded-miner-windows-amd64-latest.tar.gz"
$RunId = "PUBLIC_${WorkerSafe}_windows-amd64_$((Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss'))"
$RunLog = Join-Path $LogDir "$RunId.log"
$ErrLog = Join-Path $LogDir "ERR_$RunId.log"
$UpdateLog = Join-Path $LogDir "public-autoupdate.log"

$AssetUrl = "https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-windows-amd64-latest.tar.gz"
$RunPs1Url = "https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1"
$UpdateSec = 60
if ($env:CODED_PUBLIC_UPDATE_SEC) { try { $UpdateSec = [int]$env:CODED_PUBLIC_UPDATE_SEC } catch {} }
if ($UpdateSec -lt 30) { $UpdateSec = 30 }

$BootSec = 10
if ($env:CODED_PUBLIC_BOOT_SEC) { try { $BootSec = [int]$env:CODED_PUBLIC_BOOT_SEC } catch {} }
if ($BootSec -lt 0) { $BootSec = 0 }

New-Item -ItemType Directory -Force -Path $LogDir, $PidDir, $StateDir | Out-Null

function Add-UpdateLog($Message) {
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  "[$ts] $Message" | Out-File -FilePath $UpdateLog -Append -Encoding utf8
}

function Write-Brand {
  $title = '$0.01  IS  CODED'
  $width = 78
  $line = "═" * $width
  $pad = [Math]::Max(0, $width - $title.Length)
  $left = [Math]::Floor($pad / 2)
  $right = $pad - $left

  Write-Host ""
  Write-Host ("╔" + $line + "╗")
  Write-Host ("║" + (" " * $left) + $title + (" " * $right) + "║")
  Write-Host ("╚" + $line + "╝")
  Write-Host ""
}

$script:LoaderStarted = $false
$script:LoaderPercent = 0
$script:LoaderTop = 0

function Show-Loader($Target, $Status) {
  $width = 78
  if ($Target -lt 0) { $Target = 0 }
  if ($Target -gt 100) { $Target = 100 }
  if ($Target -lt $script:LoaderPercent) { $script:LoaderPercent = 0 }

  while ($script:LoaderPercent -lt $Target) {
    $script:LoaderPercent++
    Render-Loader $script:LoaderPercent $Status $width
    Start-Sleep -Milliseconds 12
  }

  Render-Loader $Target $Status $width
  $script:LoaderPercent = $Target
}

function Render-Loader($Percent, $Status, $Width) {
  if (-not $script:LoaderStarted) {
    $script:LoaderTop = [Console]::CursorTop
    $script:LoaderStarted = $true
  } else {
    try { [Console]::SetCursorPosition(0, $script:LoaderTop) } catch {}
  }

  $fill = [int][Math]::Floor($Width * $Percent / 100)
  $bar = ("█" * $fill) + ("░" * ($Width - $fill))
  $statusLine = ("{0,3}% {1}" -f $Percent, $Status)
  if ($statusLine.Length -gt $Width) { $statusLine = $statusLine.Substring(0, $Width) }
  $left = [Math]::Floor(($Width - $statusLine.Length) / 2)
  $statusLine = (" " * $left) + $statusLine
  if ($statusLine.Length -lt $Width) { $statusLine = $statusLine + (" " * ($Width - $statusLine.Length)) }

  Write-Host ("`r" + (" " * 120) + "`r") -NoNewline
  Write-Host $bar -ForegroundColor Green
  Write-Host ("`r" + (" " * 120) + "`r") -NoNewline
  Write-Host $statusLine
}

function Finish-Loader {
  if ($script:LoaderStarted) { Write-Host "" }
  $script:LoaderStarted = $false
}

function Download-File($Url, $OutFile) {
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $OutFile
  } catch {
    $wc = New-Object Net.WebClient
    $wc.DownloadFile($Url, $OutFile)
  }
}

function Read-ManifestCommit($Dir) {
  $mfs = Get-ChildItem -Path $Dir -Recurse -File -Include manifest.json,release_manifest.json -ErrorAction SilentlyContinue | Select-Object -First 6
  foreach ($mf in $mfs) {
    try {
      $raw = Get-Content -Raw -Path $mf.FullName
      $json = $raw | ConvertFrom-Json
      if ($json.commit) { return [string]$json.commit }
    } catch {
      $line = Select-String -Path $mf.FullName -Pattern '"commit"\s*:\s*"([^"]+)"' -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($line -and $line.Matches.Count -gt 0) { return $line.Matches[0].Groups[1].Value }
    }
  }
  return ""
}

function Stop-OldPublicProcesses {
  Get-ChildItem -Path $PidDir -Filter "*.pid" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $pidText = (Get-Content $_.FullName -ErrorAction SilentlyContinue | Select-Object -First 1)
      if ($pidText) {
        $pidValue = [int]$pidText
        Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
      }
    } catch {}
  }

  try {
    Get-WmiObject Win32_Process -ErrorAction SilentlyContinue |
      Where-Object {
        $_.CommandLine -and (
          $_.CommandLine -like "*$Base*" -or
          $_.CommandLine -like "*PUBLIC_${WorkerSafe}_*" -or
          $_.CommandLine -like "*CODED_WORKER=$WorkerSafe*"
        )
      } |
      ForEach-Object {
        try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
      }
  } catch {}

  Start-Sleep -Seconds 1
}

function Extract-Asset($Archive, $Dest) {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Dest
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null

  $tar = Get-Command tar -ErrorAction SilentlyContinue
  if (-not $tar) {
    throw "tar.exe not found. Windows needs tar.exe to extract the CODED release asset."
  }

  & tar -xzf $Archive -C $Dest
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract $Archive"
  }
}

function Find-StartScript($Dir) {
  $direct = Join-Path $Dir "start.ps1"
  if (Test-Path $direct) { return $direct }

  $found = Get-ChildItem -Path $Dir -Recurse -Filter "start.ps1" -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { return $found.FullName }

  return ""
}

function Quote-PS($Value) {
  return "'" + ([string]$Value).Replace("'", "''") + "'"
}

function Start-CodedMinerProcess($StartScript) {
  $qStart = Quote-PS $StartScript
  $qWallet = Quote-PS $Wallet
  $qWorker = Quote-PS $WorkerSafe
  $qPool = Quote-PS $Pool
  $qRunLog = Quote-PS $RunLog
  $qErrLog = Quote-PS $ErrLog
  $qPlatform = Quote-PS "windows-amd64"
  $qRunId = Quote-PS $RunId

  $cmd = @"
`$ErrorActionPreference = 'Continue'
`$env:CODED_PLATFORM = $qPlatform
`$env:CODED_BACKEND_PLATFORM = $qPlatform
`$env:CODED_WORKER = $qWorker
`$env:CODED_WORKER_NAME = $qWorker
`$env:CODED_RIG_ID = $qWorker
`$env:WORKER = $qWorker
`$env:WORKER_NAME = $qWorker
`$env:CODED_RUN_ID = $qRunId
`$env:RUN_ID = $qRunId
`$env:CODED_WALLET = $qWallet
`$env:CODED_THREADS = '$Threads'
`$env:THREADS = '$Threads'
`$env:CODED_ANALYTICS = 'YES'
`$env:CODED_ANALYTICS_ENABLED = '1'
try {
  & $qStart -Wallet $qWallet -Worker $qWorker -Threads $Threads -Backend '$Backend' -Pool $qPool *>&1 | ForEach-Object {
    [string]`$_ | Out-File -FilePath $qRunLog -Append -Encoding utf8
  }
} catch {
  ('ERROR ' + [string]`$_) | Out-File -FilePath $qErrLog -Append -Encoding utf8
}
"@

  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
  $ps = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  $proc = Start-Process -FilePath $ps -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-EncodedCommand",$encoded) -PassThru
  $proc.Id | Out-File -FilePath (Join-Path $PidDir "runner.pid") -Encoding ascii
  return $proc
}

function Current-QubicEpoch {
  try {
    $ref = [DateTime]::Parse("2026-07-01T12:00:00Z").ToUniversalTime()
    $now = [DateTime]::UtcNow
    $weeks = [Math]::Floor(($now - $ref).TotalDays / 7)
    return [string](220 + $weeks)
  } catch {
    return "?"
  }
}

function Format-Rate($Value) {
  try { $v = [double]$Value } catch { return "0" }
  if ($v -ge 1000000000) { return ("{0:N2}B" -f ($v / 1000000000)).Replace(".", ",") }
  if ($v -ge 1000000) { return ("{0:N2}M" -f ($v / 1000000)).Replace(".", ",") }
  if ($v -ge 1000) { return ("{0:N1}K" -f ($v / 1000)).Replace(".", ",") }
  return ("{0:N0}" -f $v)
}

function Backend-Label($Value) {
  $b = ([string]$Value).ToLowerInvariant()
  if ($b -match "avx512") { return "AVX512" }
  if ($b -match "avx2") { return "AVX2" }
  if ($b -match "arm|neon") { return "ARM" }
  if ($b -match "cuda") { return "CUDA" }
  return "SCALAR"
}

function Parse-Frame($Line) {
  if ($Line -notmatch "CODED_ANALYTICS_FRAME") { return $null }

  $h = @{}
  foreach ($m in [regex]::Matches($Line, '([A-Za-z0-9_]+)=("[^"]*"|\S+)')) {
    $k = $m.Groups[1].Value
    $v = $m.Groups[2].Value.Trim('"')
    $h[$k] = $v
  }
  return $h
}

function Print-PublicHeader($State) {
  Write-Brand
  Write-Host "CODED PUBLIC MINER"
  Write-Host ("wallet  : " + $Wallet)
  Write-Host ("worker  : " + $WorkerSafe)
  Write-Host ("threads : " + $Threads)
  Write-Host ("backend : " + (Backend-Label $State.backend))
  Write-Host ("epoch   : " + $State.epoch)
  Write-Host ""
}

function Print-PublicLine($State) {
  $clock = (Get-Date).ToString("HH:mm:ss")
  $epoch = $State.epoch
  if (-not $epoch -or $epoch -eq "?") { $epoch = Current-QubicEpoch }

  $backend = Backend-Label $State.backend
  $total = Format-Rate $State.total
  $avg = Format-Rate $State.avg

  $body = "$clock E:$epoch | SOLS $($State.sols)/$($State.accepted) R:$($State.rejected) | $backend | $total it/s | AVG $avg it/s"
  $logo = '[$0.01]'
  $width = 78
  $gap = $width - $logo.Length - $body.Length
  if ($gap -lt 1) { $gap = 1 }
  $line = $logo + (" " * $gap) + $body
  if ($line.Length -gt $width) { $line = $line.Substring(0, $width) }
  Write-Host $line
}

function Test-UpdateAvailable($CurrentCommit) {
  $checkDir = Join-Path $StateDir ("update-check-" + [Guid]::NewGuid().ToString("N"))
  $checkTar = Join-Path $checkDir "latest.tar.gz"

  try {
    New-Item -ItemType Directory -Force -Path $checkDir | Out-Null
    Download-File ($AssetUrl + "?cb=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) $checkTar
    Extract-Asset $checkTar $checkDir
    $newCommit = Read-ManifestCommit $checkDir

    if (-not $newCommit) {
      Add-UpdateLog "new_commit_missing keep_current cur=$CurrentCommit"
      return $false
    }

    if ($newCommit -eq $CurrentCommit) {
      Add-UpdateLog "already_latest commit=$newCommit"
      return $false
    }

    Add-UpdateLog "update_available old=$CurrentCommit new=$newCommit restarting"
    return $true
  } catch {
    Add-UpdateLog ("update_check_failed keep_current error=" + [string]$_)
    return $false
  } finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $checkDir
  }
}

function Public-ConsoleLoop($Proc, $CurrentCommit) {
  $state = [ordered]@{
    backend = $Backend
    epoch = Current-QubicEpoch
    total = 0
    avg = 0
    sols = 0
    accepted = 0
    rejected = 0
  }

  $printed = $false
  $statusCount = 0
  $seenLines = 0
  $lastUpdateCheck = Get-Date

  while ($true) {
    if ((Get-Date) -gt $lastUpdateCheck.AddSeconds($UpdateSec)) {
      $lastUpdateCheck = Get-Date
      if (Test-UpdateAvailable $CurrentCommit) {
        Write-Brand
        Show-Loader 15 "Updating CODED MINER"
        Show-Loader 45 "Downloading latest CODED MINER"
        Show-Loader 75 "Preparing restart"
        Show-Loader 100 "Restarting neural network training"
        Finish-Loader

        Stop-Process -Id $Proc.Id -Force -ErrorAction SilentlyContinue
        Stop-OldPublicProcesses

        $next = Join-Path $env:TEMP "coded-run-latest.ps1"
        Download-File ($RunPs1Url + "?cb=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) $next

        $argList = @("-NoProfile","-ExecutionPolicy","Bypass","-File",$next,"-Wallet",$Wallet,"-Worker",$WorkerSafe,"-Threads",$Threads,"-Backend",$Backend)
        & powershell.exe @argList
        exit $LASTEXITCODE
      }
    }

    if (Test-Path $RunLog) {
      $lines = Get-Content -Path $RunLog -Tail 80 -ErrorAction SilentlyContinue
      foreach ($line in $lines) {
        $frame = Parse-Frame $line
        if (-not $frame) { continue }

        $sig = $line.GetHashCode()
        if ($sig -eq $script:LastFrameSig) { continue }
        $script:LastFrameSig = $sig

        if ($frame.backend) { $state.backend = $frame.backend }
        if ($frame.runtime_backend) { $state.backend = $frame.runtime_backend }
        if ($frame.epoch) { $state.epoch = $frame.epoch }
        if ($frame.hash_it_s) { $state.total = $frame.hash_it_s }
        elseif ($frame.total_it_s) { $state.total = $frame.total_it_s }
        if ($frame.avg_hash_it_s_30s) { $state.avg = $frame.avg_hash_it_s_30s }
        elseif ($frame.avg_it_s) { $state.avg = $frame.avg_it_s }
        if ($frame.total_pass) { $state.sols = $frame.total_pass }
        if ($frame.accepted) { $state.accepted = $frame.accepted }
        if ($frame.rejected) { $state.rejected = $frame.rejected }

        if (-not $printed) {
          Print-PublicHeader $state
          $printed = $true
        }

        if (($statusCount -gt 0) -and (($statusCount % 9) -eq 0)) {
          Write-Host ""
          Write-Brand
        }

        Print-PublicLine $state
        $statusCount++
      }
    }

    if ($Proc.HasExited) {
      break
    }

    Start-Sleep -Seconds 1
  }
}

Write-Brand
Show-Loader 8 "Initializing latest CODED MINER"

Stop-OldPublicProcesses

Show-Loader 32 "Downloading latest CODED MINER"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $DownloadDir
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
Download-File ($AssetUrl + "?cb=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) $TarPath

Show-Loader 55 "Setting up environment"
Extract-Asset $TarPath $ExtractDir

$CurrentCommit = Read-ManifestCommit $ExtractDir
if (-not $CurrentCommit) { $CurrentCommit = "unknown" }

$Start = Find-StartScript $ExtractDir
if (-not $Start) {
  throw "start.ps1 not found in Windows release package."
}

Show-Loader 72 "Starting neural network training"
$Proc = Start-CodedMinerProcess $Start

Show-Loader 82 "Starting analytics heartbeat"

for ($i = 1; $i -le $BootSec; $i++) {
  $pct = 82 + [int]($i * 17 / [Math]::Max(1, $BootSec))
  if ($pct -gt 99) { $pct = 99 }
  Show-Loader $pct "Stabilizing neural network training"
  Start-Sleep -Seconds 1
}

Show-Loader 100 "Neural network training online"
Finish-Loader

Add-UpdateLog "autoupdate_started commit=$CurrentCommit interval=${UpdateSec}s worker=$WorkerSafe backend=$Backend threads=$Threads"

Public-ConsoleLoop $Proc $CurrentCommit
