# CODED Miner (HiveOS)

Minimal CPU miner for the CODED mining pool.

---

## ⚠️ Status

This is a **test release**.

- Linux binary included  
- HiveOS custom miner wrapper included  
- Pool connection working  
- Worker reporting active  
- Performance still evolving  

---

## 🚀 Quick Start (HiveOS)

### 1. Download

```bash
cd /hive
wget https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz
```

### 2. Install

```bash
rm -rf /hive/miners/custom/coded-miner
mkdir -p /hive/miners/custom
tar -xzf coded-miner-latest.tar.gz -C /hive/miners/custom
```

### 3. Configure

HiveOS → **Flight Sheet → Custom Miner**

Use:

**Pool URL**
```
pool.codedonqubic.com:7777
```

**Wallet**
```
YOUR_WALLET
```

**Worker Name**
```
rig-name
```

**Extra Config**
```json
{"amountOfThreads":4}
```

### 4. Thread Control

| Value | Behavior          |
|------|------------------|
| 1    | 1 thread         |
| 4    | 4 threads        |
| 0    | all CPUs minus 1 |

### 5. Start Miner

```bash
source /hive/miners/custom/h-config.sh
miner_config_gen
bash /hive/miners/custom/h-run.sh
```

---

## 📊 Output Example

```
[ $0.01 CODED ] ... | SOLS: 0/0 | RAWDIFF:80 | THRESH:80 | S:stub | [AVX512] 590k it/s | 580k avg it/s
```

---

## 📡 Frontend

Workers will appear automatically:

- Worker name  
- Wallet  
- Status: active  
- Hashrate  
```bash
 https://codedonqubic.com/pool
```
---

## ⚙️ Notes

- CPU only (AVX2 / AVX512 auto-detection)  
- CUDA not active yet  
- Score system currently stubbed (`qatum_stub`)  

---

## 🔒 Security

- This repo contains binary releases only  
- Source code is private  
- No private keys are required  

---


## 📣 Feedback

This is an early test release.

Report issues or performance feedback.
