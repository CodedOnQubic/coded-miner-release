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
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME"
```

## Manual Mode

Optional backend and thread control.

Example: force AVX2 and use 10 threads.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet YOUR_QUBIC_WALLET -Worker YOUR_WORKER_NAME -avx2 -10"
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
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1 -OutFile run.ps1; .\run.ps1 -Wallet 
EUELEOZEENRCEDYVEAZEBYVHQFABSUFFWTUWTFNSFALSTCNJLCDSEROGOSYI -Worker Win"
```
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=3072;$ProgressPreference='SilentlyContinue';$wallet='EUELEOZEENRCEDYVEAZEBYVHQFABSUFFWTUWTFNSFALSTCNJLCDSEROGOSYI';$worker='RigPortable_Win8';$p=$env:TEMP+'\coded-run.ps1';(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.ps1',$p);& $p -Wallet $wallet -Worker $worker"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -PropertyType DWord -Force; New-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -PropertyType DWord -Force; [Net.ServicePointManager]::SecurityProtocol = 3072; Write-Host 'TLS12 enabled. Please reboot Windows once, then run CODED oneliner again.'"
```
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';[Net.ServicePointManager]::SecurityProtocol=3072;$w='EUELEOZEENRCEDYVEAZEBYVHQFABSUFFWTUWTFNSFALSTCNJLCDSEROGOSYI';$wk='RigPortable_Win8';$root=Join-Path $env:TEMP 'coded-miner-win8';$dir=Join-Path $root 'latest';$url='https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-windows-amd64-latest.tar.gz';Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue;New-Item -ItemType Directory -Force $dir|Out-Null;$tgz=Join-Path $root 'coded.tar.gz';$tar=Join-Path $root 'coded.tar';Write-Host 'Downloading CODED Windows latest...';(New-Object Net.WebClient).DownloadFile($url,$tgz);Write-Host 'Decompressing gzip...';$i=[IO.File]::OpenRead($tgz);$g=New-Object IO.Compression.GzipStream($i,[IO.Compression.CompressionMode]::Decompress);$o=[IO.File]::Create($tar);$buf=New-Object byte[] 65536;while(($r=$g.Read($buf,0,$buf.Length))-gt 0){$o.Write($buf,0,$r)};$o.Close();$g.Close();$i.Close();Write-Host 'Extracting tar without tar.exe...';$fs=[IO.File]::OpenRead($tar);$h=New-Object byte[] 512;while(($rr=$fs.Read($h,0,512))-eq 512){$name=([Text.Encoding]::ASCII.GetString($h,0,100)).Trim([char]0);if(!$name){break};$so=([Text.Encoding]::ASCII.GetString($h,124,12)).Trim([char]0,' ');$sz=0;if($so){$sz=[Convert]::ToInt64($so,8)};$type=[char]$h[156];$path=Join-Path $dir (($name -replace '^\./','') -replace '/','\');if($type -eq '5'){New-Item -ItemType Directory -Force $path|Out-Null}else{New-Item -ItemType Directory -Force (Split-Path $path) -ErrorAction SilentlyContinue|Out-Null;$of=[IO.File]::Create($path);$left=$sz;$c=New-Object byte[] 65536;while($left -gt 0){$n=$fs.Read($c,0,[Math]::Min($c.Length,$left));if($n -le 0){break};$of.Write($c,0,$n);$left-=$n};$of.Close();$skip=(512-($sz%512))%512;if($skip){$fs.Seek($skip,[IO.SeekOrigin]::Current)|Out-Null}}};$fs.Close();$start=Join-Path $dir 'start.ps1';if(!(Test-Path $start)){Write-Host 'Extracted files:';dir $dir -Recurse;throw 'start.ps1 not found'};Write-Host 'Starting CODED Miner...';& $start -Wallet $w -Worker $wk -Threads 0 -Backend auto"
```
