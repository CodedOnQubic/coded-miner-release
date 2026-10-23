param(
  [string]$Wallet=$env:CODED_WALLET,
  [string]$Worker=$env:CODED_WORKER,
  [ValidateRange(0,1024)][int]$Threads=0,
  [ValidateSet('auto','avx2','avx512','cuda','avx2+cuda','avx512+cuda')][string]$Backend='auto',
  [string]$Pool='pool.codedonqubic.com:7777',
  [switch]$Beta,
  [switch]$StageOnly
)
# Stock Windows bootstrap. The verified package supplies its own runtime.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
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
function Read-Json([string]$Uri) {
  Invoke-RestMethod -UseBasicParsing -Uri $Uri -UserAgent 'CODED-Windows-Public' -TimeoutSec 30
}
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Check-Package([string]$Root,[string]$Pin,[string]$Version) {
  $manifest=Get-Content -LiteralPath (Join-Path $Root 'release_manifest.json') -Raw | ConvertFrom-Json
  if ($manifest.schema -ne 'coded.windows.ant-v1306.v1' -or $manifest.release_profile -ne 'windows-ant-v1306' `
      -or $manifest.source_commit -ne $Pin -or $manifest.commit -ne $Pin -or $manifest.version -ne $Version `
      -or $manifest.branch -ne 'coded-miner-1.0-anthill' -or $manifest.publishable_source -ne $true `
      -or $manifest.publication_authorized -ne $true -or $manifest.runtime_compilation -ne $false `
      -or $manifest.host_python_required -ne $false -or $manifest.population -ne 32 -or $manifest.ann_bytes -ne 1088 `
      -or $manifest.windows_work_state_bank_enabled -ne $true -or $manifest.work_state_bank_reader_version -ne 3) {
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
New-Item -ItemType Directory -Force -Path $cacheParent | Out-Null
do {
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
  if (!$entry -or $entry.commit -notmatch '^[0-9a-f]{40}$' -or $entry.version -notmatch '^[A-Za-z0-9_.+-]+$' `
      -or !$entry.version.Contains($entry.commit) -or $entry.assets.windows.ok -ne $true `
      -or $entry.public_onboarding_contract -ne 'coded.public.onboarding.v1') { throw 'Windows channel is awaiting release qualification.' }
  if ($entry.source_commit -and $entry.source_commit -ne $entry.commit) { throw 'Source/channel mismatch.' }
  if ($channel -eq 'beta' -and ($entry.status -ne 'completed' -or $entry.stage -ne 'complete')) { throw 'Beta is not complete.' }
  foreach ($value in @($entry.status,$entry.stage)) {
    if ($value -and $value -notin @('completed','complete','ok','ready','published','active')) { throw 'Release is not ready.' }
  }
  $alias=if($channel -eq 'beta'){'coded-miner-windows-amd64-beta-latest.tar.gz'}else{'coded-miner-windows-amd64-latest.tar.gz'}
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
    Invoke-WebRequest -UseBasicParsing -Uri $assets[0].browser_download_url -OutFile $archive -TimeoutSec 300
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
    Remove-Item -LiteralPath $archive
    try { [IO.Directory]::Move($stage,$cache) } catch {
      if (!(Test-Path -LiteralPath $cache)) { throw }
      # A concurrent verified installation wins; its bytes are checked below.
    }
  }
  Check-Package $root $entry.commit $entry.version
  if ($StageOnly) {
    $ready=@{root=$root;source_commit=$entry.commit;version=$entry.version} | ConvertTo-Json -Compress
    Write-Output ('WINDOWS_STAGE_READY='+$ready)
    exit 0
  }
  $env:CODED_WINDOWS_BOOTSTRAP_PATH=$PSCommandPath
  $env:CODED_WINDOWS_BOOTSTRAP_SHA256=Sha $PSCommandPath
  $env:CODED_WINDOWS_REQUESTED_CHANNEL=$requestedChannel
  $arguments=@('-I','-B',(Join-Path $root 'windows_runtime.py'),'--root',$root,'--wallet',$Wallet,
    '--worker',$Worker,'--backend',$Backend,'--threads',[string]$Threads,'--pool',$Pool)
  & (Join-Path $root 'python\python.exe') @arguments
  $code=$LASTEXITCODE
} while ($code -eq 75)
exit $code
