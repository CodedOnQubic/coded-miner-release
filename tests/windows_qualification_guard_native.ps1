param(
  [Parameter(Mandatory=$true)][string]$Entrypoint,
  [Parameter(Mandatory=$true)][string]$EntrypointSha256,
  [Parameter(Mandatory=$true)][string]$Bootstrap,
  [Parameter(Mandatory=$true)][string]$BootstrapSha256,
  [Parameter(Mandatory=$true)][string]$Output
)
# Native parser/guard controls only. Never execute either launcher body.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitProcess -or $PSVersionTable.PSVersion.Major -ne 5) {
  throw 'Actual Windows x64 PowerShell 5 required.'
}
if (Test-Path -LiteralPath $Output) { throw 'Preserve an existing control receipt.' }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
$pinnedRaw=@{}
foreach ($item in @(@($Entrypoint,$EntrypointSha256),@($Bootstrap,$BootstrapSha256))) {
  $raw=[IO.File]::ReadAllBytes($item[0]);$algorithm=[Security.Cryptography.SHA256]::Create()
  try { $actual=-join($algorithm.ComputeHash($raw)|ForEach-Object{$_.ToString('x2')}) } finally { $algorithm.Dispose() }
  if ($item[1] -cnotmatch '^[0-9a-f]{64}$' -or $actual -cne $item[1]) { throw 'Externally pinned launcher bytes required.' }
  $pinnedRaw[$item[0]]=$raw
}
$keys=@('LOCALAPPDATA','CODED_ALLOW_FEATURE_VALIDATION','CODED_ANT_V3_LIVE_SUBMIT','CODED_POOL_API_BASE',
        'CODED_WINDOWS_QUALIFICATION_PLAN','CODED_WINDOWS_QUALIFICATION_PLAN_SHA256',
        'NO_PROXY','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY')
$saved=@{};foreach ($key in $keys) { $saved[$key]=[Environment]::GetEnvironmentVariable($key,'Process') }
$private=Join-Path 'C:\coded-qa' ('onboarding-controls-'+[Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $private) { throw 'Fresh private control directory required.' }
New-Item -ItemType Directory -Path $private | Out-Null
$planPath=Join-Path $private 'qualification.plan'
$machine=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid).MachineGuid.ToLowerInvariant()
$start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-1
$end=$start+120
$source='a'*40
$records=@('coded.windows.bootstrap-qualification.v1','window_id=native-guard-controls',
  ('machine_guid='+$machine),('starts_unix='+$start),('expires_unix='+$end),('local_app_data='+$private),
  'api_base=http://127.0.0.1:9000','asset_base=http://127.0.0.1:9001','pool=127.0.0.1:7777',
  ('public_entrypoint_sha256='+$EntrypointSha256),('platform_bootstrap_sha256='+$BootstrapSha256),
  ('package=controls-'+$source+' '+$source+' '+('b'*64)))
$canonical=($records -join "`n")+"`n"
$results=New-Object 'System.Collections.Generic.List[object]'
function Reset-Context {
  $env:LOCALAPPDATA=$private;$env:CODED_ALLOW_FEATURE_VALIDATION='1';$env:CODED_ANT_V3_LIVE_SUBMIT='0'
  $env:CODED_POOL_API_BASE='http://127.0.0.1:9000';$env:NO_PROXY='*'
  foreach ($key in @('CODED_WINDOWS_QUALIFICATION_PLAN','CODED_WINDOWS_QUALIFICATION_PLAN_SHA256','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY')) {
    [Environment]::SetEnvironmentVariable($key,$null,'Process')
  }
}
function Check-Rejection([string]$Name,[string]$Text,[string]$ChangeKey='', [string]$ChangeValue='') {
  Reset-Context
  [IO.File]::WriteAllBytes($planPath,[Text.Encoding]::ASCII.GetBytes($Text))
  if ($ChangeKey) { [Environment]::SetEnvironmentVariable($ChangeKey,$ChangeValue,'Process') }
  $rejected=$false
  try { $null=Read-QualificationPlan $planPath (Hash $planPath) '127.0.0.1:7777' } catch { $rejected=$true }
  if (!$rejected) { throw ('Guard accepted negative control: '+$Name) }
  $results.Add(@{launcher=$launcher;control=$Name;rejected=$true})
}
try {
  foreach ($launcher in @($Entrypoint,$Bootstrap)) {
    $tokens=$null;$parseErrors=$null
    # Parse exactly the retained SHA-verified bytes, with no second file read.
    $ast=[Management.Automation.Language.Parser]::ParseInput([Text.Encoding]::UTF8.GetString($pinnedRaw[$launcher]),[ref]$tokens,[ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Native PS5 launcher parse failed.' }
    # Only this exact pinned guard definition is evaluated. No main body,
    # downloader, tar, package Python, native binary or issuer is invoked.
    $functions=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Read-QualificationPlan'},$true))
    if ($functions.Count -ne 1) { throw 'Exactly one QA guard definition required.' }
    . ([ScriptBlock]::Create($functions[0].Extent.Text))
    Reset-Context
    [IO.File]::WriteAllBytes($planPath,[Text.Encoding]::ASCII.GetBytes($canonical))
    $accepted=Read-QualificationPlan $planPath (Hash $planPath) '127.0.0.1:7777'
    if ($accepted.machine_guid -cne $machine -or $accepted.packages.Count -ne 1) { throw 'Positive native guard control failed.' }
    $results.Add(@{launcher=$launcher;control='current-machine-private-loopback-plan';accepted=$true})
    Check-Rejection 'duplicate-field' ($canonical+"pool=127.0.0.1:7777`n")
    Check-Rejection 'unknown-field' ($canonical+"unsafe=true`n")
    Check-Rejection 'CRLF' ($canonical.Replace("`n","`r`n"))
    Check-Rejection 'missing-field' ($canonical.Replace("pool=127.0.0.1:7777`n",''))
    Check-Rejection 'wrong-machine' ($canonical.Replace('machine_guid='+$machine,'machine_guid=00000000-0000-0000-0000-000000000000'))
    Check-Rejection 'expired' ($canonical.Replace('starts_unix='+$start,'starts_unix=1').Replace('expires_unix='+$end,'expires_unix=2'))
    Check-Rejection 'DNS-transport' ($canonical.Replace('http://127.0.0.1:9001','http://localhost:9001'))
    Check-Rejection 'production-transport' ($canonical.Replace('http://127.0.0.1:9001','https://api.codedonqubic.com'))
    Check-Rejection 'live-submit' $canonical 'CODED_ANT_V3_LIVE_SUBMIT' '1'
    Check-Rejection 'missing-feature-opt-in' $canonical 'CODED_ALLOW_FEATURE_VALIDATION' '0'
    Check-Rejection 'proxy-fallback' $canonical 'HTTP_PROXY' 'http://127.0.0.1:8888'
    Check-Rejection 'partial-inherited-context' $canonical 'CODED_WINDOWS_QUALIFICATION_PLAN' $planPath
    Reset-Context
    $env:CODED_WINDOWS_QUALIFICATION_PLAN=$planPath
    $rejected=$false
    try { $null=Read-QualificationPlan '' '' '127.0.0.1:7777' } catch { $rejected=$true }
    if (!$rejected) { throw 'Partial inherited QA context fell through to public mode.' }
    $results.Add(@{launcher=$launcher;control='no-public-fallback';rejected=$true})
  }
  if ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $end) { throw 'Native controls exceeded their deadline.' }
  $receipt=[ordered]@{schema='coded.windows.bootstrap-guard-controls.v1';result='PASS_ACTUAL_PS5_GUARD_ONLY';
    at_utc=[DateTime]::UtcNow.ToString('o');machine_guid=$machine;private_directory=$private;
    entrypoint_sha256=$EntrypointSha256;bootstrap_sha256=$BootstrapSha256;controls=@($results.ToArray());
    network_requests=0;launcher_main_executed=$false;miner_executed=$false;gpu_executed=$false;
    issuer_executed=$false;publication_qualified=$false;real_public_onboarding=$false}
  $json=$receipt|ConvertTo-Json -Depth 8
  $file=[IO.File]::Open($Output,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
  try { $bytes=[Text.Encoding]::UTF8.GetBytes($json+"`n");$file.Write($bytes,0,$bytes.Length);$file.Flush($true) } finally { $file.Dispose() }
  Write-Output $json
} finally {
  foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
  # Retain only this run's plan/directory as evidence; no cache/state cleanup.
}
