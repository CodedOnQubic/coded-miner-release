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
# M1091V27E_WINDOWS_CMD_BRIDGE_NO_CRASH
# Windows 8 PowerShell can crash with async .NET ProcessStartInfo stream handlers.
# Use cmd.exe as the native stdio bridge instead:
# - cmd redirects miner stderr to stdout
# - PowerShell receives plain stdout only
# - Tee-Object writes the same stream to the analytics log
# - avoids red NativeCommandError and avoids PowerShell crash

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
