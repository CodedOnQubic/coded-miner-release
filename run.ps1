param(
  [string]$Wallet = $env:CODED_WALLET,
  [string]$Worker = $env:CODED_WORKER,
  [int]$Threads = 0,
  [ValidateSet("auto","scalar","avx2","avx512")]
  [string]$Backend = "auto",
  [string]$Pool = $env:CODED_POOL,
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$ExtraArgs
)

# M1091V27_WINDOWS_PUBLIC_RUN_HIVE_ANALYTICS
# M1091V27B_WINDOWS_NATIVE_STDERR_SAFE
# M1091V27C_WINDOWS_CANONICAL_ANALYTICS_PAYLOADS
# M1091V27I_WINDOWS_SHORT_ARGS
# M1091V34F_WINDOWS_PUBLIC_LOG_ONLY
# M1091V34G_WINDOWS_PUBLIC_LOG_SAFE_FRAMES
# M1091V34H_WINDOWS_QUIET_START_TEE_SAFE
# M1091V34I_WINDOWS_QUIET_AND_AUTOUPDATE_60S
# M1091V34J_REMOVE_WINDOWS_DEV_LINES_HARD
# M1091V34K_WINDOWS_FIRST_OUTPUT_BRANDING
# M1091V34M_WINDOWS_NO_REGISTRY_TLS_SPAM
# M1091V34N_DISABLE_WINDOWS_INLINE_AUTOUPDATE
# Windows public runner:
# - Windows 8 compatible TLS bootstrap
# - tar.exe-free .tar.gz extraction fallback
# - starts miner like Hive default analytics: log frames + analytics uploader
# - source metric: CODED_ANALYTICS_FRAME avg_hash_it_s_30s/hash_it_s/pipeline/qatum

$ErrorActionPreference = "Stop"

function Enable-CodedTls {
  # M1091V34M_WINDOWS_NO_REGISTRY_TLS_SPAM
  # Session-local TLS 1.2 only. Do not write HKLM registry keys:
  # Windows 8 / locked-down PCs can mine without admin rights and without PermissionDenied spam.
  try { [Net.ServicePointManager]::SecurityProtocol = 3072 } catch {}
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

# M1091V27I_WINDOWS_SHORT_ARGS
# Support public README shorthand:
#   -avx2 -2
#   -avx512 -31
#   -scalar -1
# Canonical long form still works:
#   -Backend avx2 -Threads 2
if ($ExtraArgs) {
  foreach ($arg in $ExtraArgs) {
    $a = ([string]$arg).Trim()
    if (!$a) { continue }

    switch -Regex ($a.ToLowerInvariant()) {
      '^-avx2$'   { $Backend = "avx2"; continue }
      '^-avx512$' { $Backend = "avx512"; continue }
      '^-scalar$' { $Backend = "scalar"; continue }
      '^-auto$'   { $Backend = "auto"; continue }
      '^-threads=(\d+)$' { $Threads = [int]$Matches[1]; continue }
      '^-t=(\d+)$'       { $Threads = [int]$Matches[1]; continue }
      '^-(\d+)$'         { $Threads = [int]$Matches[1]; continue }
      '^(\d+)$'          { $Threads = [int]$Matches[1]; continue }
    }
  }
}

if (-not $Pool) { $Pool = "178.104.150.57:7777" }
if (-not $Wallet) { $Wallet = Read-Host "Qubic wallet address" }
if (-not $Worker) { $Worker = Read-Host "Worker name" }
if ($Threads -le 0) { $Threads = [Math]::Max(1, [Environment]::ProcessorCount - 1) }

$base = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "CODED" } else { Join-Path $env:TEMP "CODED" }
# M1091V43Y_WINDOWS_RUNPS1_RELEASE_STATUS_POST
function Send-CodedReleaseStatusV43Y {
  param(
    [string]$InstallDir,
    [string]$Worker,
    [string]$Backend
  )

  try {
    $ErrorActionPreference = "SilentlyContinue"

    $manifestPath = $null
    foreach ($f in @(
      (Join-Path $InstallDir "release_manifest.json"),
      (Join-Path $InstallDir "coded-miner\release_manifest.json"),
      (Join-Path (Get-Location) "release_manifest.json"),
      (Join-Path (Get-Location) "coded-miner\release_manifest.json")
    )) {
      if (Test-Path $f) {
        $manifestPath = $f
        break
      }
    }

    if (!$manifestPath) { return }

    $m = Get-Content -Raw $manifestPath | ConvertFrom-Json

    $commit = [string]$m.commit
    if ($m.source_commit) { $commit = [string]$m.source_commit }

    $version = [string]$m.version
    if ($m.asset_version) { $version = [string]$m.asset_version }

    $w = $Worker
    if (!$w) { $w = $env:CODED_WORKER }
    if (!$w) { $w = $env:CODED_WORKER_NAME }
    if (!$w) { $w = $env:WORKER_NAME }
    if (!$w) { $w = $env:RIG_NAME }
    if (!$w) { $w = $env:COMPUTERNAME }
    if (!$w) { $w = "RigPortable_Win8" }

    $b = $Backend
    if (!$b) { $b = $env:CODED_KERNEL_BACKEND }
    if (!$b) { $b = $env:CODED_BACKEND }
    if (!$b) { $b = $env:BACKEND }
    if (!$b) { $b = "windows-amd64" }

    $api = $env:CODED_POOL_API_URL
    if (!$api) { $api = $env:POOL_API_URL }
    if (!$api) { $api = "http://178.104.150.57:4000" }
    $api = $api.TrimEnd("/")

    if ($commit -match "^[0-9a-fA-F]{7,40}$") {
      $payload = @{
        worker_name = $w
        rig_id = $w
        backend = $b
        commit = $commit.ToLowerInvariant()
        version = $version
      } | ConvertTo-Json -Compress

      $wc = New-Object System.Net.WebClient
      $wc.Headers.Add("Content-Type", "application/json")
      [void]$wc.UploadString("$api/api/miner/release-status", "POST", $payload)
      Write-Host "[PUBLIC] M1091V43Y_WINDOWS_RUNPS1_RELEASE_STATUS_POST worker=$w commit=$($commit.ToLowerInvariant()) backend=$b"
    }
  } catch {
    Write-Host "[PUBLIC] M1091V43Y_WINDOWS_RUNPS1_RELEASE_STATUS_POST_ERROR $($_.Exception.Message)"
  }
}

$root = Join-Path $base "miner"
$dir = Join-Path $root "latest"
$tgz = Join-Path $root "coded-miner-windows-amd64-latest.tar.gz"
$log = Join-Path $root "coded-miner.log"
$analytics = Join-Path $root "coded-windows-analytics.ps1"

# M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE
function Get-CodedWindowsLocalCommit {
  param([string]$InstallDir)

  $candidates = @(
    (Join-Path $InstallDir "release_manifest.json"),
    (Join-Path $InstallDir "coded-miner\release_manifest.json"),
    (Join-Path $InstallDir "manifest.json"),
    (Join-Path $InstallDir "coded-miner\manifest.json")
  )

  foreach ($m in $candidates) {
    if (Test-Path $m) {
      try {
        $j = Get-Content $m -Raw | ConvertFrom-Json
        if ($j.commit) { return [string]$j.commit }
      } catch {}
    }
  }

  return ""
}

function Start-CodedWindowsSafeAutoupdate {
  param(
    [string]$Root,
    [string]$CurrentCommit,
    [string]$ExePath,
    [string]$Worker
  )

  $sec = 60
  if ($env:CODED_PUBLIC_UPDATE_SEC) {
    try {
      $parsed = [int]$env:CODED_PUBLIC_UPDATE_SEC
      if ($parsed -ge 30) { $sec = $parsed }
    } catch {}
  }

  $flag = Join-Path $Root "coded-windows-update-requested.flag"
  $last = Join-Path $Root "coded-windows-last-requested.txt"
  Remove-Item $flag -Force -ErrorAction SilentlyContinue

  Start-Job -Name ("coded-win-autoupdate-" + $Worker) -ScriptBlock {
    param($Root, $CurrentCommit, $ExePath, $Worker, $Sec, $Flag, $Last)

    while ($true) {
      Start-Sleep -Seconds $Sec

      try {
        $cb = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        # M1091V39B_WINDOWS_LATEST_RELEASE_API_COMMIT_CHECK
        # Latest truth comes from GitHub Releases/latest tag, not raw main/release_manifest.json.
        # Tag format: v0.9.3-m1091v16-universal-build-button-<commit>-YYYYMMDDTHHMMSSZ
        $url = "https://api.github.com/repos/CodedOnQubic/coded-miner-release/releases/latest?cb=$cb"
        $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 20 -Headers @{ "User-Agent" = "CODED-Windows-Public-Runner" }
        $json = $resp.Content | ConvertFrom-Json
        $version = [string]$json.tag_name
        $latest = ""

        if ($version -match "-([0-9a-fA-F]{7,40})-[0-9]{8}T[0-9]{6}Z$") {
          $latest = $Matches[1].ToLowerInvariant()
        }

        if (-not $latest -and $json.name -match "-([0-9a-fA-F]{7,40})-[0-9]{8}T[0-9]{6}Z") {
          $latest = $Matches[1].ToLowerInvariant()
        }

        if (-not $latest) { continue }

        if ($latest -eq $CurrentCommit) {
          Write-Host "[PUBLIC] M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE worker=$Worker up_to_date local=$CurrentCommit latest=$latest"
          continue
        }

        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $lastCommit = ""
        $lastTs = 0

        if (Test-Path $Last) {
          try {
            $parts = (Get-Content $Last -Raw).Trim().Split(" ")
            if ($parts.Length -ge 2) {
              $lastCommit = $parts[0]
              $lastTs = [int64]$parts[1]
            }
          } catch {}
        }

        $age = $now - $lastTs
        if ($lastCommit -eq $latest -and $age -lt 900) {
          Write-Host "[PUBLIC] M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE worker=$Worker update_already_requested local=$CurrentCommit latest=$latest age_sec=$age"
          continue
        }

        "$latest $now" | Set-Content -Path $Last -Encoding ASCII
        "update_needed local=$CurrentCommit latest=$latest version=$version" | Set-Content -Path $Flag -Encoding ASCII

        Write-Host "[PUBLIC] M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE worker=$Worker update_needed local=$CurrentCommit latest=$latest version=$version action=stop_miner"

        Get-Process -ErrorAction SilentlyContinue | Where-Object {
          $_.Path -and ($_.Path -eq $ExePath)
        } | Stop-Process -Force -ErrorAction SilentlyContinue

        break
      }
      catch {
        Write-Host "[PUBLIC] M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE_ERROR worker=$Worker error=$($_.Exception.Message)"
      }
    }
  } -ArgumentList $Root, $CurrentCommit, $ExePath, $Worker, $sec, $flag, $last | Out-Null
}



Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $dir | Out-Null
New-Item -ItemType Directory -Force $root | Out-Null

# M1091V43AD_WINDOWS_MINUTELY_QUIET_AUTOUPDATE
function Start-CodedWindowsMinutelyAutoupdateV43AD {
  param(
    [string]$Root,
    [string]$InstallDir,
    [string]$ExePath,
    [string]$Worker
  )

  try {
    $jobName = "coded-win-v43ad-autoupdate-" + (($Worker -replace '[^A-Za-z0-9_.-]', '_'))
    Get-Job -Name $jobName -ErrorAction SilentlyContinue | Stop-Job -Force -ErrorAction SilentlyContinue | Out-Null
    Get-Job -Name $jobName -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue | Out-Null

    Start-Job -Name $jobName -ScriptBlock {
      param($Root, $InstallDir, $ExePath, $Worker)

      $ErrorActionPreference = "SilentlyContinue"

      $state = Join-Path $Root "autoupdate-v43ad"
      New-Item -ItemType Directory -Force -Path $state | Out-Null

      $log = Join-Path $state "autoupdate.log"
      $lastFile = Join-Path $state "last-request.txt"
      $flag = Join-Path $Root "coded-update-request.txt"

      function LogV43AD([string]$msg) {
        $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        Add-Content -Path $log -Value "$ts M1091V43AD_WINDOWS_MINUTELY_QUIET_AUTOUPDATE $msg" -Encoding UTF8
      }

      function ReadLocalCommitV43AD([string]$dir) {
        foreach ($f in @(
          (Join-Path $dir "release_manifest.json"),
          (Join-Path $dir "coded-miner\release_manifest.json")
        )) {
          if (Test-Path $f) {
            try {
              $m = Get-Content -Raw $f | ConvertFrom-Json
              $c = [string]$m.commit
              if ($m.source_commit) { $c = [string]$m.source_commit }
              if ($c -match "^[0-9a-fA-F]{7,40}$") { return $c.ToLowerInvariant() }
            } catch {}
          }
        }
        return ""
      }

      function GetLatestReleaseV43AD() {
        try {
          [Net.ServicePointManager]::SecurityProtocol = 3072
          $cb = [int][double]::Parse((Get-Date -UFormat %s))
          $url = "https://api.github.com/repos/CodedOnQubic/coded-miner-release/releases/latest?cb=$cb"
          $wc = New-Object System.Net.WebClient
          $wc.Headers.Add("User-Agent", "coded-win-v43ad-autoupdate")
          $raw = $wc.DownloadString($url)
          $json = $raw | ConvertFrom-Json

          $version = [string]$json.tag_name
          if (!$version) { $version = [string]$json.name }

          $latest = ""
          if ($version -match "-([0-9a-fA-F]{7,40})-[0-9]{8}T[0-9]{6}Z") {
            $latest = $Matches[1].ToLowerInvariant()
          } elseif ([string]$json.name -match "-([0-9a-fA-F]{7,40})-[0-9]{8}T[0-9]{6}Z") {
            $latest = $Matches[1].ToLowerInvariant()
          }

          return @{
            commit = $latest
            version = $version
          }
        } catch {
          LogV43AD "latest_check_error error=$($_.Exception.Message)"
          return @{
            commit = ""
            version = ""
          }
        }
      }

      function StopMinerV43AD([string]$exePath) {
        $stopped = $false

        try {
          $target = ""
          if ($exePath) { $target = [System.IO.Path]::GetFullPath($exePath).ToLowerInvariant() }

          $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
            try {
              $p = $_.Path
              if (!$p) { return $false }
              $pp = [System.IO.Path]::GetFullPath($p).ToLowerInvariant()
              return (
                $pp -eq $target -or
                $pp.EndsWith("\coded-miner.exe") -or
                $pp.EndsWith("\coded-miner-avx2.exe") -or
                $pp.EndsWith("\coded-miner-avx512.exe") -or
                $pp.EndsWith("\coded-miner-scalar.exe")
              )
            } catch {
              return $false
            }
          }

          foreach ($proc in $procs) {
            try {
              Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
              $stopped = $true
            } catch {}
          }
        } catch {}

        return $stopped
      }

      LogV43AD "started worker=$Worker root=$Root install=$InstallDir"

      while ($true) {
        try {
          $local = ReadLocalCommitV43AD $InstallDir
          $latestObj = GetLatestReleaseV43AD
          $latest = [string]$latestObj.commit
          $version = [string]$latestObj.version

          if (!$local -or !$latest) {
            LogV43AD "skip_missing_commit local=$local latest=$latest"
            Start-Sleep -Seconds 60
            continue
          }

          if ($local -eq $latest) {
            LogV43AD "up_to_date local=$local latest=$latest"
            Start-Sleep -Seconds 60
            continue
          }

          $now = [int][double]::Parse((Get-Date -UFormat %s))
          $lastCommit = ""
          $lastTs = 0

          if (Test-Path $lastFile) {
            $parts = (Get-Content -Raw $lastFile).Trim().Split(" ")
            if ($parts.Length -ge 2) {
              $lastCommit = $parts[0]
              [int]::TryParse($parts[1], [ref]$lastTs) | Out-Null
            }
          }

          $age = $now - $lastTs
          if ($lastCommit -eq $latest -and $age -lt 180) {
            LogV43AD "guard_skip local=$local latest=$latest age_sec=$age"
            Start-Sleep -Seconds 60
            continue
          }

          "$latest $now" | Set-Content -Path $lastFile -Encoding ASCII
          "update_needed local=$local latest=$latest version=$version" | Set-Content -Path $flag -Encoding ASCII

          $stopped = StopMinerV43AD $ExePath
          LogV43AD "update_requested local=$local latest=$latest version=$version stopped=$stopped"

          Start-Sleep -Seconds 60
        } catch {
          LogV43AD "loop_error error=$($_.Exception.Message)"
          Start-Sleep -Seconds 60
        }
      }
    } -ArgumentList $Root, $InstallDir, $ExePath, $Worker | Out-Null
  } catch {}
}

# M1091V43AF_WINDOWS_RUNSH_STYLE_AUTOUPDATE
function Start-CodedWindowsRunshStyleAutoupdateV43AF {
  param(
    [string]$Root,
    [string]$InstallDir,
    [string]$ExePath,
    [string]$Worker,
    [string]$Backend
  )

  try {
    $jobName = "coded-win-v43af-runsh-autoupdate-" + (($Worker -replace '[^A-Za-z0-9_.-]', '_'))
    Get-Job -Name $jobName -ErrorAction SilentlyContinue | Stop-Job -Force -ErrorAction SilentlyContinue | Out-Null
    Get-Job -Name $jobName -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue | Out-Null

    Start-Job -Name $jobName -ScriptBlock {
      param($Root, $InstallDir, $ExePath, $Worker, $Backend)

      $ErrorActionPreference = "SilentlyContinue"

      $state = Join-Path $Root "autoupdate-v43af"
      New-Item -ItemType Directory -Force -Path $state | Out-Null

      $log = Join-Path $state "autoupdate.log"
      $lastFile = Join-Path $state "last-request.txt"
      $flag = Join-Path $Root "coded-update-request.txt"

      function LogV43AF([string]$msg) {
        $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        Add-Content -Path $log -Value "$ts M1091V43AF_WINDOWS_RUNSH_STYLE_AUTOUPDATE $msg" -Encoding UTF8
      }

      function ReadManifestCommitV43AF([string]$file) {
        try {
          if (!(Test-Path $file)) { return "" }
          $m = Get-Content -Raw $file | ConvertFrom-Json
          $c = [string]$m.commit
          if ($m.source_commit) { $c = [string]$m.source_commit }
          if ($c -match "^[0-9a-fA-F]{7,40}$") { return $c.ToLowerInvariant() }
        } catch {}
        return ""
      }

      function LocalCommitV43AF([string]$dir) {
        foreach ($f in @(
          (Join-Path $dir "release_manifest.json"),
          (Join-Path $dir "coded-miner\release_manifest.json")
        )) {
          $c = ReadManifestCommitV43AF $f
          if ($c) { return $c }
        }
        return ""
      }

      function PackageRootV43AF([string]$extract) {
        foreach ($d in @(
          $extract,
          (Join-Path $extract "coded-miner")
        )) {
          if (Test-Path (Join-Path $d "release_manifest.json")) {
            return $d
          }
        }

        $mf = Get-ChildItem -Path $extract -Filter release_manifest.json -Recurse -ErrorAction SilentlyContinue |
          Select-Object -First 1

        if ($mf) {
          return Split-Path -Parent $mf.FullName
        }

        return ""
      }

      function RequiredExeV43AF([string]$dir, [string]$backend) {
        $b = [string]$backend
        $b = $b.ToLowerInvariant()

        $candidates = @()

        if ($b -match "avx512") {
          $candidates += "coded-miner-avx512.exe"
        }

        if ($b -match "avx2") {
          $candidates += "coded-miner-avx2.exe"
        }

        if ($b -match "scalar") {
          $candidates += "coded-miner-scalar.exe"
        }

        $candidates += @(
          "coded-miner-avx2.exe",
          "coded-miner-avx512.exe",
          "coded-miner-scalar.exe",
          "coded-miner.exe"
        )

        foreach ($name in $candidates) {
          $path = Join-Path $dir $name
          if (Test-Path $path) { return $path }
        }

        return ""
      }

      function StopMinerV43AF([string]$exePath) {
        $stopped = $false

        try {
          $target = ""
          if ($exePath) {
            try { $target = [System.IO.Path]::GetFullPath($exePath).ToLowerInvariant() } catch {}
          }

          $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
            try {
              $p = $_.Path
              if (!$p) { return $false }
              $pp = [System.IO.Path]::GetFullPath($p).ToLowerInvariant()
              return (
                ($target -and $pp -eq $target) -or
                $pp.EndsWith("\coded-miner.exe") -or
                $pp.EndsWith("\coded-miner-avx2.exe") -or
                $pp.EndsWith("\coded-miner-avx512.exe") -or
                $pp.EndsWith("\coded-miner-scalar.exe")
              )
            } catch {
              return $false
            }
          }

          foreach ($proc in $procs) {
            try {
              Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
              $stopped = $true
            } catch {}
          }
        } catch {}

        return $stopped
      }

      function ExtractTarGzV43AF([string]$tar, [string]$extract) {
        try {
          New-Item -ItemType Directory -Force -Path $extract | Out-Null

          $tarExe = Get-Command tar.exe -ErrorAction SilentlyContinue
          if ($tarExe) {
            & $tarExe.Source -xzf $tar -C $extract *> $null
            if ($LASTEXITCODE -eq 0) { return $true }
          }

          $tarCmd = Get-Command tar -ErrorAction SilentlyContinue
          if ($tarCmd) {
            & $tarCmd.Source -xzf $tar -C $extract *> $null
            if ($LASTEXITCODE -eq 0) { return $true }
          }
        } catch {}

        return $false
      }

      LogV43AF "started worker=$Worker root=$Root install=$InstallDir backend=$Backend"

      while ($true) {
        $work = $null

        try {
          $local = LocalCommitV43AF $InstallDir
          $epoch = [int][double]::Parse((Get-Date -UFormat %s))

          $lastCommit = ""
          $lastTs = 0
          if (Test-Path $lastFile) {
            $parts = (Get-Content -Raw $lastFile).Trim().Split(" ")
            if ($parts.Length -ge 2) {
              $lastCommit = $parts[0]
              [int]::TryParse($parts[1], [ref]$lastTs) | Out-Null
            }
          }

          $work = Join-Path $state ("work-" + $epoch)
          $extract = Join-Path $work "extract"
          $tarPath = Join-Path $work "coded-miner-windows-amd64-latest.tar.gz"

          New-Item -ItemType Directory -Force -Path $work | Out-Null

          [Net.ServicePointManager]::SecurityProtocol = 3072
          $url = "https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-windows-amd64-latest.tar.gz?cb=$epoch"

          $wc = New-Object System.Net.WebClient
          $wc.Headers.Add("User-Agent", "coded-win-v43af-runsh-style")
          $wc.DownloadFile($url, $tarPath)

          if (!(Test-Path $tarPath) -or ((Get-Item $tarPath).Length -lt 100000)) {
            LogV43AF "download_failed_or_too_small local=$local"
            Start-Sleep -Seconds 60
            continue
          }

          if (!(ExtractTarGzV43AF $tarPath $extract)) {
            LogV43AF "extract_failed local=$local"
            Start-Sleep -Seconds 60
            continue
          }

          $pkg = PackageRootV43AF $extract
          if (!$pkg) {
            LogV43AF "manifest_missing local=$local"
            Start-Sleep -Seconds 60
            continue
          }

          $newManifest = Join-Path $pkg "release_manifest.json"
          $latest = ReadManifestCommitV43AF $newManifest

          if (!$latest) {
            LogV43AF "latest_commit_missing local=$local"
            Start-Sleep -Seconds 60
            continue
          }

          if ($local -eq $latest) {
            LogV43AF "up_to_date local=$local latest=$latest"
            Start-Sleep -Seconds 60
            continue
          }

          $age = $epoch - $lastTs
          if ($lastCommit -eq $latest -and $age -lt 180) {
            LogV43AF "guard_skip local=$local latest=$latest age_sec=$age"
            Start-Sleep -Seconds 60
            continue
          }

          $required = RequiredExeV43AF $pkg $Backend
          if (!$required) {
            LogV43AF "required_binary_missing local=$local latest=$latest backend=$Backend keep_current"
            Start-Sleep -Seconds 60
            continue
          }

          "$latest $epoch" | Set-Content -Path $lastFile -Encoding ASCII
          "update_needed local=$local latest=$latest backend=$Backend" | Set-Content -Path $flag -Encoding ASCII

          $backup = Join-Path $Root ("previous-" + $local + "-" + $epoch)
          $incoming = Join-Path $Root ("incoming-" + $latest + "-" + $epoch)

          if (Test-Path $incoming) { Remove-Item $incoming -Recurse -Force -ErrorAction SilentlyContinue }
          Move-Item -Path $pkg -Destination $incoming -Force

          $stopped = StopMinerV43AF $ExePath
          Start-Sleep -Seconds 4

          try {
            if (Test-Path $backup) { Remove-Item $backup -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path $InstallDir) { Move-Item -Path $InstallDir -Destination $backup -Force }
            Move-Item -Path $incoming -Destination $InstallDir -Force
            LogV43AF "activated local=$local latest=$latest backend=$Backend stopped=$stopped backup=$backup"

            # Existing run.ps1 outer logic sees coded-update-request.txt after miner exits.
            # If it does not, the next manual public runner start already uses the updated package.
          } catch {
            LogV43AF "activate_failed local=$local latest=$latest error=$($_.Exception.Message)"
            try {
              if (!(Test-Path $InstallDir) -and (Test-Path $backup)) {
                Move-Item -Path $backup -Destination $InstallDir -Force
              }
            } catch {}
          }

          Start-Sleep -Seconds 60
        } catch {
          LogV43AF "loop_error error=$($_.Exception.Message)"
          Start-Sleep -Seconds 60
        } finally {
          try {
            if ($work -and (Test-Path $work)) {
              Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
            }
          } catch {}
        }
      }
    } -ArgumentList $Root, $InstallDir, $ExePath, $Worker, $Backend | Out-Null
  } catch {}
}

$url = "https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-windows-amd64-latest.tar.gz"
Write-Host "Downloading latest Windows universal miner..."
Download-File $url $tgz

Write-Host "Extracting..."
Expand-TarGz $tgz $dir

$CurrentCommit = Get-CodedWindowsLocalCommit $dir
Write-Host ("Current release commit: " + $CurrentCommit)

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

Send-CodedReleaseStatusV43Y -InstallDir $dir -Worker $Worker -Backend $selected
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
Start-CodedWindowsSafeAutoupdate -Root $root -CurrentCommit $CurrentCommit -ExePath $exe -Worker $Worker
Start-CodedWindowsRunshStyleAutoupdateV43AF -Root $root -InstallDir $dir -ExePath $exe -Worker $Worker -Backend $selected


function Format-CodedPublicRate($Value) {
  try { $v = [double]$Value } catch { return "0" }

  if ($v -ge 1000000000) { return ("{0:N2}B" -f ($v / 1000000000)) }
  if ($v -ge 1000000) { return ("{0:N2}M" -f ($v / 1000000)) }
  if ($v -ge 1000) { return ("{0:N1}K" -f ($v / 1000)) }
  return ("{0:N0}" -f $v)
}

function Get-CodedPublicMap([string]$Line) {
  $m = @{}
  foreach ($match in [regex]::Matches($Line, '([A-Za-z0-9_]+)=("[^"]*"|[^ ]+)')) {
    $k = $match.Groups[1].Value
    $v = $match.Groups[2].Value.Trim('"')
    $m[$k] = $v
  }
  return $m
}

function Get-CodedPublicValue($Map, [string]$Key, $Fallback) {
  if ($Map.ContainsKey($Key) -and $Map[$Key] -and $Map[$Key] -ne "unknown" -and $Map[$Key] -ne "unset") {
    return $Map[$Key]
  }
  return $Fallback
}

function Get-CodedPublicBackend($Raw) {
  $b = ([string]$Raw).ToLower()
  if ($b -match "avx512") { return "AVX512" }
  if ($b -match "avx2") { return "AVX2" }
  if ($b -match "arm|neon") { return "ARM" }
  if ($b -match "cuda") { return "CUDA" }
  return "SCALAR"
}

function Write-CodedPublicBrand {
  $title = '$0.01  IS  CODED'
  $width = 78
  $line = "=" * $width
  $pad = [Math]::Max(0, $width - $title.Length)
  $left = [Math]::Floor($pad / 2)
  $right = $pad - $left

  Write-Host ""
  Write-Host ("+" + $line + "+")
  Write-Host ("|" + (" " * $left) + $title + (" " * $right) + "|")
  Write-Host ("+" + $line + "+")
  Write-Host ""
}


function Get-CodedPublicEpochFallback {
  try {
    $ref = [DateTime]::Parse("2026-07-01T12:00:00Z").ToUniversalTime()
    $now = (Get-Date).ToUniversalTime()
    $weeks = [Math]::Floor(($now - $ref).TotalDays / 7)
    return [string](220 + $weeks)
  } catch {
    return "?"
  }
}

function Show-CodedPublicBootLoader([string]$Status) {
  $width = 78
  for ($p = 0; $p -le 100; $p += 2) {
    $fill = [int][Math]::Floor($width * $p / 100)
    $bar = ("#" * $fill) + ("." * ($width - $fill))
    Write-Host ("`r" + $bar) -NoNewline -ForegroundColor Green
    Start-Sleep -Milliseconds 14
  }
  Write-Host ""
  $line = ("100% " + $Status)
  if ($line.Length -gt $width) { $line = $line.Substring(0, $width) }
  $left = [Math]::Floor(($width - $line.Length) / 2)
  Write-Host ((" " * $left) + $line)
  Write-Host ""
}


$script:CODED_PUBLIC_HEADER_PRINTED = $false
$script:CODED_PUBLIC_LINE_COUNT = 0
$script:CODED_PUBLIC_LAST_SIG = ""

function Write-CodedPublicFrame([string]$Line) {
  if ($Line -notmatch "CODED_ANALYTICS_FRAME") { return }

  $sig = [string]$Line.GetHashCode()
  if ($sig -eq $script:CODED_PUBLIC_LAST_SIG) { return }
  $script:CODED_PUBLIC_LAST_SIG = $sig

  $m = Get-CodedPublicMap $Line

  $backendRaw = Get-CodedPublicValue $m "backend" $selected
  $backend = Get-CodedPublicBackend $backendRaw

  $epoch = Get-CodedPublicValue $m "epoch" "?"
  if (-not $epoch -or $epoch -eq "?" -or $epoch -eq "0") { $epoch = Get-CodedPublicEpochFallback }
  $total = Get-CodedPublicValue $m "hash_it_s" (Get-CodedPublicValue $m "total_it_s" 0)
  $avg = Get-CodedPublicValue $m "avg_hash_it_s_30s" (Get-CodedPublicValue $m "avg_it_s" $total)

  $sols = Get-CodedPublicValue $m "total_pass" 0
  $accepted = Get-CodedPublicValue $m "accepted" 0
  $rejected = Get-CodedPublicValue $m "rejected" 0

  if (-not $script:CODED_PUBLIC_HEADER_PRINTED) {
    Write-CodedPublicBrand
    Write-Host "CODED PUBLIC MINER"
    Write-Host ("wallet  : " + $Wallet)
    Write-Host ("worker  : " + $Worker)
    Write-Host ("threads : " + $Threads)
    Write-Host ("backend : " + $backend)
    Write-Host ("epoch   : " + $epoch)
    Write-Host ""
    $script:CODED_PUBLIC_HEADER_PRINTED = $true
  }

  if (($script:CODED_PUBLIC_LINE_COUNT -gt 0) -and (($script:CODED_PUBLIC_LINE_COUNT % 9) -eq 0)) {
    Write-CodedPublicBrand
  }

  $clock = Get-Date -Format "HH:mm:ss"
  $totalText = Format-CodedPublicRate $total
  $avgText = Format-CodedPublicRate $avg

  $body = "$clock E:$epoch | SOLS $sols/$accepted R:$rejected | $backend | $totalText it/s | AVG $avgText it/s"
  $logo = '[$0.01]'
  $width = 78
  $gap = $width - $logo.Length - $body.Length
  if ($gap -lt 1) { $gap = 1 }

  $out = $logo + (" " * $gap) + $body
  if ($out.Length -gt $width) { $out = $out.Substring(0, $width) }

  Write-Host $out
  $script:CODED_PUBLIC_LINE_COUNT += 1
}


Write-CodedPublicBrand
Show-CodedPublicBootLoader "Neural network training online"
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

# M1091V27B_WINDOWS_NATIVE_STDERR_SAFE
# Windows PowerShell can convert native stderr output into NativeCommandError when
# $ErrorActionPreference="Stop". The miner prints normal runtime/status lines on
# stderr on some Windows builds, so do not let stderr stop the public runner.
$ErrorActionPreference = "Continue"
try {
  & $exe --pool $Pool --wallet $Wallet --worker $Worker --threads "$Threads" 2>&1 | Tee-Object -FilePath $log -Append | ForEach-Object {
    $line = [string]$_
    Write-CodedPublicFrame $line
  }
} finally {
  Write-Host ""

  # M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE
  $updateFlag = Join-Path $root "coded-windows-update-requested.flag"
  if (Test-Path $updateFlag) {
    Write-Host "CODED Miner update requested. Restarting public runner on latest..."
    Remove-Item $updateFlag -Force -ErrorAction SilentlyContinue

    $self = $PSCommandPath
    if (-not $self) { $self = $MyInvocation.MyCommand.Path }

    if ($self -and (Test-Path $self)) {
      $args = @(
        "-NoProfile",
        "-ExecutionPolicy","Bypass",
        "-File",$self,
        "-Wallet",$Wallet,
        "-Worker",$Worker,
        "-Pool",$Pool,
        "-Backend",$Backend,
        "-Threads","$Threads"
      )
      Start-Process powershell -ArgumentList $args | Out-Null
      exit
    }
  }

  Write-Host "CODED Miner process ended."
}
