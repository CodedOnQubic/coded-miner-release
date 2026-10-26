param(
  [string]$Wallet=$env:CODED_WALLET,
  [string]$Worker=$env:CODED_WORKER,
  [ValidateRange(0,1024)][int]$Threads=0,
  [ValidateSet('auto','avx2','avx512','cuda','avx2+cuda','avx512+cuda')][string]$Backend='auto',
  [string]$Pool='pool.codedonqubic.com:7777',
  [switch]$Beta,
  [string]$QualificationPlan,
  [string]$QualificationPlanSha256,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$ExtraArgs
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
# CODED_WINDOWS_EXPLICIT_QA_GUARD_V1 (identical in entrypoint and bootstrap)
function Assert-QualificationPath([string]$Path) {
  $full=[IO.Path]::GetFullPath($Path)
  if (!$full.StartsWith($qa.local_app_data+'\',[StringComparison]::OrdinalIgnoreCase) -and $full -ne $qa.local_app_data) { throw 'QA path escaped its private application directory.' }
  $cursor=$full
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      $part=Get-Item -LiteralPath $cursor -Force
      if ($part.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'QA reparse point rejected.' }
    }
    $cursor=Split-Path -Parent $cursor
  }
}
function Read-QualificationPlan([string]$Path,[string]$Expected,[string]$Pool) {
  $inheritedPath=$env:CODED_WINDOWS_QUALIFICATION_PLAN
  $inheritedSha=$env:CODED_WINDOWS_QUALIFICATION_PLAN_SHA256
  if (!$Path -and !$Expected) {
    if ($inheritedPath -or $inheritedSha) { throw 'QA context requires explicit transitive plan arguments; public fallback rejected.' }
    return $null
  }
  if (!$Path -or $Expected -cnotmatch '^[0-9a-f]{64}$' -or ($inheritedPath -and !$inheritedSha) -or ($inheritedSha -and !$inheritedPath) `
      -or ($inheritedPath -and ($inheritedPath -cne $Path -or $inheritedSha -cne $Expected))) { throw 'Complete identical QA plan binding required.' }
  $full=[IO.Path]::GetFullPath($Path)
  $item=Get-Item -LiteralPath $full -Force
  if ($full -ne $Path -or $item.PSIsContainer -or $item.Length -le 0 -or $item.Length -gt 32768) { throw 'Canonical bounded QA plan file required.' }
  $cursor=$full
  while ($cursor) {
    $part=Get-Item -LiteralPath $cursor -Force
    if ($part.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'QA plan reparse point rejected.' }
    $cursor=Split-Path -Parent $cursor
  }
  $raw=[IO.File]::ReadAllBytes($full)
  $algorithm=[Security.Cryptography.SHA256]::Create()
  try { $actual=-join($algorithm.ComputeHash($raw)|ForEach-Object{$_.ToString('x2')}) } finally { $algorithm.Dispose() }
  if ($actual -cne $Expected -or @($raw|Where-Object{$_ -ne 10 -and ($_ -lt 32 -or $_ -gt 126)}).Count) { throw 'QA plan bytes or ASCII/LF encoding mismatch.' }
  $lines=[Text.Encoding]::ASCII.GetString($raw).Split([char]10)
  if ($lines[0] -cne 'coded.windows.bootstrap-qualification.v1' -or $lines[-1] -cne '') { throw 'Explicit QA plan schema and final LF required.' }
  $allowed=@('window_id','machine_guid','starts_unix','expires_unix','local_app_data','api_base','asset_base','pool','public_entrypoint_sha256','platform_bootstrap_sha256')
  $fields=@{};$packages=@{}
  for ($i=1;$i -lt $lines.Length-1;$i++) {
    $pair=$lines[$i].Split([char[]]'=',2)
    if ($pair.Count -ne 2 -or !$pair[1] -or $pair[0] -cnotmatch '^[a-z][a-z0-9_]*$') { throw 'Canonical QA record required.' }
    $key=$pair[0];$value=$pair[1]
    if ($key -ceq 'package') {
      $parts=$value.Split([char]' ')
      if ($parts.Count -ne 3 -or $parts[0] -cnotmatch '^[A-Za-z0-9_.+-]{1,200}$' -or $parts[1] -cnotmatch '^[0-9a-f]{40}$' `
          -or !$parts[0].Contains($parts[1]) -or $parts[2] -cnotmatch '^[0-9a-f]{64}$' -or $packages.ContainsKey($parts[0])) { throw 'Unique exact QA package version/source/digest required.' }
      $packages[$parts[0]]=@{source_commit=$parts[1];archive_sha256=$parts[2]}
    } else {
      if ($allowed -cnotcontains $key -or $fields.ContainsKey($key)) { throw 'Unknown or duplicate QA field rejected.' }
      $fields[$key]=$value
    }
  }
  if ($fields.Count -ne $allowed.Count -or $packages.Count -lt 1 -or $packages.Count -gt 4 `
      -or @($packages.Values|ForEach-Object{$_.source_commit}|Select-Object -Unique).Count -ne $packages.Count) { throw 'Complete QA field/package coverage required.' }
  foreach ($key in $allowed) { if (!$fields.ContainsKey($key)) { throw 'Missing QA field.' } }
  $machine=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid).MachineGuid.ToLowerInvariant()
  if ($fields.window_id -cnotmatch '^[a-z0-9][a-z0-9-]{3,48}$' -or $fields.machine_guid -cnotmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' `
      -or $fields.machine_guid -cne $machine) { throw 'QA actual machine identity mismatch.' }
  if ($fields.starts_unix -cnotmatch '^[0-9]{1,11}$' -or $fields.expires_unix -cnotmatch '^[0-9]{1,11}$') { throw 'Integer QA UTC window required.' }
  $start=[long]$fields.starts_unix;$end=[long]$fields.expires_unix;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if ($end -le $start -or $end-$start -gt 1800 -or $now -lt $start -or $now -ge $end) { throw 'Current bounded QA window required.' }
  if ($fields.local_app_data -cnotmatch '^[A-Z]:\\coded-qa\\onboarding-[a-z0-9-]{4,48}$' -or $fields.local_app_data -ne $env:LOCALAPPDATA `
      -or $full -ne (Join-Path $fields.local_app_data 'qualification.plan') `
      -or !(Test-Path -LiteralPath $fields.local_app_data -PathType Container)) { throw 'Explicit private QA LOCALAPPDATA and plan path required.' }
  foreach ($key in @('api_base','asset_base')) {
    if ($fields[$key] -cnotmatch '^http://(127\.0\.0\.1|\[::1\]):[1-9][0-9]{0,4}$' -or ([Uri]$fields[$key]).Port -gt 65535) { throw 'Numeric loopback-only QA transport required.' }
  }
  if ($fields.pool -cnotmatch '^(127\.0\.0\.1|\[::1\]):[1-9][0-9]{0,4}$' -or ([Uri]('tcp://'+$fields.pool)).Port -gt 65535 `
      -or $fields.pool -cne $Pool -or $fields.api_base -cne $env:CODED_POOL_API_BASE `
      -or $env:CODED_ALLOW_FEATURE_VALIDATION -cne '1' -or $env:CODED_ANT_V3_LIVE_SUBMIT -cne '0') { throw 'QA requires explicit NoSubmit, local Analytics and the exact local pool.' }
  if ($env:NO_PROXY -cne '*' -or $env:HTTP_PROXY -or $env:HTTPS_PROXY -or $env:ALL_PROXY) { throw 'QA proxy fallback rejected; explicit NO_PROXY=* and no proxy variables required.' }
  foreach ($key in @('public_entrypoint_sha256','platform_bootstrap_sha256')) { if ($fields[$key] -cnotmatch '^[0-9a-f]{64}$') { throw 'QA launcher pins required.' } }
  $env:CODED_WINDOWS_QUALIFICATION_PLAN=$Path;$env:CODED_WINDOWS_QUALIFICATION_PLAN_SHA256=$Expected
  $fields.packages=$packages;$fields.plan_path=$Path;$fields.plan_sha256=$Expected
  return $fields
}
function Qualification-Timeout([int]$Maximum) {
  if (!$qa) { return $Maximum }
  $null=Read-QualificationPlan $QualificationPlan $QualificationPlanSha256 $Pool
  $remaining=[long]$qa.expires_unix-[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-1
  if ($remaining -lt 1) { throw 'QA network budget expired.' }
  return [int][Math]::Min($Maximum,$remaining)
}
# END_CODED_WINDOWS_EXPLICIT_QA_GUARD_V1

$qa=Read-QualificationPlan $QualificationPlan $QualificationPlanSha256 $Pool
if ($qa) { [Net.WebRequest]::DefaultWebProxy=$null }
if ($ExtraArgs.Count) { throw 'Unsupported arguments. Use -Backend auto, avx2, avx512, cuda, avx2+cuda or avx512+cuda; retired -gpu/-gpu_only are removed.' }
if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitProcess) { throw 'Windows x64 required.' }
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$commit='843b0630fcc51a6b349257324f389fbc96ceb82c'
$expected='d20a5825a54ff5e7672410349549b15c6be2d555d586010e5da4dd6fac022339'
if ($qa) {
  # QA must never fall through to the old bootstrap without these guards.
  $expected='b0abe263aaa02f1d400ecf8c825d478db8ed617995105cd49de2899f1733ee17'
  if (!$PSCommandPath -or (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $qa.public_entrypoint_sha256 `
      -or $qa.platform_bootstrap_sha256 -cne $expected) { throw 'Exact QA entrypoint/bootstrap bytes required.' }
}
$base=Join-Path $env:LOCALAPPDATA 'CODED\bootstrap'
if ($qa) { Assert-QualificationPath $base }
New-Item -ItemType Directory -Force -Path $base | Out-Null
$helper=Join-Path $base ('run-windows-'+$expected+'.ps1')
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
if (!(Test-Path -LiteralPath $helper)) {
  $temporary=Join-Path $base ('.download-'+[Guid]::NewGuid().ToString('N'))
  $url='https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/'+$commit+'/run-windows.ps1'
  if ($qa) {
    Assert-QualificationPath $temporary
    $url=$qa.asset_base+'/bootstrap/run-windows-'+$expected+'.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temporary -TimeoutSec (Qualification-Timeout 30) -MaximumRedirection 0
  } else {
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temporary -TimeoutSec 30
  }
  if ((Sha $temporary) -ne $expected) { throw 'Pinned Windows bootstrap integrity failed.' }
  try { [IO.File]::Move($temporary,$helper) } catch { if (!(Test-Path -LiteralPath $helper)) { throw } }
}
if ((Sha $helper) -ne $expected) { throw 'Cached Windows bootstrap integrity failed; preserve for inspection.' }
if ($qa) { Assert-QualificationPath $helper;$null=Read-QualificationPlan $QualificationPlan $QualificationPlanSha256 $Pool }
$params=@{Wallet=$Wallet;Worker=$Worker;Threads=$Threads;Backend=$Backend;Pool=$Pool;Beta=$Beta}
if ($qa) { $params.QualificationPlan=$QualificationPlan;$params.QualificationPlanSha256=$QualificationPlanSha256 }
& $helper @params
exit $LASTEXITCODE
