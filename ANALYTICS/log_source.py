#!/usr/bin/env python3
import glob
import os

def latest_log():
    for name in ("RUN_LOG", "CODED_RUN_LOG", "CODED_ANALYTICS_LOG"):
        p = os.environ.get(name) or ""
        if p and os.path.exists(p):
            return p

    files = glob.glob("/var/log/miner/coded-miner/LIVE_*")
    if not files:
        files = glob.glob("/var/log/miner/coded-miner/*.log")
    return max(files, key=os.path.getmtime) if files else ""
