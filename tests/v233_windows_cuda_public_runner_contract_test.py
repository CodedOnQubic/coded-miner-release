#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
wrapper = (ROOT / "run.ps1").read_text(encoding="utf-8")
base = (ROOT / "run-base-v233.ps1").read_text(encoding="utf-8")

for token in (
    "M1091V233_WINDOWS_CUDA_EXPLICIT_BETA_AUTHORITY",
    '$script:CodedExplicitCudaBeta = $explicitCuda -and $explicitBeta',
    '"-cuda","--cuda"',
    '"-beta","--beta"',
    '"explicit_user_cuda_beta"',
    'CODED_HARDWARE_TUNE_REQUESTED_BACKEND = $effectivePolicyBackend',
    'CODED_PUBLIC_BACKEND_REQUEST_SNAPSHOT = $effectivePolicyBackend',
    'run-base-v233.ps1',
    'M1091V233_WINDOWS_CUDA_REMOTE_ONE_SHOT_SUPERVISOR',
    'retrying channel in 60s',
):
    assert token in wrapper, token

for token in (
    "M1091V233_WINDOWS_CUDA_BETA_GOLDEN_AUTOUPDATE",
    "M1091V233_WINDOWS_CUDA_SINGLE_GPU_BASELINE",
    "M1091V233_WINDOWS_CUDA_BETA_GOLDEN_GATE",
    '$Threads = 1',
    '$env:CODED_CUDA_DEVICE = "0"',
    'coded-miner-cuda.exe',
    'coded-bpp9000-cuda-golden.exe',
    'coded-bpp9000-cuda.ptx',
    'full112-v1.meta',
    'task_bpp9000.bin',
    'FINAL=PASS_CUDA_BETA_GOLDEN',
    'architecture=blackwell',
    'golden_gate_sha256',
    'task_sha256',
    'gpu_identity',
    'Get-WmiObject Win32_VideoController',
    'CUDA beta packaged task authority mismatch',
    'Start-CodedWindowsChannelAutoupdateV53B',
    '& $self -Wallet $Wallet -Worker $Worker -Pool $Pool -Backend $Backend -Threads $Threads -Beta',
    'Get-CodedPublicBackend',
    'if ($b -match "cuda") { return "CUDA" }',
    'Post-Json "/analytics/runs/heartbeat"',
    'Post-Json "/analytics/performance-snapshot"',
):
    assert token in base, token

golden_index = base.index("M1091V233_WINDOWS_CUDA_BETA_GOLDEN_GATE")
run_index = base.index(
    '& $exe --pool $Pool --wallet $Wallet --worker $Worker'
)
assert golden_index < run_index

assert (
    'CUDA backend requested, but coded-miner-cuda.exe is not included '
    'in this Windows release.'
) in base

print("V233_WINDOWS_CUDA_SHORT_ARGS=PASS")
print("V233_WINDOWS_CUDA_GOLDEN_BEFORE_MINING=PASS")
print("V233_WINDOWS_CUDA_PUBLIC_LOG_ANALYTICS=PASS")
print("V233_WINDOWS_CUDA_BETA_AUTOUPDATE=PASS")
print("V233_WINDOWS_CUDA_ONE_TIME_ONELINER=PASS")
print("FINAL=PASS_V233_WINDOWS_CUDA_PUBLIC_RUNNER_CONTRACT")
