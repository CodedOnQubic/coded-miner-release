param(
  [string]$Wallet = $env:CODED_WALLET,
  [string]$Worker = $env:CODED_WORKER,
  [int]$Threads = 0,
  [ValidateSet("auto","scalar","avx2","avx512","cuda")]
  [string]$Backend = "auto",
  [string]$Pool = $env:CODED_POOL,
  [switch]$Beta,
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$ExtraArgs
)

# M1091V70_RUNTIME_POLICY_AUTHORITY_V1
# Windows counterpart to run.sh policy authority. Desired startup policy is
# resolved before the proven runner performs AUTO detection. Execution labels
# remain outputs of the productive miner and are never written by this wrapper.

$ErrorActionPreference = "Stop"
$CodedPublicRunnerBaseCommit = "5e898b60779ea163b07bb44dd7a3e1186b414f8b"
$CodedPublicRunnerBaseUrl = "https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/$CodedPublicRunnerBaseCommit/run.ps1"
$env:CODED_RUNTIME_POLICY_SCHEMA = "coded.runtime.policy.v1"

function Enable-CodedV70Tls {
  try { [Net.ServicePointManager]::SecurityProtocol = 3072 } catch {}
}

function Get-CodedV70SafeIdentity([string]$Value) {
  if (!$Value) { return "coded-worker" }
  $safe = ([string]$Value) -replace '[^A-Za-z0-9_.-]', ''
  if (!$safe) { return "coded-worker" }
  if ($safe.Length -gt 96) { $safe = $safe.Substring(0,96) }
  return $safe
}

function Get-CodedV70RuntimePolicy {
  param(
    [string]$RigId,
    [string]$WorkerName
  )

  $poolApi = $env:CODED_POOL_API_URL
  if (!$poolApi) { $poolApi = $env:POOL_API_URL }
  if (!$poolApi) { $poolApi = $env:CODED_POOL_API_BASE }
  if (!$poolApi) { $poolApi = "http://178.104.150.57:4000" }
  $poolApi = ([string]$poolApi).TrimEnd("/")
  if ($poolApi.ToLowerInvariant().EndsWith("/analytics")) {
    $poolApi = $poolApi.Substring(0, $poolApi.Length - 10)
  }

  $policyUrl = $env:CODED_RUNTIME_POLICY_URL
  if (!$policyUrl) { $policyUrl = "$poolApi/analytics2/runtime-policy" }

  $parts = @()
  if ($RigId) { $parts += "rig_id=$([Uri]::EscapeDataString([string]$RigId))" }
  if ($WorkerName) { $parts += "worker_name=$([Uri]::EscapeDataString([string]$WorkerName))" }
  if ($parts.Count -eq 0) { return $null }

  Enable-CodedV70Tls
  try {
    $wc = New-Object Net.WebClient
    $wc.Headers.Add("User-Agent", "CODED-Windows-Runtime-Policy-V70")
    $json = $wc.DownloadString($policyUrl + "?" + ($parts -join "&"))
    if (!$json) { return $null }
    return ($json | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Test-CodedV70PolicyContract($Policy) {
  if (!$Policy) { return $false }
  if ($Policy.ok -ne $true) { return $false }
  if ([string]$Policy.schema -ne "coded.runtime.policy.v1") { return $false }
  return $true
}

# Resolve worker early so policy lookup occurs before any AUTO detector in the
# proven runner. This is the same prompt the delegated runner would otherwise use.
if (-not $Worker) {
  if ($env:CODED_WORKER_NAME) { $Worker = $env:CODED_WORKER_NAME }
  elseif ($env:WORKER_NAME) { $Worker = $env:WORKER_NAME }
  elseif ($env:RIG_NAME) { $Worker = $env:RIG_NAME }
}
if (-not $Worker) { $Worker = Read-Host "Worker name" }

$rigId = $env:CODED_RIG_ID
if (!$rigId) { $rigId = $env:RIG_ID }
if (!$rigId) { $rigId = $Worker }

$cacheBase = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "CODED\runtime-policy" } else { Join-Path $env:TEMP "CODED-runtime-policy" }
New-Item -ItemType Directory -Force $cacheBase | Out-Null
$cacheFile = Join-Path $cacheBase ((Get-CodedV70SafeIdentity $rigId) + ".json")

$policy = Get-CodedV70RuntimePolicy -RigId $rigId -WorkerName $Worker
$policySource = "live"
if (Test-CodedV70PolicyContract $policy) {
  if ($policy.managed -eq $true) {
    try { $policy | ConvertTo-Json -Depth 8 -Compress | Set-Content -Path $cacheFile -Encoding ASCII } catch {}
  } else {
    Remove-Item $cacheFile -Force -ErrorAction SilentlyContinue
  }
} else {
  $policy = $null
  if (Test-Path $cacheFile) {
    try {
      $cached = Get-Content $cacheFile -Raw | ConvertFrom-Json
      if ((Test-CodedV70PolicyContract $cached) -and $cached.managed -eq $true) {
        $policy = $cached
        $policySource = "cache"
      }
    } catch {}
  }
}

$managedPolicy = $false
if ($policy -and $policy.managed -eq $true) {
  $managedPolicy = $true
  if ($policy.valid -ne $true) {
    throw "Managed CODED runtime policy is inconsistent; refusing AUTO/backend fallback."
  }

  $policyBackend = ([string]$policy.policy.backend).Trim().ToLowerInvariant()
  if ($policyBackend -notin @("auto","scalar","avx2","avx512","cuda")) {
    throw "Managed CODED runtime policy backend '$policyBackend' is unsupported on Windows."
  }

  $requestedBackend = ([string]$policy.policy.requested_backend).Trim().ToLowerInvariant()
  if ($requestedBackend -and $requestedBackend -ne $policyBackend) {
    throw "Managed CODED runtime policy request/backend mismatch."
  }

  $Backend = $policyBackend
  $env:BACKEND = $policyBackend
  $env:CODED_HARDWARE_TUNE_REQUESTED_BACKEND = $policyBackend
  $env:CODED_PUBLIC_BACKEND_REQUEST_SNAPSHOT = $policyBackend
  $env:CODED_RUNTIME_POLICY_MANAGED = "1"
  $env:CODED_RUNTIME_POLICY_VALID = "1"
  $env:CODED_RUNTIME_POLICY_SOURCE = $policySource
  $env:CODED_RUNTIME_POLICY_AUTHORITY = "miner_default_profiles"
  $env:CODED_RUNTIME_POLICY_BACKEND = $policyBackend
  $env:CODED_RUNTIME_POLICY_PROFILE = [string]$policy.policy.profile_version
  if ($policy.matched.rig_id) { $env:CODED_RUNTIME_POLICY_RIG_ID = [string]$policy.matched.rig_id }
  if ($policy.matched.worker_name) { $env:CODED_RUNTIME_POLICY_WORKER_NAME = [string]$policy.matched.worker_name }

  # Managed backend authority cannot be undone by shorthand arguments in the
  # delegated runner. Non-backend arguments remain untouched and ordered.
  $filtered = @()
  foreach ($arg in @($ExtraArgs)) {
    if (!$arg) { continue }
    $token = ([string]$arg).Trim().ToLowerInvariant()
    if ($token -in @("-auto","--auto","-scalar","--scalar","-avx2","--avx2","-avx512","--avx512","-cuda","--cuda")) { continue }
    if ($token -match '^--?backend=') { continue }
    $filtered += [string]$arg
  }
  $ExtraArgs = $filtered
}

# Fetch a fixed, previously proven runner instead of recursively invoking main.
# Its self-update path re-enters this wrapper only on a fresh public invocation;
# during the same Windows update cycle it preserves the already resolved Backend.
$delegate = Join-Path $env:TEMP ("coded-public-runner-" + $CodedPublicRunnerBaseCommit + ".ps1")
$needDownload = $true
if (Test-Path $delegate) {
  try {
    $head = Get-Content $delegate -Raw
    if ($head -match 'M1091V63G2A3E_WINDOWS8_SAFE_RELEASE_IDENTITY_UPDATE') { $needDownload = $false }
  } catch {}
}
if ($needDownload) {
  Enable-CodedV70Tls
  $tmp = $delegate + ".tmp"
  $wc = New-Object Net.WebClient
  $wc.Headers.Add("User-Agent", "CODED-Windows-Runtime-Policy-V70")
  $wc.DownloadFile($CodedPublicRunnerBaseUrl + "?cb=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), $tmp)
  $verify = Get-Content $tmp -Raw
  if ($verify -notmatch 'M1091V63G2A3E_WINDOWS8_SAFE_RELEASE_IDENTITY_UPDATE') {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    throw "Pinned CODED Windows runner contract missing."
  }
  Move-Item -Force $tmp $delegate
}

$params = @{
  Wallet = $Wallet
  Worker = $Worker
  Threads = $Threads
  Backend = $Backend
  Pool = $Pool
}
if ($Beta) { $params["Beta"] = $true }
if ($ExtraArgs -and $ExtraArgs.Count -gt 0) { $params["ExtraArgs"] = [string[]]$ExtraArgs }

& $delegate @params
exit $LASTEXITCODE
