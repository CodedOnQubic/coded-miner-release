param(
  [string]$Wallet=$env:CODED_WALLET,
  [string]$Worker=$env:CODED_WORKER,
  [ValidateRange(0,1024)][int]$Threads=0,
  [ValidateSet('auto','avx2','avx512','cuda','avx2+cuda','avx512+cuda')][string]$Backend='auto',
  [string]$Pool='pool.codedonqubic.com:7777',
  [switch]$Beta,
  [string]$QualificationPlan,
  [string]$QualificationPlanSha256,
  [switch]$StageOnly
)
# Stock Windows bootstrap. The verified package supplies its own runtime.
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
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitProcess) { throw 'Windows x64 required.' }
if ($Wallet -notmatch '^[A-Z]{60}$' -or $Worker -notmatch '^[A-Za-z0-9_.-]{1,64}$') { throw 'Valid Wallet and Worker required.' }
$Backend=$Backend.ToLowerInvariant()
if ($Backend -eq 'cuda' -and $Threads -ne 0) { throw 'GPU-only has no CPU thread option.' }
if ($Backend -like '*+cuda' -and $Threads -gt 512) { throw 'Hybrid CPU threads maximum is 512.' }
if (!$PSCommandPath) { throw 'Use the official run.ps1 entrypoint.' }
$channel=if($Beta){'beta'}else{'latest'}
$channelUrl='https://api.codedonqubic.com/admin/release/channel-status'
$releaseApi='https://api.github.com/repos/CodedOnQubic/coded-miner-release/releases/tags'
$downloadBase='https://github.com/CodedOnQubic/coded-miner-release/releases/download'
if ($qa) {
  if (!$PSCommandPath -or (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $qa.platform_bootstrap_sha256) { throw 'Exact QA bootstrap bytes required.' }
  Assert-QualificationPath $PSCommandPath
  $channelUrl=$qa.api_base+'/admin/release/channel-status'
  $releaseApi=$qa.asset_base+'/repos/CodedOnQubic/coded-miner-release/releases/tags'
  $downloadBase=$qa.asset_base+'/releases/download'
}
function Read-Json([string]$Uri) {
  if ($qa) {
    Invoke-RestMethod -UseBasicParsing -Uri $Uri -UserAgent 'CODED-Windows-Qualification' -TimeoutSec (Qualification-Timeout 30) -MaximumRedirection 0
  } else {
    Invoke-RestMethod -UseBasicParsing -Uri $Uri -UserAgent 'CODED-Windows-Public' -TimeoutSec 30
  }
}
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Read-QualificationArchiveHashes([string]$Archive) {
  # Read exact raw bytes through the system tar, without a host Python/toolchain.
  Assert-QualificationPath $Archive
  $capture=Join-Path (Split-Path -Parent $Archive) ('.hashes-'+[Guid]::NewGuid().ToString('N'))
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=(Get-Command tar.exe -ErrorAction Stop).Source
  $info.Arguments='-xOf '+$Archive+' coded-miner/package-sha256.json'
  $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
  $process=New-Object Diagnostics.Process;$process.StartInfo=$info;$started=$false;$file=$null;$copy=$null
  try {
    $file=[IO.File]::Open($capture,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    if (!$process.Start()) { throw 'QA archive reader failed to start.' };$started=$true
    $copy=$process.StandardOutput.BaseStream.CopyToAsync($file);$errors=$process.StandardError.ReadToEndAsync()
    if (!$process.WaitForExit(1000*(Qualification-Timeout 30))) { throw 'QA archive reader timeout.' }
    if (!$copy.Wait(2000) -or !$errors.Wait(2000) -or $process.ExitCode -ne 0) { throw 'QA archive hashes could not be read.' }
    $file.Flush($true);$file.Dispose();$file=$null
    if ((Get-Item -LiteralPath $capture).Length -gt 8388608) { throw 'QA archive hashes exceed bounds.' }
    return @{path=$capture;sha256=(Sha $capture)}
  } catch {
    if ($started -and !$process.HasExited) { $process.Kill();[void]$process.WaitForExit(2000) }
    throw
  } finally {
    if ($copy) { [void]$copy.Wait(2000) }
    if ($file) { $file.Dispose() };$process.Dispose()
  }
}
function Check-Package([string]$Root,[string]$Pin,[string]$Version) {
  $archiveHashes=$null
  if ($qa) {
    Assert-QualificationPath $Root
    $null=Read-QualificationPlan $QualificationPlan $QualificationPlanSha256 $Pool
    $expectedPackage=$qa.packages[$Version]
    $archive=Join-Path (Split-Path -Parent $Root) 'package.tar.gz'
    if (!$expectedPackage -or $expectedPackage.source_commit -cne $Pin -or (Sha $archive) -cne $expectedPackage.archive_sha256) { throw 'QA cache requires the exact reviewed retained archive.' }
    $archiveHashes=Read-QualificationArchiveHashes $archive
    try {
      if ((Sha (Join-Path $Root 'package-sha256.json')) -cne $archiveHashes.sha256) { throw 'QA extracted hash map differs from the reviewed archive.' }
    } finally { Remove-Item -LiteralPath $archiveHashes.path }
  }
  $manifest=Get-Content -LiteralPath (Join-Path $Root 'release_manifest.json') -Raw | ConvertFrom-Json
  if ($manifest.schema -ne 'coded.windows.ant-v1306.v1' -or $manifest.release_profile -ne 'windows-ant-v1306' `
      -or $manifest.source_commit -ne $Pin -or $manifest.commit -ne $Pin -or $manifest.version -ne $Version `
      -or $manifest.branch -ne 'coded-miner-1.0-anthill' -or $manifest.publishable_source -ne $true `
      -or $manifest.publication_authorized -ne $true -or $manifest.runtime_compilation -ne $false `
      -or $manifest.host_python_required -ne $false -or $manifest.population -ne 32 -or $manifest.ann_bytes -ne 1088 `
      -or $manifest.windows_work_state_bank_enabled -ne $true -or $manifest.work_state_bank_reader_version -ne 3 `
      -or $manifest.cuda_abi -ne 3 -or $manifest.cuda_thread_selection -ne 'explicit-per-call-argument') {
    throw 'Qualified native Windows package contract missing.'
  }
  $hashes=Get-Content -LiteralPath (Join-Path $Root 'package-sha256.json') -Raw | ConvertFrom-Json
  $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  $files=@(Get-ChildItem -LiteralPath $Root -Recurse -Force)
  foreach ($file in $files) {
    if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Package reparse point rejected.' }
    if ($file.PSIsContainer) { continue }
    $relative=$file.FullName.Substring($Root.Length+1).Replace('\','/')
    if ($relative -eq 'package-sha256.json') { continue }
    if (!$seen.Add($relative)) { throw 'Duplicate package path.' }
    $property=$hashes.PSObject.Properties[$relative]
    if (!$property -or $property.Value -notmatch '^[0-9a-f]{64}$' -or (Sha $file.FullName) -ne $property.Value) {
      throw ('Package file integrity failed: '+$relative)
    }
  }
  if ($seen.Count -ne @($hashes.PSObject.Properties).Count) { throw 'Incomplete package hash coverage.' }
  foreach ($required in @('python/python.exe','windows_runtime.py','windows_analytics.py','windows_process.py',
      'windows_plan.py','coded-backend-detect.exe','coded-cuda-v1306.dll','coded-public-console.py','task_bpp9000.bin')) {
    if (!$seen.Contains($required)) { throw ('Package runtime file missing: '+$required) }
  }
}
$requestedChannel=$channel
$cacheParent=Join-Path $env:LOCALAPPDATA 'CODED\packages\windows'
if ($qa) { Assert-QualificationPath $cacheParent }
New-Item -ItemType Directory -Force -Path $cacheParent | Out-Null
do {
  if ($qa) { Assert-QualificationPath $cacheParent;$null=Read-QualificationPlan $QualificationPlan $QualificationPlanSha256 $Pool }
  $channel=$requestedChannel
  $metadata=Read-Json $channelUrl
  if ($Beta -and $metadata.beta_disabled.disabled -eq $true) {
    if ($metadata.beta_disabled.commit -notmatch '^[0-9a-f]{40}$' `
        -or $metadata.beta_disabled.commit -ne $metadata.public_latest.commit) {
      throw 'Disabled Beta has no identical promoted Latest.'
    }
    $channel='latest'
  }
  $entry=if($channel -eq 'beta'){$metadata.beta}else{$metadata.public_latest}
  if ($qa) {
    $assetReady=$entry.assets.windows.materialized -is [bool] -and $entry.assets.windows.materialized -eq $true -and $entry.assets.windows.ok -ne $true
    $contractReady=$entry.qualification_contract -ceq 'coded.windows.staged-onboarding.v1' `
      -and $entry.real_public_onboarding -is [bool] -and $entry.real_public_onboarding -eq $false `
      -and !$entry.public_onboarding_contract
    if ($entry.status -cne 'materialized' -or $entry.stage -cne 'bootstrap_qualification') { throw 'QA fixture must describe materialized, unpublished archives.' }
  } else {
    $assetReady=$entry.assets.windows.ok -eq $true
    $contractReady=$entry.public_onboarding_contract -eq 'coded.public.onboarding.v1'
  }
  if (!$entry -or $entry.commit -notmatch '^[0-9a-f]{40}$' -or $entry.version -notmatch '^[A-Za-z0-9_.+-]+$' `
      -or !$entry.version.Contains($entry.commit) -or !$assetReady -or !$contractReady) { throw 'Windows channel is awaiting release qualification.' }
  if ($entry.source_commit -and $entry.source_commit -ne $entry.commit) { throw 'Source/channel mismatch.' }
  if (!$qa) {
    if ($channel -eq 'beta' -and ($entry.status -ne 'completed' -or $entry.stage -ne 'complete')) { throw 'Beta is not complete.' }
    foreach ($value in @($entry.status,$entry.stage)) {
      if ($value -and $value -notin @('completed','complete','ok','ready','published','active')) { throw 'Release is not ready.' }
    }
  }
  $alias=if($channel -eq 'beta'){'coded-miner-windows-amd64-beta-latest.tar.gz'}else{'coded-miner-windows-amd64-latest.tar.gz'}
  if ($qa -and (!$qa.packages.ContainsKey($entry.version) -or $qa.packages[$entry.version].source_commit -cne $entry.commit)) { throw 'QA channel requested an unreviewed package.' }
  $cache=Join-Path $cacheParent $entry.version
  $root=Join-Path $cache 'coded-miner'
  if (!(Test-Path -LiteralPath $cache)) {
    $stage=Join-Path $cacheParent ('.stage-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    $release=Read-Json ($releaseApi+'/'+$entry.version)
    $assets=@($release.assets | Where-Object {$_.name -eq $alias})
    if ($assets.Count -ne 1 -or $assets[0].digest -notmatch '^sha256:[0-9a-f]{64}$' `
        -or $assets[0].browser_download_url -ne ($downloadBase+'/'+$entry.version+'/'+$alias)) {
      throw 'Exact versioned Windows archive/digest missing.'
    }
    $archive=Join-Path $stage 'package.tar.gz'
    if ($qa) {
      Assert-QualificationPath $archive
      if ($assets[0].digest -cne ('sha256:'+$qa.packages[$entry.version].archive_sha256)) { throw 'QA metadata archive digest mismatch.' }
      Invoke-WebRequest -UseBasicParsing -Uri $assets[0].browser_download_url -OutFile $archive -TimeoutSec (Qualification-Timeout 300) -MaximumRedirection 0
    } else {
      Invoke-WebRequest -UseBasicParsing -Uri $assets[0].browser_download_url -OutFile $archive -TimeoutSec 300
    }
    if ((Sha $archive) -ne $assets[0].digest.Substring(7)) { throw 'Windows archive SHA256 mismatch.' }
    $names=@(& tar.exe -tzf $archive)
    if ($LASTEXITCODE -ne 0 -or !$names.Count -or $names.Count -gt 50000) { throw 'Invalid package archive.' }
    $unique=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $names) {
      if ($name -notmatch '^coded-miner(/|$)' -or $name -match '(^|/)\.\.(/|$)|[\\:\x00\r\n]' `
          -or $name -match '(^|/)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|/|$)' `
          -or $name -match '[ .](/|$)' -or !$unique.Add($name.TrimEnd('/'))) { throw 'Unsafe Windows archive path.' }
    }
    $listing=@(& tar.exe -tvzf $archive)
    if ($LASTEXITCODE -ne 0 -or @($listing | Where-Object {$_ -notmatch '^[-d]'}).Count) { throw 'Archive links/special files rejected.' }
    & tar.exe -xzf $archive -C $stage
    if ($LASTEXITCODE -ne 0) { throw 'Archive extraction failed.' }
    Check-Package (Join-Path $stage 'coded-miner') $entry.commit $entry.version
    if (!$qa) { Remove-Item -LiteralPath $archive }
    try { [IO.Directory]::Move($stage,$cache) } catch {
      if (!(Test-Path -LiteralPath $cache)) { throw }
      # A concurrent verified installation wins; its bytes are checked below.
    }
  }
  Check-Package $root $entry.commit $entry.version
  if ($StageOnly) {
    $ready=@{root=$root;source_commit=$entry.commit;version=$entry.version} | ConvertTo-Json -Compress
    if ($qa) { $ready=@{root=$root;source_commit=$entry.commit;version=$entry.version;qa_plan_sha256=$QualificationPlanSha256;qualification_scope='staged_no_submit';real_public_onboarding=$false}|ConvertTo-Json -Compress }
    Write-Output ('WINDOWS_STAGE_READY='+$ready)
    exit 0
  }
  $env:CODED_WINDOWS_BOOTSTRAP_PATH=$PSCommandPath
  $env:CODED_WINDOWS_BOOTSTRAP_SHA256=Sha $PSCommandPath
  $env:CODED_WINDOWS_REQUESTED_CHANNEL=$requestedChannel
  $arguments=@('-I','-B',(Join-Path $root 'windows_runtime.py'),'--root',$root,'--wallet',$Wallet,
    '--worker',$Worker,'--backend',$Backend,'--threads',[string]$Threads,'--pool',$Pool)
  if ($qa) {
    $null=Read-QualificationPlan $QualificationPlan $QualificationPlanSha256 $Pool
    $arguments+=@('--qualification-only','--qualification-updates','--qualification-plan',$QualificationPlan,'--qualification-plan-sha256',$QualificationPlanSha256)
  }
  & (Join-Path $root 'python\python.exe') @arguments
  $code=$LASTEXITCODE
} while ($code -eq 75)
exit $code
