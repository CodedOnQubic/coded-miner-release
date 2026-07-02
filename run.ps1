param(
  [string]$Wallet = $env:CODED_WALLET,
  [string]$Worker = $env:CODED_WORKER,
  [int]$Threads = 0,
  [ValidateSet("auto","scalar","avx2","avx512")]
  [string]$Backend = "auto",
  [string]$Pool = $env:CODED_POOL
)

# M1091V27_WINDOWS_PUBLIC_RUN_HIVE_ANALYTICS
# M1091V27B_WINDOWS_NATIVE_STDERR_SAFE
# M1091V27C_WINDOWS_CANONICAL_ANALYTICS_PAYLOADS
# M1091V27F_RESTORE_CANONICAL_WITH_CMD_BRIDGE
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
  [string]$Token,
  [string]$Worker,
  [string]$RigId,
  [string]$Backend,
  [int]$Threads,
  [string]$RunId
)

# M1091V27C_WINDOWS_CANONICAL_ANALYTICS_PAYLOADS
# Canonical Windows uploader compatible with Hive sidecar payloads.

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

function S($m,$k,$fallback) {
  if ($m.ContainsKey($k) -and $m[$k] -and $m[$k] -ne "unknown" -and $m[$k] -ne "unset") { return [string]$m[$k] }
  return $fallback
}

function F($m,$k,$fallback=0.0) {
  if ($m.ContainsKey($k)) {
    $x = 0.0
    if ([double]::TryParse(($m[$k] -replace ',','.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$x)) { return $x }
  }
  return $fallback
}

function I($m,$k,$fallback=0) {
  if ($m.ContainsKey($k)) {
    $x = 0
    if ([int]::TryParse(([string]$m[$k]), [ref]$x)) { return $x }
    $d = 0.0
    if ([double]::TryParse(([string]$m[$k] -replace ',','.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return [int]$d }
  }
  return $fallback
}

function Frame-Object($m) {
  $o = @{}
  foreach ($k in $m.Keys) {
    $raw = [string]$m[$k]
    $iv = 0
    $dv = 0.0
    if ([int]::TryParse($raw, [ref]$iv)) {
      $o[$k] = $iv
    } elseif ([double]::TryParse(($raw -replace ',','.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$dv)) {
      $o[$k] = $dv
    } else {
      $o[$k] = $raw
    }
  }
  return $o
}

function Api-Url($api, $path) {
  if (-not $api) { $api = "https://api.codedonqubic.com" }
  $base = $api.TrimEnd("/")
  if ($base.ToLower().EndsWith("/analytics") -and $path.ToLower().StartsWith("/analytics/")) {
    $base = $base.Substring(0, $base.Length - 10)
  }
  return $base + $path
}

function Post-Json($path, $payload) {
  try {
    $json = $payload | ConvertTo-Json -Depth 16 -Compress
    $wc = New-Object Net.WebClient
    $wc.Headers["Content-Type"] = "application/json"
    if ($Token) { $wc.Headers["Authorization"] = "Bearer $Token" }
    $url = Api-Url $Api $path
    $resp = $wc.UploadString($url, "POST", $json)
    Write-Host "[M1091V27C_WINDOWS_CANONICAL_ANALYTICS_PAYLOADS] $path ok resp=$($resp.Substring(0,[Math]::Min(160,$resp.Length)))"
  } catch {
    Write-Host "[M1091V27C_WINDOWS_CANONICAL_ANALYTICS_PAYLOADS] $path fail $($_.Exception.Message)"
  }
}

$last = ""
while ($true) {
  try {
    if (Test-Path $LogFile) {
      $frame = Get-Content $LogFile -ErrorAction SilentlyContinue |
        Where-Object { $_ -like '*[CODED_ANALYTICS_FRAME]*' } |
        Select-Object -Last 1

      if ($frame -and $frame -ne $last) {
        $last = $frame
        $m = Parse-Frame $frame
        $now = (Get-Date).ToUniversalTime().ToString("o")

        $workerName = S $m "worker" $Worker
        if (-not $workerName) { $workerName = "windows-public" }

        $rig = S $m "rig_id" $RigId
        if (-not $rig -or $rig -eq "unknown") { $rig = $workerName }

        $backendName = S $m "backend" $Backend
        if (-not $backendName) { $backendName = "unknown" }

        $runtimeBackend = S $m "runtime_backend" $backendName
        $run = S $m "run_id" $RunId
        if (-not $run) { $run = "WIN_" + $workerName }

        $thr = I $m "threads" $Threads
        $threshold = I $m "threshold" 509

        $avgHash = F $m "avg_hash_it_s_30s" 0
        $hashIts = F $m "hash_it_s" 0
        $backendHot = F $m "backend_hotloop_it_s" 0
        $pipeIts = F $m "pipeline_it_s" 0
        $routerIts = F $m "router_scoring_it_s" 0
        $qatumIts = F $m "qatum_fullscore_it_s" 0

        $avgIts = $avgHash
        if ($avgIts -le 0) { $avgIts = $hashIts }
        if ($avgIts -le 0) { $avgIts = $backendHot }

        $lastIts = $hashIts
        if ($lastIts -le 0) { $lastIts = $avgIts }

        $totalSeen = I $m "total_seen" 0
        $totalPass = I $m "total_pass" 0
        $totalAudited = I $m "total_audited" 0
        $fullscoreIterations = I $m "fullscore_total_iterations" 0
        if ($fullscoreIterations -gt $totalAudited) { $totalAudited = $fullscoreIterations }

        $falseNegative = I $m "false_negative" 0

        $real321 = I $m "real321" 0
        $real310 = I $m "real310" 0
        $real300 = I $m "real300" 0

        $b300 = I $m "score_300_309" 0
        $b310 = I $m "score_310_320" 0
        $b321 = I $m "score_321_plus" 0

        if ($b300 -le 0) { $b300 = I $m "qatum_all_score_300_309_count" 0 }
        if ($b310 -le 0) { $b310 = I $m "qatum_all_score_310_320_count" 0 }
        if ($b321 -le 0) { $b321 = I $m "qatum_all_score_321_plus_count" 0 }

        if (($b300 + $b310 + $b321) -le 0 -and $real300 -gt 0) {
          $b321 = $real321
          $b310 = [Math]::Max(0, $real310 - $real321)
          $b300 = [Math]::Max(0, $real300 - $real310)
        }

        $real300 = [Math]::Max($real300, $b300 + $b310 + $b321)
        $real310 = [Math]::Max($real310, $b310 + $b321)
        $real321 = [Math]::Max($real321, $b321)

        if ($real300 -gt $totalAudited) { $totalAudited = $real300 }

        $maxScore = I $m "max_real_score_seen" 0
        $maxPassed = I $m "max_real_score_passed" 0
        $maxSkip = I $m "max_real_score_audited_skip" 0
        if ($maxPassed -le 0) { $maxPassed = $maxScore }
        if ($maxSkip -le 0) { $maxSkip = $maxScore }

        $passRate = 0
        if ($totalSeen -gt 0) { $passRate = $totalPass / $totalSeen }

        $frameObj = Frame-Object $m
        $raw = @{
          source = "M1091V27C_WINDOWS_CANONICAL_ANALYTICS_PAYLOADS"
          posted_at = $now
          log = $LogFile
          analytics_frame = $frameObj
          windows_public_runner = $true
          runtime_backend = $runtimeBackend
          avg_hash_it_s_30s = $avgHash
          hash_it_s = $hashIts
          pipeline_it_s = $pipeIts
          router_scoring_it_s = $routerIts
          qatum_fullscore_it_s = $qatumIts
          v11_max_real_score_seen = $maxScore
          v11_score_mode = S $m "score_mode" ""
          real_score_available = S $m "real_score_available" ""
        }

        $heartbeat = @{
          run_id = $run
          rig_id = $rig
          worker_name = $workerName
          status = "running"
          live_status = "running"
          threshold = $threshold
          threads = $thr
          backend = $backendName
          active_backend = $backendName
          avg_its = $avgIts
          last_its = $lastIts
          avg_hash_it_s_30s = $avgHash
          hash_it_s = $hashIts
          total_seen = $totalSeen
          total_pass = $totalPass
          total_skip = 0
          total_audited = $totalAudited
          false_negative = $falseNegative
          max_real_score_seen = $maxScore
          max_real_score_passed = $maxPassed
          max_real_score_audited_skip = $maxSkip
          pass_rate = $passRate
          meta = $raw
          raw = $raw
        }

        $perf = @{
          run_id = $run
          rig_id = $rig
          worker_name = $workerName
          threshold = $threshold
          backend = $backendName
          active_backend = $backendName
          threads = $thr
          avg_its = $avgIts
          last_its = $lastIts
          avg_hash_it_s_30s = $avgHash
          hash_it_s = $hashIts
          backend_hotloop_it_s = $backendHot
          pipeline_it_s = $pipeIts
          router_scoring_it_s = $routerIts
          qatum_fullscore_it_s = $qatumIts
          raw_it_s = $avgHash
          total_it_s = $avgHash
          scoring_it_s = $routerIts
          fullscore_it_s = $qatumIts
          total_seen = $totalSeen
          total_pass = $totalPass
          total_audited = $totalAudited
          fullscore_count = $totalAudited
          false_negative = $falseNegative
          real300 = $real300
          real310 = $real310
          real321 = $real321
          max_real_score_seen = $maxScore
          max_real_score_passed = $maxPassed
          max_real_score_audited_skip = $maxSkip
          router_name = "M1091D_T509_DISCOVERY"
          priority_budget_matrix = "windows-public"
          raw = $raw
        }

        $score = @{
          run_id = $run
          rig_id = $rig
          worker_name = $workerName
          epoch = I $m "epoch" 0
          backend = $backendName
          cpu_model = "windows-public"
          threshold = $threshold
          threads = $thr
          batch_size = I $m "batch_size" 0
          audit_rate = 500
          total_seen = $totalSeen
          total_pass = $totalPass
          total_skip = 0
          total_audited = $totalAudited
          false_negative = $falseNegative
          max_score = $maxScore
          max_pass_score = $maxPassed
          max_audited_skip_score = $maxSkip
          score_260_269 = 0
          score_270_279 = 0
          score_280_289 = 0
          score_290_299 = 0
          score_300_309 = $b300
          score_310_320 = $b310
          score_321_plus = $b321
          real300 = $real300
          real310 = $real310
          real321 = $real321
          raw = $raw
        }

        $priority = @{
          run_id = $run
          rig_id = $rig
          worker_name = $workerName
          threshold = $threshold
          priority_matrix = "windows-public"
          priority_version = "M1091V27C_WINDOWS_CANONICAL_ANALYTICS_PAYLOADS"
          p0_seen = $totalSeen
          p0_scored = $totalAudited
          p0_skipped = 0
          p0_score_rate = $(if ($totalSeen -gt 0) { $totalAudited / $totalSeen } else { 0 })
          p0_real280 = 0
          p0_real290 = 0
          p0_real300 = $real300
          p0_real310 = $real310
          p0_real321 = $real321
          p0_d300 = $real300
          p0_d321 = $real321
          p1_seen = 0; p1_scored = 0; p1_skipped = 0; p1_score_rate = 0; p1_real280 = 0; p1_real290 = 0; p1_real300 = 0; p1_real310 = 0; p1_real321 = 0; p1_d300 = 0; p1_d321 = 0
          p2_seen = 0; p2_scored = 0; p2_skipped = 0; p2_score_rate = 0; p2_real280 = 0; p2_real290 = 0; p2_real300 = 0; p2_real310 = 0; p2_real321 = 0; p2_d300 = 0; p2_d321 = 0
          p3_seen = 0; p3_scored = 0; p3_skipped = 0; p3_score_rate = 0; p3_real280 = 0; p3_real290 = 0; p3_real300 = 0; p3_real310 = 0; p3_real321 = 0; p3_d300 = 0; p3_d321 = 0
          raw = $raw
        }

        $policy = @{
          run_id = $run
          rig_id = $rig
          worker_name = $workerName
          threshold = $threshold
          policy_name = "windows-public"
          router_name = "windows-public"
          pass = $totalPass
          real280 = 0
          real290 = 0
          real300 = $real300
          real310 = $real310
          real321 = $real321
          pass_per_seen = $(if ($totalSeen -gt 0) { $totalPass / $totalSeen } else { 0 })
          real300_per_pass = $(if ($totalPass -gt 0) { $real300 / $totalPass } else { 0 })
          real310_per_pass = $(if ($totalPass -gt 0) { $real310 / $totalPass } else { 0 })
          raw = $raw
        }

        $histogram = @{
          run_id = $run
          rig_id = $rig
          worker_name = $workerName
          threshold = $threshold
          router_name = "windows-public"
          priority_budget_matrix = "windows-public"
          rows = @(
            @{shadow_score=270; total=0; real300=$real300; real310=$real310; real321=$real321},
            @{shadow_score=280; total=0; real300=$real300; real310=$real310; real321=$real321},
            @{shadow_score=290; total=0; real300=$real300; real310=$real310; real321=$real321},
            @{shadow_score=300; total=$b300; real300=$real300; real310=$real310; real321=$real321},
            @{shadow_score=310; total=$b310; real300=$real300; real310=$real310; real321=$real321},
            @{shadow_score=321; total=$b321; real300=$real300; real310=$real310; real321=$real321}
          )
          raw = $raw
        }

        Post-Json "/analytics/runs/heartbeat" $heartbeat
        Post-Json "/analytics/performance-snapshot" $perf
        Post-Json "/analytics/score-distribution-snapshot" $score
        Post-Json "/analytics/priority-budget-snapshot" $priority
        Post-Json "/analytics/shadow-policy-snapshot" $policy
        Post-Json "/analytics/shadow-histogram-snapshot" $histogram
      }
    }
  } catch {
    Write-Host "[M1091V27C_WINDOWS_CANONICAL_ANALYTICS_PAYLOADS] loop error $($_.Exception.Message)"
  }
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
$env:CODED_ANALYTICS_API = if ($env:CODED_ANALYTICS_API) { $env:CODED_ANALYTICS_API } else { "https://api.codedonqubic.com" }
$env:CODED_ANALYTICS_TOKEN = if ($env:CODED_ANALYTICS_TOKEN) { $env:CODED_ANALYTICS_TOKEN } else { "coded_analytics_ingest_2026_secure_token" }

Write-CodedWindowsAnalytics $analytics

Write-Host "Starting analytics uploader..."
Start-Process powershell -WindowStyle Minimized -ArgumentList @(
  "-NoProfile",
  "-ExecutionPolicy","Bypass",
  "-File",$analytics,
  "-LogFile",$log,
  "-Api",$env:CODED_ANALYTICS_API,
  "-Token",$env:CODED_ANALYTICS_TOKEN,
  "-Worker",$Worker,
  "-RigId",$Worker,
  "-Backend",$selected,
  "-Threads","$Threads",
  "-RunId",$runId
) | Out-Null

Write-Host "Starting CODED Miner"
Write-Host "Backend: $selected"
Write-Host "Pool:    $Pool"
Write-Host "Worker:  $Worker"
Write-Host "Threads: $Threads"
Write-Host "Run ID:  $runId"
Write-Host "Log:     $log"
Write-Host ""

# M1091V27F_RESTORE_CANONICAL_WITH_CMD_BRIDGE
# Keep full V27C canonical analytics runner.
# Use cmd.exe only for final miner stdio so stderr becomes plain stdout before PowerShell sees it.
# This avoids NativeCommandError without using Windows 8-crashy async .NET handlers.
function Quote-CmdArg([string]$x) {
  if ($null -eq $x) { return '""' }
  return '"' + ($x -replace '"','\"') + '"'
}

$cmdLine = (Quote-CmdArg $exe) +
  " --pool " + (Quote-CmdArg $Pool) +
  " --wallet " + (Quote-CmdArg $Wallet) +
  " --worker " + (Quote-CmdArg $Worker) +
  " --threads " + (Quote-CmdArg "$Threads") +
  " 2>&1"

$ErrorActionPreference = "Continue"

try {
  & $env:ComSpec /d /s /c $cmdLine | Tee-Object -FilePath $log -Append
} finally {
  Write-Host ""
  Write-Host "CODED Miner process ended."
}
