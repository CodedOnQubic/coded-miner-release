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
powershell -NoProfile -ExecutionPolicy Bypass -Command "$body = @{ device_id='windows-x64:Windows'; worker_name='Windows'; target='windows-x64'; platform='windows-x64'; os='Windows'; arch='x64'; analytics=$true; builder=$true; builder_targets=@('windows-x64'); miner_running=$false; runtime_mode='builder_standby'; device_role='external_builder'; capabilities=@{ windows_x64=$true; build_windows_x64=$true; default_analytics=$true; run_experiment=$false }; source='manual_windows_cmd_powershell_register_z257' } | ConvertTo-Json -Depth 10; Invoke-RestMethod -Uri 'https://api.codedonqubic.com/fleet/devices/heartbeat' -Method POST -ContentType 'application/json' -Body $body"
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
