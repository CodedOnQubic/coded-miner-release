param(
  [string]$Wallet = $env:CODED_WALLET,
  [string]$Worker = $env:CODED_WORKER,
  [int]$Threads = 0,
  [ValidateSet("auto","scalar","avx2","avx512")]
  [string]$Backend = "auto",
  [string]$Pool = $env:CODED_POOL,
  [switch]$Beta,
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
# M1091V53B_WINDOWS_BETA_CHANNEL_AUTOUPDATE
# M1091V54B_PUBLIC_RUNNER_RESTART_AND_MAC_ARM_NEON_LABEL
# M1091V54C_WINDOWS_SINGLE_SESSION_RESTART_CLEANUP
# M1091V54D_WINDOWS_CLEAN_SINGLE_RUNNER
# M1091V54J_WINDOWS_REENTER_WITHOUT_ARRAY_SPLATTING
# M1091V55C_WINDOWS_JOB_SCOPE_DEBUG_HELPER_ROBUST
# M1091V54K_PUBLIC_COSMETIC_AUTOUPDATE_TRANSITION
# M1091V63G2A3_WINDOWS_CHANNEL_IDENTITY_AND_IDEMPOTENT_UPDATE
function Write-CodedPublicDebugV54K([string]$Message) {
  if ($env:CODED_PUBLIC_DEBUG -eq "1") {
    Write-Host $Message
  }
}
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
  [string]$RunId,
  [string]$ReleaseChannel,
  [string]$ReleaseCommit,
  [string]$ReleaseVersion
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

        # M1091V63G2A3_WINDOWS_RELEASE_IDENTITY_IN_ALL_ANALYTICS
        $releaseChannelValue = S $m "release_channel" $ReleaseChannel
        $releaseCommitValue = S $m "release_commit" $ReleaseCommit
        $releaseVersionValue = S $m "release_version" $ReleaseVersion

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
          release_channel = $releaseChannelValue
          release_commit = $releaseCommitValue
          release_version = $releaseVersionValue
          git_commit = $releaseCommitValue
          miner_version = $releaseVersionValue
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
          release_channel = $releaseChannelValue
          release_commit = $releaseCommitValue
          release_version = $releaseVersionValue
          git_commit = $releaseCommitValue
          miner_version = $releaseVersionValue
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
          release_channel = $releaseChannelValue
          release_commit = $releaseCommitValue
          release_version = $releaseVersionValue
          git_commit = $releaseCommitValue
          miner_version = $releaseVersionValue
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
          release_channel = $releaseChannelValue
          release_commit = $releaseCommitValue
          release_version = $releaseVersionValue
          git_commit = $releaseCommitValue
          miner_version = $releaseVersionValue
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
          release_channel = $releaseChannelValue
          release_commit = $releaseCommitValue
          release_version = $releaseVersionValue
          git_commit = $releaseCommitValue
          miner_version = $releaseVersionValue
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
          release_channel = $releaseChannelValue
          release_commit = $releaseCommitValue
          release_version = $releaseVersionValue
          git_commit = $releaseCommitValue
          miner_version = $releaseVersionValue
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
          release_channel = $releaseChannelValue
          release_commit = $releaseCommitValue
          release_version = $releaseVersionValue
          git_commit = $releaseCommitValue
          miner_version = $releaseVersionValue
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

# M1091V53B_WINDOWS_BETA_CHANNEL_AUTOUPDATE
$script:CodedBetaRequested = $false
if ($Beta) { $script:CodedBetaRequested = $true }
foreach ($v in @($env:CODED_BETA_REQUESTED, $env:CODED_BETA, $env:BETA, $env:CODED_RELEASE_CHANNEL)) {
  if (!$v) { continue }
  if (([string]$v).ToLowerInvariant() -in @("1","yes","true","beta")) {
    $script:CodedBetaRequested = $true
  }
}
if ($script:CodedBetaRequested) {
  $env:CODED_BETA_REQUESTED = "1"
  $env:CODED_BETA = "yes"
  $env:BETA = "yes"
} else {
  $env:CODED_BETA_REQUESTED = "0"
}

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
      '^--?beta$' { $script:CodedBetaRequested = $true; $env:CODED_BETA_REQUESTED = "1"; $env:CODED_BETA = "yes"; $env:BETA = "yes"; continue }
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
        channel = [string]$env:CODED_RELEASE_CHANNEL
        release_channel = [string]$env:CODED_RELEASE_CHANNEL
      } | ConvertTo-Json -Compress

      $wc = New-Object System.Net.WebClient
      $wc.Headers.Add("Content-Type", "application/json")
      [void]$wc.UploadString("$api/api/miner/release-status", "POST", $payload)
      Write-CodedPublicDebugV54K "[PUBLIC] M1091V43Y_WINDOWS_RUNPS1_RELEASE_STATUS_POST worker=$w commit=$($commit.ToLowerInvariant()) backend=$b"
    }
  } catch {
    Write-CodedPublicDebugV54K "[PUBLIC] M1091V43Y_WINDOWS_RUNPS1_RELEASE_STATUS_POST_ERROR $($_.Exception.Message)"
  }
}

# M1091V53B_WINDOWS_BETA_CHANNEL_AUTOUPDATE
function New-CodedWindowsReleaseSelectionV53B {
  param(
    [string]$Channel,
    [string]$Version,
    [string]$Commit,
    [string]$Asset,
    [string]$Url
  )

  $o = New-Object PSObject
  $o | Add-Member NoteProperty Channel $Channel
  $o | Add-Member NoteProperty Version $Version
  $o | Add-Member NoteProperty Commit $Commit
  $o | Add-Member NoteProperty Asset $Asset
  $o | Add-Member NoteProperty Url $Url
  return $o
}

function Get-CodedWindowsAssetNameV53B {
  param([string]$Channel)
  if ($Channel -eq "beta") { return "coded-miner-windows-amd64-beta-latest.tar.gz" }
  return "coded-miner-windows-amd64-latest.tar.gz"
}

function Get-CodedWindowsReleaseSelectionV53B {
  param([bool]$BetaRequested)

  Enable-CodedTls

  $repo = "https://github.com/CodedOnQubic/coded-miner-release/releases"
  $poolApi = $env:CODED_POOL_API_URL
  if (!$poolApi) { $poolApi = $env:POOL_API_URL }
  if (!$poolApi) { $poolApi = "http://178.104.150.57:4000" }
  $poolApi = $poolApi.TrimEnd("/")

  try {
    $cb = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $statusUrl = "$poolApi/admin/release/channel-status?cb=$cb"
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $statusUrl -TimeoutSec 15 -Headers @{ "User-Agent" = "CODED-Windows-Public-Runner" }
    $j = $resp.Content | ConvertFrom-Json

    if ($BetaRequested -and $j.beta -and $j.beta.version -and $j.beta.commit) {
      $asset = Get-CodedWindowsAssetNameV53B "beta"
      $version = [string]$j.beta.version
      $commit = ([string]$j.beta.commit).ToLowerInvariant()
      $url = "$repo/download/$version/$asset"
      return New-CodedWindowsReleaseSelectionV53B "beta" $version $commit $asset $url
    }

    if ($j.public_latest -and $j.public_latest.version) {
      $asset = Get-CodedWindowsAssetNameV53B "latest"
      $version = [string]$j.public_latest.version
      $commit = ""
      if ($j.public_latest.commit) { $commit = ([string]$j.public_latest.commit).ToLowerInvariant() }
      $url = "$repo/download/$version/$asset"
      return New-CodedWindowsReleaseSelectionV53B "latest" $version $commit $asset $url
    }
  } catch {
    Write-CodedPublicDebugV54K "[PUBLIC] M1091V53B channel-status unavailable: $($_.Exception.Message)"
  }

  # M1091V63G2A3_BETA_FAIL_CLOSED_ON_STATUS_OUTAGE
  # Beta may resolve to public/latest only after a successful channel-status
  # response explicitly reports no active beta. A transport failure must not
  # silently change the desired beta lane.
  if ($BetaRequested) { return $null }

  try {
    $cb = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $apiUrl = "https://api.github.com/repos/CodedOnQubic/coded-miner-release/releases/latest?cb=$cb"
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $apiUrl -TimeoutSec 20 -Headers @{ "User-Agent" = "CODED-Windows-Public-Runner" }
    $json = $resp.Content | ConvertFrom-Json
    $version = [string]$json.tag_name
    $commit = ""
    if ($version -match "-([0-9a-fA-F]{7,40})-[0-9]{8}T[0-9]{6}Z$") {
      $commit = $Matches[1].ToLowerInvariant()
    }
    $asset = Get-CodedWindowsAssetNameV53B "latest"
    $url = "$repo/latest/download/$asset"
    return New-CodedWindowsReleaseSelectionV53B "latest" $version $commit $asset $url
  } catch {
    $asset = Get-CodedWindowsAssetNameV53B "latest"
    return New-CodedWindowsReleaseSelectionV53B "latest" "" "" $asset "$repo/latest/download/$asset"
  }
}

$root = Join-Path $base "miner"
New-Item -ItemType Directory -Force $root | Out-Null

# M1091V63G2A3_PERSIST_DESIRED_CHANNEL
$script:CodedDesiredChannel = if ($script:CodedBetaRequested) { "beta" } else { "latest" }
$script:CodedDesiredChannelPath = Join-Path $root "desired-channel.txt"
$script:CodedDesiredChannel | Set-Content -Path $script:CodedDesiredChannelPath -Encoding ASCII

$script:CodedReleaseSelection = Get-CodedWindowsReleaseSelectionV53B -BetaRequested:$script:CodedBetaRequested

if (!$script:CodedReleaseSelection) {
  $cachedChannel = $script:CodedDesiredChannel
  $resolvedChannelPath = Join-Path $root "resolved-channel.txt"

  if ($script:CodedBetaRequested -and (Test-Path $resolvedChannelPath)) {
    try {
      $remembered = (Get-Content $resolvedChannelPath -Raw).Trim().ToLowerInvariant()
      if ($remembered -in @("beta", "latest")) {
        $cachedChannel = $remembered
      }
    } catch {}
  }

  $cachedDir = Join-Path $root $cachedChannel
  $cachedManifest = Join-Path $cachedDir "release_manifest.json"

  if (Test-Path $cachedManifest) {
    try {
      $cached = Get-Content $cachedManifest -Raw | ConvertFrom-Json

      $cachedCommit = [string]$cached.commit
      if ($cached.source_commit) {
        $cachedCommit = [string]$cached.source_commit
      }

      $cachedVersion = [string]$cached.version
      if ($cached.asset_version) {
        $cachedVersion = [string]$cached.asset_version
      }

      $cachedAsset = Get-CodedWindowsAssetNameV53B $cachedChannel

      $script:CodedReleaseSelection =
        New-CodedWindowsReleaseSelectionV53B `
          $cachedChannel `
          $cachedVersion `
          $cachedCommit `
          $cachedAsset `
          ""

      Write-Host (
        "Release status unavailable; using cached " +
        $cachedChannel +
        " installation."
      )
    } catch {}
  }
}

if (!$script:CodedReleaseSelection) {
  if ($script:CodedBetaRequested) {
    throw "Beta status unavailable and no cached beta/latest resolution exists. Refusing silent public fallback."
  }

  $script:CodedReleaseSelection =
    New-CodedWindowsReleaseSelectionV53B `
      "latest" `
      "" `
      "" `
      "coded-miner-windows-amd64-latest.tar.gz" `
      "https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-windows-amd64-latest.tar.gz"
}
$script:CodedEffectiveChannel = [string]$script:CodedReleaseSelection.Channel
if (!$script:CodedEffectiveChannel) { $script:CodedEffectiveChannel = "latest" }

$dir = Join-Path $root $script:CodedEffectiveChannel
$tgz = Join-Path $root $script:CodedReleaseSelection.Asset
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

# M1091V63G2A3_VALIDATED_INSTALL_CACHE
function Get-CodedWindowsManifestInfoV63G2A3 {
  param([string]$InstallDir)

  foreach ($candidate in @(
    (Join-Path $InstallDir "release_manifest.json"),
    (Join-Path $InstallDir "coded-miner\release_manifest.json"),
    (Join-Path $InstallDir "manifest.json"),
    (Join-Path $InstallDir "coded-miner\manifest.json")
  )) {
    if (!(Test-Path $candidate)) {
      continue
    }

    try {
      $manifest =
        Get-Content $candidate -Raw |
        ConvertFrom-Json

      $commit =
        [string]$manifest.commit

      if ($manifest.source_commit) {
        $commit =
          [string]$manifest.source_commit
      }

      $version =
        [string]$manifest.version

      if ($manifest.asset_version) {
        $version =
          [string]$manifest.asset_version
      }

      $platform =
        [string]$manifest.platform

      if (!$platform) {
        $platform =
          [string]$manifest.target
      }

      return @{
        Path =
          $candidate

        Commit =
          $commit.ToLowerInvariant()

        Version =
          $version

        Platform =
          $platform
      }
    } catch {}
  }

  return $null
}

function Test-CodedWindowsInstallReadyV63G2A3 {
  param([string]$InstallDir)

  $manifest =
    Get-CodedWindowsManifestInfoV63G2A3 `
      $InstallDir

  if (!$manifest) {
    return $false
  }

  if (
    [string]$manifest.Platform -and
    ([string]$manifest.Platform).ToLowerInvariant() -notmatch "windows"
  ) {
    return $false
  }

  foreach ($required in @(
    "coded-miner.exe",
    "coded-miner-scalar.exe",
    "coded-miner-avx2.exe",
    "coded-miner-avx512.exe"
  )) {
    if (
      !(
        Test-Path (
          Join-Path $InstallDir $required
        )
      )
    ) {
      return $false
    }
  }

  return $true
}

function Get-CodedFileSha256V63G2A3 {
  param([string]$Path)

  try {
    $sha =
      [Security.Cryptography.SHA256]::Create()

    $stream =
      [IO.File]::OpenRead($Path)

    try {
      return (
        [BitConverter]::ToString(
          $sha.ComputeHash($stream)
        )
      )
        .Replace("-", "")
        .ToLowerInvariant()
    } finally {
      $stream.Dispose()
      $sha.Dispose()
    }
  } catch {
    return ""
  }
}

function Resolve-CodedWindowsPackageRootV63G2A3 {
  param([string]$ExtractDir)

  if (
    Test-Path (
      Join-Path $ExtractDir "release_manifest.json"
    )
  ) {
    return $ExtractDir
  }

  $manifest =
    Get-ChildItem `
      $ExtractDir `
      -Recurse `
      -Filter "release_manifest.json" `
      -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if ($manifest) {
    return $manifest.Directory.FullName
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

  # M1091V63G2A3D_LIGHTWEIGHT_60_SECOND_CHECK
  $sec = 60

  if ($env:CODED_PUBLIC_UPDATE_SEC) {
    try {
      $parsed =
        [int]$env:CODED_PUBLIC_UPDATE_SEC

      if ($parsed -ge 60) {
        $sec =
          $parsed
      }
    } catch {}
  }

  $flag = Join-Path $Root "coded-windows-update-requested.flag"
  $last = Join-Path $Root "coded-windows-last-requested.txt"
  Remove-Item $flag -Force -ErrorAction SilentlyContinue

  Start-Job -Name ("coded-win-autoupdate-" + $Worker) -ScriptBlock {
    param($Root, $CurrentCommit, $ExePath, $Worker, $Sec, $Flag, $Last)

      function Write-CodedPublicDebugV54K([string]$Message) {
        if ($env:CODED_PUBLIC_DEBUG -eq "1") {
          Write-Host $Message
        }
      }
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
          Write-CodedPublicDebugV54K "[PUBLIC] M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE worker=$Worker up_to_date local=$CurrentCommit latest=$latest"
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
          Write-CodedPublicDebugV54K "[PUBLIC] M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE worker=$Worker update_already_requested local=$CurrentCommit latest=$latest age_sec=$age"
          continue
        }

        "$latest $now" | Set-Content -Path $Last -Encoding ASCII
        "update_needed local=$CurrentCommit latest=$latest version=$version" | Set-Content -Path $Flag -Encoding ASCII

        Write-CodedPublicDebugV54K "[PUBLIC] M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE worker=$Worker update_needed local=$CurrentCommit latest=$latest version=$version action=stop_miner"

        Get-Process -ErrorAction SilentlyContinue | Where-Object {
          $_.Path -and ($_.Path -eq $ExePath)
        } | Stop-Process -Force -ErrorAction SilentlyContinue

        break
      }
      catch {
        Write-CodedPublicDebugV54K "[PUBLIC] M1091V39A_WINDOWS_INLINE_SAFE_AUTOUPDATE_ERROR worker=$Worker error=$($_.Exception.Message)"
      }
    }
  } -ArgumentList $Root, $CurrentCommit, $ExePath, $Worker, $sec, $flag, $last | Out-Null
}

# M1091V53B_WINDOWS_BETA_CHANNEL_AUTOUPDATE

# M1091V55F_WINDOWS_SINGLE_AUTUPDATE_JOB_CLEANUP
function Stop-CodedWindowsAutoupdateJobsV55F {
  param(
    [string]$Worker
  )

  try {
    $safeWorker = if ([string]::IsNullOrWhiteSpace($Worker)) { "coded-worker" } else { $Worker }

    # Keep Windows reliable: do not touch miner/analytics processes here.
    # Only remove stale PowerShell background autoupdate jobs for this worker.
    $jobNames = @(
      ("coded-win-channel-autoupdate-" + $safeWorker),
      ("coded-win-autoupdate-" + $safeWorker)
    )

    foreach ($jobName in $jobNames) {
      $jobs = @(Get-Job -Name $jobName -ErrorAction SilentlyContinue)
      foreach ($job in $jobs) {
        try {
          if ($job.State -eq "Running") {
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 250
          }
          Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
          Write-CodedPublicDebugV54K "[PUBLIC] M1091V55F_WINDOWS_SINGLE_AUTUPDATE_JOB_CLEANUP removed_job=$jobName id=$($job.Id) state=$($job.State)"
        } catch {
          Write-CodedPublicDebugV54K "[PUBLIC] M1091V55F_WINDOWS_SINGLE_AUTUPDATE_JOB_CLEANUP remove_failed job=$jobName error=$($_.Exception.Message)"
        }
      }
    }
  } catch {
    Write-CodedPublicDebugV54K "[PUBLIC] M1091V55F_WINDOWS_SINGLE_AUTUPDATE_JOB_CLEANUP outer_error=$($_.Exception.Message)"
  }
}


function Start-CodedWindowsChannelAutoupdateV53B {
  param(
    [string]$Root,
    [string]$CurrentChannel,
    [string]$CurrentCommit,
    [string]$CurrentVersion,
    [string]$ExePath,
    [string]$Worker,
    [bool]$BetaRequested
  )

  # M1091V63G2A3D_LIGHTWEIGHT_60_SECOND_CHECK
  $sec = 60

  if ($env:CODED_PUBLIC_UPDATE_SEC) {
    try {
      $parsed =
        [int]$env:CODED_PUBLIC_UPDATE_SEC

      if ($parsed -ge 60) {
        $sec =
          $parsed
      }
    } catch {}
  }

  # M1091V55F_WINDOWS_SINGLE_AUTUPDATE_JOB_CLEANUP: ensure only one channel-aware autoupdate watcher exists per worker.
  Stop-CodedWindowsAutoupdateJobsV55F -Worker $Worker

  $flag = Join-Path $Root "coded-windows-update-requested.flag"
  $last = Join-Path $Root "coded-windows-last-requested.txt"
  Remove-Item $flag -Force -ErrorAction SilentlyContinue

  Start-Job -Name ("coded-win-channel-autoupdate-" + $Worker) -ScriptBlock {
    param($Root, $CurrentChannel, $CurrentCommit, $CurrentVersion, $ExePath, $Worker, $Sec, $Flag, $Last, $BetaRequested)

      function Write-CodedPublicDebugV54K([string]$Message) {
        if ($env:CODED_PUBLIC_DEBUG -eq "1") {
          Write-Host $Message
        }
      }
    function Enable-CodedTlsJobV53B {
      try { [Net.ServicePointManager]::SecurityProtocol = 3072 } catch {}
    }

    function AssetNameV53B([string]$Channel) {
      if ($Channel -eq "beta") { return "coded-miner-windows-amd64-beta-latest.tar.gz" }
      return "coded-miner-windows-amd64-latest.tar.gz"
    }

    function SelectionV53B([bool]$WantBeta) {
      Enable-CodedTlsJobV53B
      $repo = "https://github.com/CodedOnQubic/coded-miner-release/releases"
      $poolApi = $env:CODED_POOL_API_URL
      if (!$poolApi) { $poolApi = $env:POOL_API_URL }
      if (!$poolApi) { $poolApi = "http://178.104.150.57:4000" }
      $poolApi = $poolApi.TrimEnd("/")

      try {
        $cb = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $resp = Invoke-WebRequest -UseBasicParsing -Uri "$poolApi/admin/release/channel-status?cb=$cb" -TimeoutSec 15 -Headers @{ "User-Agent" = "CODED-Windows-Public-Runner" }
        $j = $resp.Content | ConvertFrom-Json

        if ($WantBeta -and $j.beta -and $j.beta.version -and $j.beta.commit) {
          $asset = AssetNameV53B "beta"
          return @{
            Channel = "beta"
            Version = [string]$j.beta.version
            Commit = ([string]$j.beta.commit).ToLowerInvariant()
            Asset = $asset
            Url = "$repo/download/$([string]$j.beta.version)/$asset"
          }
        }

        if ($j.public_latest -and $j.public_latest.version) {
          $asset = AssetNameV53B "latest"
          $commit = ""
          if ($j.public_latest.commit) { $commit = ([string]$j.public_latest.commit).ToLowerInvariant() }
          return @{
            Channel = "latest"
            Version = [string]$j.public_latest.version
            Commit = $commit
            Asset = $asset
            Url = "$repo/download/$([string]$j.public_latest.version)/$asset"
          }
        }
      } catch {}

      # M1091V63G2A3_BETA_WATCHER_FAIL_CLOSED
      if ($WantBeta) {
        return $null
      }

      try {
        $cb = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $resp = Invoke-WebRequest -UseBasicParsing -Uri "https://api.github.com/repos/CodedOnQubic/coded-miner-release/releases/latest?cb=$cb" -TimeoutSec 20 -Headers @{ "User-Agent" = "CODED-Windows-Public-Runner" }
        $json = $resp.Content | ConvertFrom-Json
        $version = [string]$json.tag_name
        $commit = ""
        if ($version -match "-([0-9a-fA-F]{7,40})-[0-9]{8}T[0-9]{6}Z$") {
          $commit = $Matches[1].ToLowerInvariant()
        }
        return @{
          Channel = "latest"
          Version = $version
          Commit = $commit
          Asset = (AssetNameV53B "latest")
          Url = "$repo/latest/download/$(AssetNameV53B "latest")"
        }
      } catch {
        return @{ Channel = "latest"; Version = ""; Commit = ""; Asset = (AssetNameV53B "latest"); Url = "$repo/latest/download/$(AssetNameV53B "latest")" }
      }
    }

    $currentKey = "$CurrentChannel`:$CurrentCommit`:$CurrentVersion"

    while ($true) {
      Start-Sleep -Seconds $Sec
      try {
        $sel = SelectionV53B $BetaRequested
        if (!$sel) { continue }

        $targetChannel = [string]$sel.Channel
        $targetCommit = [string]$sel.Commit
        $targetVersion = [string]$sel.Version

        if (!$targetChannel) { $targetChannel = "latest" }
        if (!$targetCommit) { continue }

        $targetKey = "$targetChannel`:$targetCommit`:$targetVersion"

        if ($targetKey -eq $currentKey) {
          Write-CodedPublicDebugV54K "[PUBLIC] M1091V53B_WINDOWS_BETA_CHANNEL_AUTOUPDATE worker=$Worker up_to_date key=$currentKey"
          continue
        }

        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $lastKey = ""
        $lastTs = 0

        if (Test-Path $Last) {
          try {
            $parts = (Get-Content $Last -Raw).Trim().Split(" ")
            if ($parts.Length -ge 2) {
              $lastKey = $parts[0]
              $lastTs = [int64]$parts[1]
            }
          } catch {}
        }

        $age = $now - $lastTs
        if ($lastKey -eq $targetKey -and $age -lt 900) {
          Write-CodedPublicDebugV54K "[PUBLIC] M1091V53B_WINDOWS_BETA_CHANNEL_AUTOUPDATE worker=$Worker update_already_requested local=$currentKey target=$targetKey age_sec=$age"
          continue
        }

        "$targetKey $now" | Set-Content -Path $Last -Encoding ASCII
        "update_needed local=$currentKey target=$targetKey version=$targetVersion" | Set-Content -Path $Flag -Encoding ASCII

        Write-CodedPublicDebugV54K "[PUBLIC] M1091V53B_WINDOWS_BETA_CHANNEL_AUTOUPDATE worker=$Worker update_needed local=$currentKey target=$targetKey version=$targetVersion action=stop_miner"

        Get-Process -ErrorAction SilentlyContinue | Where-Object {
          $_.Path -and ($_.Path -eq $ExePath)
        } | Stop-Process -Force -ErrorAction SilentlyContinue

        break
      } catch {
        Write-CodedPublicDebugV54K "[PUBLIC] M1091V53B_WINDOWS_BETA_CHANNEL_AUTOUPDATE_ERROR worker=$Worker error=$($_.Exception.Message)"
      }
    }
  } -ArgumentList $Root, $CurrentChannel, $CurrentCommit, $CurrentVersion, $ExePath, $Worker, $sec, $flag, $last, $BetaRequested | Out-Null
}



# M1091V63G2A3_IDEMPOTENT_VALIDATED_INSTALL
New-Item -ItemType Directory -Force $root | Out-Null

$targetCommit =
  ([string]$script:CodedReleaseSelection.Commit)
    .ToLowerInvariant()

$targetVersion =
  [string]$script:CodedReleaseSelection.Version

$localInfo =
  Get-CodedWindowsManifestInfoV63G2A3 `
    $dir

$installReady =
  Test-CodedWindowsInstallReadyV63G2A3 `
    $dir

$sameTarget =
  $false

if (
  $installReady -and
  $localInfo
) {
  if (
    $targetCommit -and
    $localInfo.Commit -eq $targetCommit
  ) {
    if (
      !$targetVersion -or
      $localInfo.Version -eq $targetVersion
    ) {
      $sameTarget =
        $true
    }
  } elseif (
    !$targetCommit -and
    !$targetVersion
  ) {
    $sameTarget =
      $true
  }
}

if ($sameTarget) {
  Write-Host (
    "Using cached " +
    $script:CodedEffectiveChannel +
    " Windows miner | version=" +
    $localInfo.Version +
    " | commit=" +
    $localInfo.Commit
  )
} else {
  $url =
    [string]$script:CodedReleaseSelection.Url

  if (!$url) {
    if ($installReady) {
      Write-Host (
        "Target URL unavailable; continuing validated local installation."
      )
    } else {
      throw (
        "No release URL and no validated local Windows installation."
      )
    }
  } else {
    $stageRoot =
      Join-Path $root (
        "staging-" +
        [Guid]::NewGuid().ToString("N")
      )

    $stageExtract =
      Join-Path $stageRoot "extract"

    $stageTgz =
      Join-Path `
        $stageRoot `
        $script:CodedReleaseSelection.Asset

    New-Item `
      -ItemType Directory `
      -Force `
      $stageExtract |
    Out-Null

    try {
      Write-Host (
        "Downloading changed " +
        $script:CodedEffectiveChannel +
        " Windows miner..."
      )

      Write-Host (
        "Release channel: " +
        $script:CodedEffectiveChannel +
        " | version=" +
        $targetVersion +
        " | commit=" +
        $targetCommit
      )

      Download-File `
        $url `
        $stageTgz

      $assetSha256 =
        Get-CodedFileSha256V63G2A3 `
          $stageTgz

      if (!$assetSha256) {
        throw (
          "Could not calculate Windows asset SHA256."
        )
      }

      Expand-TarGz `
        $stageTgz `
        $stageExtract

      $packageRoot =
        Resolve-CodedWindowsPackageRootV63G2A3 `
          $stageExtract

      if (!$packageRoot) {
        throw (
          "Downloaded Windows package has no release_manifest.json."
        )
      }

      if (
        !(
          Test-CodedWindowsInstallReadyV63G2A3 `
            $packageRoot
        )
      ) {
        throw (
          "Downloaded Windows package is incomplete or has wrong platform."
        )
      }

      $stageInfo =
        Get-CodedWindowsManifestInfoV63G2A3 `
          $packageRoot

      if (
        $targetCommit -and
        $stageInfo.Commit -ne $targetCommit
      ) {
        throw (
          "Downloaded manifest commit mismatch: " +
          "expected=$targetCommit " +
          "actual=$($stageInfo.Commit)"
        )
      }

      if (
        $targetVersion -and
        $stageInfo.Version -ne $targetVersion
      ) {
        throw (
          "Downloaded manifest version mismatch: " +
          "expected=$targetVersion " +
          "actual=$($stageInfo.Version)"
        )
      }

      @{
        desired_channel =
          $script:CodedDesiredChannel

        resolved_channel =
          $script:CodedEffectiveChannel

        commit =
          $stageInfo.Commit

        version =
          $stageInfo.Version

        asset_sha256 =
          $assetSha256

        installed_at =
          (Get-Date)
            .ToUniversalTime()
            .ToString("o")
      } |
      ConvertTo-Json |
      Set-Content `
        -Path (
          Join-Path `
            $packageRoot `
            "installed-fingerprint.json"
        ) `
        -Encoding ASCII

      $backupDir =
        Join-Path $root (
          "backup-" +
          $script:CodedEffectiveChannel +
          "-" +
          [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        )

      if (Test-Path $backupDir) {
        Remove-Item `
          $backupDir `
          -Recurse `
          -Force `
          -ErrorAction SilentlyContinue
      }

      if (Test-Path $dir) {
        Move-Item `
          $dir `
          $backupDir `
          -Force
      }

      try {
        Move-Item `
          $packageRoot `
          $dir `
          -Force
      } catch {
        if (Test-Path $dir) {
          Remove-Item `
            $dir `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
        }

        if (Test-Path $backupDir) {
          Move-Item `
            $backupDir `
            $dir `
            -Force
        }

        throw
      }

      if (Test-Path $backupDir) {
        Remove-Item `
          $backupDir `
          -Recurse `
          -Force `
          -ErrorAction SilentlyContinue
      }

      Write-Host (
        "Installed validated Windows target sha256=" +
        $assetSha256
      )
    } catch {
      Write-Host (
        "Windows update validation/download failed: " +
        $_.Exception.Message
      )

      if (
        !(
          Test-CodedWindowsInstallReadyV63G2A3 `
            $dir
        )
      ) {
        $fallbackFound =
          $false

        foreach (
          $fallbackChannel in @(
            $script:CodedDesiredChannel,
            "latest",
            "beta"
          )
        ) {
          $fallbackDir =
            Join-Path `
              $root `
              $fallbackChannel

          if (
            Test-CodedWindowsInstallReadyV63G2A3 `
              $fallbackDir
          ) {
            $dir =
              $fallbackDir

            $script:CodedEffectiveChannel =
              $fallbackChannel

            $fallbackFound =
              $true

            Write-Host (
              "Continuing previous validated " +
              $fallbackChannel +
              " installation."
            )

            break
          }
        }

        if (!$fallbackFound) {
          throw
        }
      } else {
        Write-Host (
          "Continuing previous validated installation."
        )
      }
    } finally {
      if (Test-Path $stageRoot) {
        Remove-Item `
          $stageRoot `
          -Recurse `
          -Force `
          -ErrorAction SilentlyContinue
      }
    }
  }
}

$installedInfo =
  Get-CodedWindowsManifestInfoV63G2A3 `
    $dir

if (!$installedInfo) {
  throw (
    "Installed Windows release manifest unavailable."
  )
}

$CurrentCommit =
  $installedInfo.Commit

$CurrentVersion =
  $installedInfo.Version

$script:CodedResolvedChannelPath =
  Join-Path $root "resolved-channel.txt"

$script:CodedEffectiveChannel |
Set-Content `
  -Path $script:CodedResolvedChannelPath `
  -Encoding ASCII

$env:CODED_RELEASE_CHANNEL =
  $script:CodedEffectiveChannel

$env:CODED_RELEASE_STATUS =
  $script:CodedEffectiveChannel

$env:CODED_RELEASE_COMMIT =
  $CurrentCommit

$env:CODED_RELEASE_VERSION =
  $CurrentVersion

$env:CODED_RELEASE_MANIFEST =
  $installedInfo.Path

Write-Host (
  "Current release channel: " +
  $script:CodedEffectiveChannel
)

Write-Host (
  "Current release commit: " +
  $CurrentCommit
)

Write-Host (
  "Current release version: " +
  $CurrentVersion
)

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

# M1091V44E_CANONICAL_RUN_START_ENV
if (-not $env:CODED_RUN_STARTED_AT) {
  $env:CODED_RUN_STARTED_AT = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}
if (-not $env:CODED_RUN_ID) {
  $safeWorkerForRun = if ($Worker) { $Worker } elseif ($env:CODED_WORKER_NAME) { $env:CODED_WORKER_NAME } elseif ($env:WORKER_NAME) { $env:WORKER_NAME } else { $env:COMPUTERNAME }
  $safeWorkerForRun = ([string]$safeWorkerForRun) -replace '[^A-Za-z0-9_.-]', ''
  $env:CODED_RUN_ID = "RUN_${safeWorkerForRun}_$($env:CODED_RUN_STARTED_AT -replace '[-:]','' -replace '\.\d+','')"
}

$env:CODED_PLATFORM = "windows-amd64"
$env:CODED_KERNEL_BACKEND = $selected
$env:CODED_BACKEND = $selected
$env:CODED_POOL = $Pool
$env:CODED_WALLET = $Wallet
$env:CODED_WORKER = $Worker
$env:CODED_WORKER_NAME = $Worker

Send-CodedReleaseStatusV43Y -InstallDir $dir -Worker $Worker -Backend $selected
$env:CODED_RIG_ID = $Worker
# M1091V44F_CLEAN_CANONICAL_RUN_ID
if (-not $env:CODED_RUN_ID) {
  $env:CODED_RUN_ID = $runId
} else {
  $runId = $env:CODED_RUN_ID
}
$env:CODED_THREADS = "$Threads"
$env:CODED_ANALYTICS = "YES"
$env:CODED_ANALYTICS_ENABLED = "1"
$env:CODED_ANALYTICS_FRAME_SEC = "5"
$env:CODED_LOG_FILE = $log
$env:CODED_ANALYTICS_LOG = $log
$env:CODED_ANALYTICS_API = if ($env:CODED_ANALYTICS_API) { $env:CODED_ANALYTICS_API } else { "https://api.codedonqubic.com" }
$env:CODED_ANALYTICS_TOKEN = if ($env:CODED_ANALYTICS_TOKEN) { $env:CODED_ANALYTICS_TOKEN } else { "coded_analytics_ingest_2026_secure_token" }

Write-CodedWindowsAnalytics $analytics
Start-CodedWindowsChannelAutoupdateV53B -Root $root -CurrentChannel $script:CodedEffectiveChannel -CurrentCommit $CurrentCommit -CurrentVersion $CurrentVersion -ExePath $exe -Worker $Worker -BetaRequested:$script:CodedBetaRequested


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


# M1091V54D_WINDOWS_CLEAN_SINGLE_RUNNER
function Stop-CodedWindowsDuplicateRunnersV54D {
  param([string]$Worker)

  try {
    $escapedWorker = [regex]::Escape([string]$Worker)

    Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | Where-Object {
      $_.ProcessId -ne $PID -and
      $_.Name -match "powershell" -and
      $_.CommandLine -and
      (
        $_.CommandLine -match "\\r\.ps1" -or
        $_.CommandLine -match "run\.ps1"
      ) -and
      $_.CommandLine -notmatch "coded-windows-analytics\.ps1" -and
      ($escapedWorker -eq "" -or $_.CommandLine -match $escapedWorker)
    } | ForEach-Object {
      Write-CodedPublicDebugV54K "[PUBLIC] M1091V54D stopping duplicate CODED runner pid=$($_.ProcessId)"
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
  } catch {
    Write-CodedPublicDebugV54K "[PUBLIC] M1091V54D duplicate runner cleanup skipped: $($_.Exception.Message)"
  }
}

Stop-CodedWindowsDuplicateRunnersV54D -Worker $Worker

# M1091V54C_WINDOWS_SINGLE_SESSION_RESTART_CLEANUP
function Stop-CodedWindowsStaleAnalyticsV54C {
  param([string]$Worker)

  try {
    $escapedWorker = [regex]::Escape([string]$Worker)

    Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | Where-Object {
      $_.ProcessId -ne $PID -and
      $_.Name -match "powershell" -and
      $_.CommandLine -and
      $_.CommandLine -match "coded-windows-analytics\.ps1" -and
      ($escapedWorker -eq "" -or $_.CommandLine -match $escapedWorker)
    } | ForEach-Object {
      Write-CodedPublicDebugV54K "[PUBLIC] M1091V54C stopping stale analytics process pid=$($_.ProcessId)"
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
  } catch {
    Write-CodedPublicDebugV54K "[PUBLIC] M1091V54C stale analytics cleanup skipped: $($_.Exception.Message)"
  }
}

Stop-CodedWindowsStaleAnalyticsV54C -Worker $Worker


Write-CodedPublicBrand
Show-CodedPublicBootLoader "Neural network training online"
Start-Process powershell -WindowStyle Hidden -ArgumentList @(
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
  "-RunId",$runId,
  "-ReleaseChannel",$env:CODED_RELEASE_CHANNEL,
  "-ReleaseCommit",$env:CODED_RELEASE_COMMIT,
  "-ReleaseVersion",$env:CODED_RELEASE_VERSION
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
    Write-Host "CODED Miner update requested. Restarting public runner channel-safe..."
    Remove-Item $updateFlag -Force -ErrorAction SilentlyContinue

    $self = $PSCommandPath
    if (-not $self) { $self = $MyInvocation.MyCommand.Path }

    if ($self -and (Test-Path $self)) {
        # M1091V54J: Windows PowerShell 5 / Windows 8 can mis-bind array
        # splatting into script params here. Call the script explicitly instead.
        Write-Host "CODED update applied. Restarting miner..."

        if ($script:CodedBetaRequested) {
          & $self -Wallet $Wallet -Worker $Worker -Pool $Pool -Backend $Backend -Threads $Threads -Beta
          exit $LASTEXITCODE
        } else {
          & $self -Wallet $Wallet -Worker $Worker -Pool $Pool -Backend $Backend -Threads $Threads
          exit $LASTEXITCODE
        }
    }
  }

  Write-Host "CODED Miner process ended."
}
