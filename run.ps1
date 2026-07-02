param(
  [string]$Wallet = $env:CODED_WALLET,
  [string]$Worker = $env:CODED_WORKER,
  [int]$Threads = 0,
  [ValidateSet("auto","scalar","avx2","avx512")]
  [string]$Backend = "auto",
  [string]$Pool = $env:CODED_POOL
)

# M1091V27_WINDOWS_PUBLIC_RUN_HIVE_ANALYTICS
# Windows public runner:
# - Windows 8 compatible TLS bootstrap
# - tar.exe-free .tar.gz extraction fallback
# - starts miner like Hive default analytics: log frames + analytics uploader
# - source metric: CODED_ANALYTICS_FRAME avg_hash_it_s_30s/hash_it_s/pipeline/qatum

$ErrorActionPreference = "Stop"

function Enable-CodedTls {
  try { [Net.ServicePointManager]::SecurityProtocol = 3072 } catch {}
  try {
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -PropertyType DWord -Force | Out-Null
  } catch {}
}

function Download-File([string]$Url, [string]$Out) {
  Enable-CodedTls
  $wc = New-Object Net.WebClient
  $wc.Headers.Add("User-Agent", "CODED-Windows-Runner")
  $wc.DownloadFile($Url, $Out)
}

function Expand-TarGz([string]$Tgz, [string]$Dest) {
  New-Item -ItemType Directory -Force $Dest | Out-Null

  $tarCmd = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($tarCmd) {
    & $tarCmd.Source -xzf $Tgz -C $Dest
    return
  }

  $tar = Join-Path ([IO.Path]::GetDirectoryName($Tgz)) "coded.tar"
  $i = [IO.File]::OpenRead($Tgz)
  $g = New-Object IO.Compression.GzipStream($i, [IO.Compression.CompressionMode]::Decompress)
  $o = [IO.File]::Create($tar)
  $buf = New-Object byte[] 65536
  while (($r = $g.Read($buf,0,$buf.Length)) -gt 0) { $o.Write($buf,0,$r) }
  $o.Close(); $g.Close(); $i.Close()

  $fs = [IO.File]::OpenRead($tar)
  $h = New-Object byte[] 512
  while (($rr = $fs.Read($h,0,512)) -eq 512) {
    $name = ([Text.Encoding]::ASCII.GetString($h,0,100)).Trim([char]0)
    if (!$name) { break }
    $so = ([Text.Encoding]::ASCII.GetString($h,124,12)).Trim([char]0,' ')
    $sz = 0
    if ($so) { $sz = [Convert]::ToInt64($so,8) }
    $type = [char]$h[156]
    $path = Join-Path $Dest (($name -replace '^\./','') -replace '/','\')
    if ($type -eq '5') {
      New-Item -ItemType Directory -Force $path | Out-Null
    } else {
      New-Item -ItemType Directory -Force (Split-Path $path) -ErrorAction SilentlyContinue | Out-Null
      $of = [IO.File]::Create($path)
      $left = $sz
      $c = New-Object byte[] 65536
      while ($left -gt 0) {
        $n = $fs.Read($c,0,[Math]::Min($c.Length,$left))
        if ($n -le 0) { break }
        $of.Write($c,0,$n)
        $left -= $n
      }
      $of.Close()
      $skip = (512 - ($sz % 512)) % 512
      if ($skip) { $fs.Seek($skip,[IO.SeekOrigin]::Current) | Out-Null }
    }
  }
  $fs.Close()
}

function Write-CodedWindowsAnalytics([string]$Path) {
  $script = @'
param(
  [string]$LogFile,
  [string]$Api,
  [string]$Token
)

$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = 3072

function Parse-Frame($line) {
  $m = @{}
  foreach ($match in [regex]::Matches($line, '([A-Za-z0-9_]+)=("[^"]*"|[^ ]+)')) {
    $k = $match.Groups[1].Value
    $v = $match.Groups[2].Value.Trim('"')
    $m[$k] = $v
  }
  return $m
}

function F($m,$k) {
  if ($m.ContainsKey($k)) {
    $x = 0.0
    if ([double]::TryParse(($m[$k] -replace ',','.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$x)) { return $x }
  }
  return 0.0
}

function I($m,$k) {
  if ($m.ContainsKey($k)) {
    $x = 0
    if ([int]::TryParse($m[$k], [ref]$x)) { return $x }
  }
  return 0
}

$last = ""
while ($true) {
  try {
    if (Test-Path $LogFile) {
      $lines = Get-Content $LogFile -ErrorAction SilentlyContinue
      $frame = $lines | Where-Object { $_ -like '*[CODED_ANALYTICS_FRAME]*' } | Select-Object -Last 1
      if ($frame -and $frame -ne $last) {
        $last = $frame
        $m = Parse-Frame $frame
        $payload = @{
          source = "windows_public_runner"
          marker = "M1091V27_WINDOWS_PUBLIC_RUN_HIVE_ANALYTICS"
          ts = (Get-Date).ToUniversalTime().ToString("o")
          run_id = $m["run_id"]
          rig_id = $m["rig_id"]
          worker = $m["worker"]
          worker_name = $m["worker"]
          backend = $m["backend"]
          runtime_backend = $m["runtime_backend"]
          platform = "windows-amd64"
          threads = I $m "threads"
          threshold = I $m "threshold"
          phase = $m["phase"]
          avg_hash_it_s_30s = F $m "avg_hash_it_s_30s"
          hash_it_s = F $m "hash_it_s"
          backend_hotloop_it_s = F $m "backend_hotloop_it_s"
          pipeline_it_s = F $m "pipeline_it_s"
          router_scoring_it_s = F $m "router_scoring_it_s"
          qatum_fullscore_it_s = F $m "qatum_fullscore_it_s"
          completed_batch_hashrate = F $m "completed_batch_hashrate"
          raw_speed_quality = $m["raw_speed_quality"]
          total_seen = I $m "total_seen"
          total_pass = I $m "total_pass"
          false_negative = I $m "false_negative"
          real300 = I $m "real300"
          real310 = I $m "real310"
          real321 = I $m "real321"
          max_real_score_seen = I $m "max_real_score_seen"
          max_real_score_passed = I $m "max_real_score_passed"
          score_mode = $m["score_mode"]
        }

        $json = $payload | ConvertTo-Json -Depth 8 -Compress
        $wc = New-Object Net.WebClient
        $wc.Headers["Content-Type"] = "application/json"
        if ($Token) { $wc.Headers["Authorization"] = "Bearer $Token" }

        foreach ($ep in @("runs-heartbeat","performance-snapshot","score-distribution")) {
          try { $wc.UploadString(($Api.TrimEnd("/") + "/" + $ep), "POST", $json) | Out-Null } catch {}
        }
      }
    }
  } catch {}
  Start-Sleep -Seconds 5
}
'@
  Set-Content -Path $Path -Value $script -Encoding ASCII
}

Enable-CodedTls

if (-not $Pool) { $Pool = "pool.codedonqubic.com:7777" }
if (-not $Wallet) { $Wallet = Read-Host "Qubic wallet address" }
if (-not $Worker) { $Worker = Read-Host "Worker name" }
if ($Threads -le 0) { $Threads = [Math]::Max(1, [Environment]::ProcessorCount - 1) }

$base = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "CODED" } else { Join-Path $env:TEMP "CODED" }
$root = Join-Path $base "miner"
$dir = Join-Path $root "latest"
$tgz = Join-Path $root "coded-miner-windows-amd64-latest.tar.gz"
$log = Join-Path $root "coded-miner.log"
$analytics = Join-Path $root "coded-windows-analytics.ps1"

Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $dir | Out-Null
New-Item -ItemType Directory -Force $root | Out-Null

$url = "https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-windows-amd64-latest.tar.gz"

Write-Host "CODED Windows public runner"
Write-Host "Downloading latest Windows universal miner..."
Download-File $url $tgz

Write-Host "Extracting..."
Expand-TarGz $tgz $dir

$selected = $Backend.ToLowerInvariant()
if ($selected -eq "auto") {
  $detector = Join-Path $dir "coded-detect-backend.exe"
  if (Test-Path $detector) {
    $selected = (& $detector).Trim().ToLowerInvariant()
  } else {
    $selected = "scalar"
  }
}
if ($selected -notin @("scalar","avx2","avx512")) { $selected = "scalar" }

$exe = Join-Path $dir ("coded-miner-{0}.exe" -f $selected)
if (!(Test-Path $exe)) {
  $exe = Join-Path $dir "coded-miner.exe"
}
if (!(Test-Path $exe)) {
  Write-Host "Extracted files:"
  Get-ChildItem $dir -Recurse
  throw "No CODED Windows miner executable found."
}

$runId = ("WIN_{0}_{1}_{2}" -f $Worker,$selected,(Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss"))

$env:CODED_PLATFORM = "windows-amd64"
$env:CODED_KERNEL_BACKEND = $selected
$env:CODED_BACKEND = $selected
$env:CODED_POOL = $Pool
$env:CODED_WALLET = $Wallet
$env:CODED_WORKER = $Worker
$env:CODED_WORKER_NAME = $Worker
$env:CODED_RIG_ID = $Worker
$env:CODED_RUN_ID = $runId
$env:CODED_THREADS = "$Threads"
$env:CODED_ANALYTICS = "YES"
$env:CODED_ANALYTICS_ENABLED = "1"
$env:CODED_ANALYTICS_FRAME_SEC = "5"
$env:CODED_LOG_FILE = $log
$env:CODED_ANALYTICS_LOG = $log
$env:CODED_ANALYTICS_API = if ($env:CODED_ANALYTICS_API) { $env:CODED_ANALYTICS_API } else { "https://api.codedonqubic.com/analytics" }
$env:CODED_ANALYTICS_TOKEN = if ($env:CODED_ANALYTICS_TOKEN) { $env:CODED_ANALYTICS_TOKEN } else { "coded_analytics_ingest_2026_secure_token" }

Write-CodedWindowsAnalytics $analytics

Write-Host "Starting analytics uploader..."
Start-Process powershell -WindowStyle Minimized -ArgumentList @(
  "-NoProfile",
  "-ExecutionPolicy","Bypass",
  "-File",$analytics,
  "-LogFile",$log,
  "-Api",$env:CODED_ANALYTICS_API,
  "-Token",$env:CODED_ANALYTICS_TOKEN
) | Out-Null

Write-Host "Starting CODED Miner"
Write-Host "Backend: $selected"
Write-Host "Pool:    $Pool"
Write-Host "Worker:  $Worker"
Write-Host "Threads: $Threads"
Write-Host "Run ID:  $runId"
Write-Host "Log:     $log"
Write-Host ""

& $exe --pool $Pool --wallet $Wallet --worker $Worker --threads "$Threads" 2>&1 | Tee-Object -FilePath $log -Append
