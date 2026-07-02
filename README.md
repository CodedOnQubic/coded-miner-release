# CODED Miner for Qubic

Qubic CPU miner for the CODED mining pool.

---

## ⚠️ Status

This is a **beta release**.

- Linux / Windows / Mac ARM supported  
- HiveOS supported  
- Performance still evolving
- CPU mining only (auto-detect AVX2 / AVX512)
- CUDA backend not active yet 

---

# 🚀 Quick Start (1-Click)

## MAC (M1 / M2 / M3)

```bash
WALLET=YOUR_WALLET WORKER=my-mac bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

---

## Windows

```bash
wsl bash -lc 'WALLET="DEINE_WALLET_HIER" WORKER="Windows"  "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh?z257b=$(date +%s))"'
```

---

## Linux

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME"
```
---


## ⚙️ Optional Parameters

### Thread Control

| Value | Behavior                         |
|------|-------|
| `-`   | Auto detect (all CPU threads -1) |
| `4`   | 4 threads                        |
| `32`  | 32 threads                       |

### Backend Control 

```json
{"cpu":avx2}, {"cpu":avx512}
```

| Value    | Behavior                               |
|------|-------|
| `-`      | Auto detect (AVX512 -> AVX2 -> Scalar) |
| `avx512` | force AVX512 if possible               |
| `avx2`   | force AVX2 if possible                 |

---

# HiveOS Flight Sheet Setup

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

# Security

- No private keys required  
- Wallet is used for identification only  
- Binary-only release  

---

# Feedback

This is an early test release.

Report issues, bugs, or performance results.
