# CODED MINER 1.0 — because $0.01 IS CODED

The official Qubic Miner for the CODED mining pool.

## Next unified Beta — release qualification pending

The following is the new Beta contract, **not a claim that the combined release
is already published**. Wait for the Admin release to complete. Public Latest
and its existing launchers are unchanged; Windows CUDA/Hybrid qualification is
deferred. Do not install Windows over a Hive disk for testing.

| Explicit Beta mode | Linux x86-64 | Apple Silicon Mac |
| --- | --- | --- |
| no GPU flag | CPU: AVX512 / AVX2 | CPU: NEON |
| `-gpu` | CPU + CUDA Hybrid | NEON + Metal Hybrid |
| `-gpu_only` | CUDA only | Metal only |

CUDA currently targets qualified RTX 3070 (SM86) and RTX 5070 (SM120).
Explicit GPU requests fail closed if the required qualified binary/device is
missing; they do not silently select CPU. Linux Hybrid uses the reviewed fixed
24 CPU + 32 CUDA worker geometry, not automatic performance tuning. CPU-only
accepts `-avx2`, `-avx512` and a thread shorthand such as `-8`.

Example Linux or Mac GPU-only Beta (replace the wallet and worker):

```bash
WALLET=YOUR_QUBIC_WALLET WORKER=YOUR_WORKER_NAME bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)" -- --beta -gpu_only
```

Remove `-gpu_only` for CPU-only, or replace it with `-gpu` for Hybrid.
Mac Beta packages include Python and a precompiled Metal library: no Homebrew,
Xcode, Metal compiler or host Python is required. M2 Pro and M3 Pro are the
tested hardware; other Apple Silicon generations are not asserted qualified
solely from architecture compatibility.

Hive Extra Config for that completed Beta:

```json
{"beta":"yes"}
```

CPU-only is the default. GPU-only:

```json
{"beta":"yes","gpu":"yes","cpu":"no"}
```

CPU + GPU Hybrid:

```json
{"beta":"yes","gpu":"yes"}
```

Do not switch an old GPU-only cursor into Hybrid by copying or deleting state.
The existing native drain/checkpoint and guarded state conversion must finish.
The console separates FOUND, POOL acceptance and independently proven NET
acceptance. Analytics2 rates come from the actual native process, not a sidecar
estimate. Closing the miner must stop its owned telemetry process as well.

---

## 👁️🔥 Beta Release

* Linux / Windows / Mac ARM supported
* HiveOS supported
* Performance still evolving
* CPU mining only
* Automatic backend detection: AVX512 → AVX2 → Scalar
* CUDA backend not active yet

---

# 🚀 Quick Start

Replace:

```text
YOUR_QUBIC_WALLET
YOUR_WORKER_NAME
```

Use a public worker name for your machine, for example:

```text
Rig1
OfficePC
MacMini
WinAVX2
```

---

# 🖥️ Windows

* Press **Win + R**
* Type `cmd.exe`
* Paste the one-liner
* Set your own Qubic Wallet and worker name

## Auto Optimization Mode

Automatic backend and thread optimization:


```powershell
powershell -NoP -EP Bypass -C "[Net.ServicePointManager]::SecurityProtocol=3072;iwr -UseB https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile $env:TEMP\r.ps1;& $env:TEMP\r.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME"
```

## Manual Mode

Optional backend and thread control.

Example: force AVX2 and use 10 threads.

```powershell
powershell -NoP -EP Bypass -C "[Net.ServicePointManager]::SecurityProtocol=3072;iwr -UseB https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile $env:TEMP\r.ps1;& $env:TEMP\r.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME -avx2 -10"
```

## Optional Parameters

```text
-avx2, -avx512, -1, -2, -3, -4, -10, -32, etc.
```

### Thread Control

| Value | Behavior                             |
| ----- | ------------------------------------ |
| empty | Auto detect: all CPU threads minus 1 |
| `-4`  | Use 4 threads                        |
| `-10` | Use 10 threads                       |
| `-32` | Use 32 threads                       |

### Backend Control

| Value     | Behavior                            |
| --------- | ----------------------------------- |
| empty     | Auto detect: AVX512 → AVX2 → Scalar |
| `-avx512` | Force AVX512 if supported           |
| `-avx2`   | Force AVX2 if supported             |

---

# 🍎 Mac ARM

For Apple Silicon: M1 / M2 / M3 / M4.

* Open the Terminal app
* Paste the one-liner
* Set your own Qubic Wallet and worker name

## Auto Optimization Mode

```bash
WALLET=YOUR_QUBIC_WALLET WORKER=YOUR_WORKER_NAME bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

---

# 🐧 Linux

* Open a terminal
* Paste the one-liner
* Set your own Qubic Wallet and worker name

## Auto Optimization Mode

Automatic backend and thread optimization:

```bash
WALLET=YOUR_QUBIC_WALLET WORKER=YOUR_WORKER_NAME bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

## Manual Mode

Optional backend and thread control.

Example: force AVX2 and use 10 threads.

```bash
QUBIC_WALLET='YOUR_QUBIC_WALLET' QUBIC_WORKER='YOUR_WORKER_NAME' bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)" -- -avx2 -10
```

## Optional Parameters

```text
-avx2, -avx512, -1, -2, -3, -4, -10, -32, etc.
```

### Thread Control

| Value | Behavior                             |
| ----- | ------------------------------------ |
| empty | Auto detect: all CPU threads minus 1 |
| `-4`  | Use 4 threads                        |
| `-10` | Use 10 threads                       |
| `-32` | Use 32 threads                       |

### Backend Control

| Value     | Behavior                            |
| --------- | ----------------------------------- |
| empty     | Auto detect: AVX512 → AVX2 → Scalar |
| `-avx512` | Force AVX512 if supported           |
| `-avx2`   | Force AVX2 if supported             |

---

# 🐝 HiveOS Flight Sheet Setup

HiveOS → **Flight Sheet** → **Custom Miner** → **Expert Section**

Use the following values:

| Field                      | Value                                                                                                    |
| -------------------------- | -------------------------------------------------------------------------------------------------------- |
| Miner name                 | `coded-miner`                                                                                            |
| Installation URL           | `https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz` |
| Hash algorithm             | `----`                                                                                                   |
| Wallet and worker template | `%WAL%-%WORKER_NAME%`                                                                                    |
| Pool URL                   | `pool.codedonqubic.com:7777`                                                                             |
| Pass                       | leave empty                                                                                              |
| Extra config arguments     | `{"amountOfThreads":16,"cpu":"avx2"}`                                                                    |

## Thread Control in HiveOS

```json
{"amountOfThreads":32}
```

| Value | Behavior                             |
| ----- | ------------------------------------ |
| empty | Auto detect: all CPU threads minus 1 |
| `4`   | Use 4 threads                        |
| `16`  | Use 16 threads                       |
| `32`  | Use 32 threads                       |

## Backend Control in HiveOS

```json
{"cpu":"avx2"}
```

```json
{"cpu":"avx512"}
```

| Value    | Behavior                            |
| -------- | ----------------------------------- |
| empty    | Auto detect: AVX512 → AVX2 → Scalar |
| `avx512` | Force AVX512 if supported           |
| `avx2`   | Force AVX2 if supported             |

---

# 📡 Dashboard

Workers appear automatically:

* Worker name
* Wallet
* Status
* Hashrate

👉 https://codedonqubic.com/pool

---

# Feedback

This is an early beta release.

Report issues, bugs, or performance results.


```powershell
powershell -NoP -EP Bypass -C "[Net.ServicePointManager]::SecurityProtocol=3072;iwr -UseB https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile $env:TEMP\r.ps1;& $env:TEMP\r.ps1 -Wallet EUELEOZEENRCEDYVEAZEBYVHQFABSUFFWTUWTFNSFALSTCNJLCDSEROGOSYI -Worker RigPortable_Win8"
```

```powershell
type "%LOCALAPPDATA%\CODED\miner\coded-miner.log" | findstr /I "ERROR SUBMIT_SPOOL spool initialize connect subscribe"
```
