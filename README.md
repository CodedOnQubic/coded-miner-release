# CODED MINER 1.0 — because $0.01 IS CODED

The official Qubic Miner for the CODED mining pool.

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
