# CODED Miner

Start mining with one command.

Replace:

- `YOUR_QUBIC_WALLET`
- `YOUR_WORKER_NAME`

## Windows

Works in PowerShell and cmd.exe.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME"
```

Windows downloads the latest universal package:

```text
coded-miner-windows-amd64-latest.tar.gz
```

The launcher selects the best backend automatically:

```text
AVX512 > AVX2 > scalar
```

## Linux

```bash
CODED_WALLET='YOUR_QUBIC_WALLET' CODED_WORKER='YOUR_WORKER_NAME' bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

## macOS

Apple Silicon / ARM64:

```bash
CODED_WALLET='YOUR_QUBIC_WALLET' CODED_WORKER='YOUR_WORKER_NAME' CODED_PLATFORM='macos-arm64' bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

## HiveOS

### Hive Shell

```bash
CODED_WALLET='YOUR_QUBIC_WALLET' CODED_WORKER='HIVE_WORKER_NAME' CODED_ANALYTICS='YES' bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

### Hive Flight Sheet

Use a Custom Miner / Custom Command and paste:

```bash
CODED_WALLET='YOUR_QUBIC_WALLET' CODED_WORKER='HIVE_WORKER_NAME' CODED_ANALYTICS='YES' bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

## Optional

### Set threads manually on Windows

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME -Threads 15"
```

### Force AVX2 on Windows

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME -Backend avx2"
```

### Set threads manually on Linux / macOS / HiveOS

```bash
CODED_WALLET='YOUR_QUBIC_WALLET' CODED_WORKER='YOUR_WORKER_NAME' CODED_THREADS='15' bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
```

## Repository contents

This repository intentionally stays clean and only contains:

```text
README.md
run.ps1
run.sh
```
