# CODED MINER 1.0 - because $0.01 IS CODED

The official Qubic Miner for the CODED mining pool.


## 👁️🔥 Beta Release

- Linux / Windows / Mac ARM supported  
- HiveOS supported  
- Performance still evolving
- CPU mining only (auto-detect AVX2 / AVX512)
- CUDA backend not active yet 

---



# 🚀 Quick Start (1-Click)



## 🖥️ Windows

- Press Win+R and type cmd.exe
- Paste in the onliner
- Set your own Qubic Wallet and a public worker name for your local machine

### Auto optimization mode (automatic backend and thread optimization)

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME"
```

### Manual mode (optional backend and thread control)

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME -avx2 -10"
```

### ⚙️ Optional Parameters
```json
-avx2, -avx512, -1, -2, -3 etc
```

### Thread Control

| Value | Behavior                         |
|------|-------|
| ` `   | Auto detect (all CPU threads -1) |
| `-4`   | 4 threads                        |
| `-32`  | 32 threads                       |

### Backend Control 

| Value    | Behavior                                |
|------|-------|
| ` `      | Auto detect (AVX512 -> AVX2 -> Scalar)  |
| `-avx512` | force AVX512 if possible               |
| `-avx2`   | force AVX2 if possible                 |

---



## 🍎 MAC (M1 / M2 / M3)

- Open the terminal app on your mac and paste in the onliner
- Set your own Qubic Wallet and a public worker name for your Machine

### Auto optimization mode
```bash
WALLET=YOUR_QUBIC_WALLET WORKER=YOUR_WORKER_NAME bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

---



## 🐧 Linux

- Open the command on your machine and paste in the onliner
- Set your own Qubic Wallet and a public worker name for your local Machine

### Auto optimization mode (automatic backend and threads optimization)
```bash
WALLET=YOUR_QUBIC_WALLET WORKER=YOUR_WORKER_NAME bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

### Manual mode (optional backend and thread control)
```bash
QUBIC_WALLET='YOUR_QUBIC_WALLET' QUBIC_WORKER='YOUR_WORKER_NAME' bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)" -- -avx2 -10
```

### ⚙️ Optional Parameters
```json
-avx2, -avx512, -1, -2, -3 etc
```

### Thread Control

| Value | Behavior                         |
|------|-------|
| ` `   | Auto detect (all CPU threads -1) |
| `-4`   | 4 threads                        |
| `-32`  | 32 threads                       |

### Backend Control 

| Value    | Behavior                                |
|------|-------|
| ` `      | Auto detect (AVX512 -> AVX2 -> Scalar)  |
| `-avx512` | force AVX512 if possible               |
| `-avx2`   | force AVX2 if possible                 |

---



# 🐝 HiveOS Flight Sheet Setup

HiveOS → **Flight Sheet** → **Custom Miner** → **Expert Section**

Use the following values:

| Field | Value |
|------|-------|
| Miner name | `coded-miner` |
| Installation URL | `https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz` |
| Hash algorithm | `----` |
| Wallet and worker template | `%WAL%-%WORKER_NAME%` |
| Pool URL | `pool.codedonqubic.com:7777` |
| Pass | leave empty |
| Extra config arguments | `{"amountOfThreads":16,"cpu":"avx2"}` |

### Thread Control in HiveOS

```json
{"amountOfThreads":32}
```

| Value | Behavior                         |
|------|-------|
| `-`   | Auto detect (all CPU threads -1) |
| `4`   | 4 threads                        |
| `32`  | 32 threads                       |


### Backend Control in HiveOS

```json
{"cpu":avx2}, {"cpu":avx512}
```

| Value    | Behavior                               |
|------|-------|
| `-`      | Auto detect (AVX512 -> AVX2 -> Scalar) |
| `avx512` | force AVX512 if possible               |
| `avx2`   | force AVX2 if possible                 |


---



# 📡 Dashboard

Workers appear automatically:

- Worker name  
- Wallet  
- Status  
- Hashrate  

👉 https://codedonqubic.com/pool

---

# Feedback

This is an early test release.

Report issues, bugs, or performance results.
