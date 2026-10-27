# CODED MINER — $0.01 IS CODED

The public packages and launchers for the CODED Qubic miner. Miner source is private; release assets are distributed only by this repository.

## Start Mining

Open [Start Mining](https://beta.codedonqubic.com/pool/onboarding), choose your operating system, enter your **public Qubic wallet identity** and give the machine a worker name. Never enter a wallet seed or private key.

The page creates a downloadable launcher and the matching command to copy into your terminal. Both use the same backend, thread count and release channel. The foreground launcher owns the miner and its existing autoupdater.

Downloads are enabled separately for each operating system after qualification. If a channel is unavailable for your OS, wait for its qualified package. Do not substitute an older channel or a package from another platform.

## Choose a backend

| Selection | Mode |
| --- | --- |
| Auto | CPU only: AVX512 first, then AVX2; automatic threads |
| AVX2 | CPU only, explicit AVX2 |
| AVX512 | CPU only, explicit AVX512 |
| CUDA | GPU only, explicit NVIDIA CUDA |
| AVX2 + CUDA | Hybrid CPU + GPU |
| AVX512 + CUDA | Hybrid CPU + GPU |
| Mac | Automatic local choice of the packaged Apple CPU/GPU runtime |

Auto is exclusive and never enables CUDA on an x86 machine. AVX2 and AVX512 are mutually exclusive. Select CUDA alongside one CPU backend for Hybrid. Threads default to Auto; a manual Hybrid thread count means **CPU threads**, with GPU workers managed separately. GPU-only has no CPU thread control.

Explicit unsupported backends fail with an error rather than silently changing the selected mode. The retired `-gpu` and `-gpu_only` arguments are not part of this onboarding contract.

## Linux

Replace both placeholders. Run in a terminal as your ordinary user:

```bash
WALLET=YOUR_QUBIC_WALLET WORKER=YOUR_WORKER_NAME bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)" -- --beta
```

Add one of these configurations after `--beta`:

| Arguments | Configuration |
| --- | --- |
| none | Auto CPU and threads |
| `-avx2 --threads 8` | AVX2 with eight CPU threads |
| `-avx512 --threads 16` | AVX512 with sixteen CPU threads |
| `-cuda` | CUDA only |
| `-avx2 -cuda --threads 4` | AVX2 + CUDA with four CPU threads |
| `-avx512 -cuda --threads 4` | AVX512 + CUDA with four CPU threads |

CUDA requires a compatible NVIDIA driver. The package carries its CUDA runtime; no CUDA compiler or toolkit is needed on a mining client. Hardware qualification is limited to the devices stated in the release evidence, currently RTX 3070 / SM86 and RTX 5070 / SM120 for the release matrix.

## Apple Silicon Mac

Open Terminal and run:

```bash
WALLET=YOUR_QUBIC_WALLET WORKER=YOUR_WORKER_NAME bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)" -- --beta --backend=mac
```

Mac exposes one choice: **Mac**. It selects a correctness-checked local CPU/GPU configuration with a bounded startup probe and safe defaults. Add `--threads 8` for a manual thread count.

The ARM package includes Python and its precompiled Metal library. A mining client needs no Homebrew, Xcode, host Python or extra compiler. Apple Silicon M1–M5 compatibility is the packaging target; this is not a claim that every chip generation has been physically qualified. Read the exact release evidence for tested hardware. macOS 12 or newer is required by the current package.

## Windows

The native Windows Beta is awaiting complete package, GPU and recovery qualification. Its successful compilation and CLI checks do not certify mining parity. Start Mining keeps the new Windows Beta download and command disabled until those gates pass.

When available, select **Windows**, enter your public wallet and a distinct worker name, and choose **Beta**. Leave backend and threads on **Auto** for the standard CPU setup, or select CUDA and an optional CPU backend explicitly. Download **CODED MINER.exe**, open it from Downloads and leave its mining window open. The launcher downloads the verified miner for the selected channel and manages approved updates. Mining clients will not need MSVC, NVCC or a separate Python installation.

Alternatively, paste the matching command from Start Mining into **Command Prompt (cmd.exe)**. The file and command carry the same settings. Use one launcher per worker; stop the first instance with **Ctrl+C** and wait for its clean shutdown before trying the other method. Keep the same wallet, worker and state on restart.

## HiveOS Flight Sheet

In HiveOS, choose **Flight Sheet → Custom Miner → Expert Section**. Copy the installation URL for the selected available channel from Start Mining; Beta requires its Beta archive, not the Latest archive.

| Field | Value |
| --- | --- |
| Miner name | `coded-miner` |
| Installation URL | Copy from Start Mining for the selected channel |
| Hash algorithm | `----` |
| Wallet and worker template | `%WAL%-%WORKER_NAME%` |
| Pool URL | `pool.codedonqubic.com:7777` |
| Pass | Leave empty |

Examples of **Beta Extra Config**:

```json
{"beta":"yes"}
```

```json
{"beta":"yes","backend":"avx2","amountOfThreads":8}
```

```json
{"beta":"yes","backend":"cuda"}
```

```json
{"beta":"yes","backend":"hybrid-avx512","amountOfThreads":4}
```

For AVX2 Hybrid use `hybrid-avx2`. In Hybrid, `amountOfThreads` is the CPU count; it is not the combined CPU/GPU worker count. Omit it for Auto.

## Updates and existing workers

Beta and Latest are separate channels. Beta is tested first. Promotion to Latest preserves the exact qualified source and packages; it does not rebuild them. A disabled Beta may follow Latest only through the existing promotion contract. This README does not promote a release.

Keep the same wallet, worker identity and persistent state. An update must preserve the existing native geometry. A stopped-work receipt does not authorize a Solo/Hybrid conversion, state reset or deletion of a search cursor. If a mode change is held for migration, keep the existing configuration and report the error. Never delete state to make a launch succeed.

Hive remains the live mining host during Windows VM preparation. Windows GPU tests require an explicitly controlled test window and restoration of the existing Hive owner.

## Logs and support

The public miner console uses the **$0.01 IS CODED** branding. FOUND, pool responses and independently verified network acceptance are different observations; a sent packet is not proof of network acceptance.

Hive public output is available in `/var/log/miner/coded-miner/coded-miner.log`. Mac public output stays in the foreground Terminal. Windows public output stays in its mining window; per-run native and Analytics logs are stored under `%LOCALAPPDATA%\CODED\state\windows\<identity>\`. Include OS, selected channel, full source commit, backend, thread count and the relevant error lines when reporting a problem. Do not include private keys, credentials or full environment dumps.

The public dashboard is linked from Start Mining. A worker is ready only when the correct native process receives a current job and its real scoring counters advance.
