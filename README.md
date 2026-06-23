# CODED Miner

Minimal CPU miner for the CODED mining pool.

---

## ⚠️ Status

This is a **test release**.

- Native macOS (Apple Silicon) supported  
- Docker (Linux / Windows / Intel Mac) supported  
- HiveOS supported  
- Pool connection working  
- Worker reporting active  
- Performance still evolving  

---

# 🚀 Quick Start (1-Click)

## 🍎 macOS (M1 / M2 / M3)

```bash
WALLET=YOUR_WALLET WORKER=my-mac bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```
```bash
WALLET=YOUR_WALLET \
WORKER=Intel-Mac \
CODED_ANALYTICS=yes \
CODED_BUILDER=yes \
CODED_BUILDER_TARGETS=macos-x64,docker-linux-amd64 \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh?z257b=$(date +%s))"
```

---

## 🐳 Docker (Linux / Windows / Intel Mac)

```bash
wsl bash -lc 'WALLET="DEINE_WALLET_HIER" WORKER="Windows"  "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh?z257b=$(date +%s))"'
```

```bash
$env:WALLET="DEINE_QUBIC_WALLET_HIER"; $env:WORKER="WinScalar_Public_Test_01"; $env:CODED_ANALYTICS="YES"; $env:CODED_BACKEND="scalar"; $env:CODED_FORCE_FULLSCORE="1"; iwr -UseBasicParsing "https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1?cb=$([int][double]::Parse((Get-Date -UFormat %s)))" | iex
```

---

## ⚙️ Optional Parameters

```bash
WALLET=YOUR_WALLET \
WORKER=my-rig \
THREADS=4 \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

### Thread Control

| Value  | Behavior                |
|--------|------------------------|
| unset  | all CPUs - 1 (default) |
| 1      | 1 thread               |
| 4      | 4 threads              |
| 0      | all CPUs - 1           |

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
| Extra config arguments | `{"amountOfThreads":32}` |

### Thread Control in HiveOS

```json
{"amountOfThreads":32}
```

| Value | Behavior |
|------|----------|
| `1` | 1 thread |
| `4` | 4 threads |
| `32` | 32 threads |
| `0` | all CPUs minus 1 |

---

# 📡 Dashboard

Workers appear automatically:

- Worker name  
- Wallet  
- Status  
- Hashrate  

👉 https://codedonqubic.com/pool

---

# ⚙️ Notes

- CPU mining only (auto-detect AVX2 / AVX512)  
- Native macOS ARM build (no Docker required)  
- Docker fallback for all other systems  
- CUDA backend not active yet  

---

# 🔒 Security

- No private keys required  
- Wallet is used for identification only  
- Binary-only release  

---

# 📣 Feedback

This is an early test release.

Report issues, bugs, or performance results.
