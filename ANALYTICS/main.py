#!/usr/bin/env python3
import time
from .config import load_identity
from .log_source import latest_log
from .parsers import parse_log
from .payloads import build_payloads
from .client import post_json

def main():
    identity = load_identity()
    print(
        f"[M1091U2_ANALYTICS_COMPONENT] start rig={identity.rig_id} worker={identity.worker_name} "
        f"backend={identity.backend} platform={identity.platform} threshold={identity.threshold} "
        f"threads={identity.threads} api={identity.api}",
        flush=True,
    )

    while True:
        log = latest_log()
        metrics = parse_log(log)
        payloads, sem = build_payloads(identity, metrics, log)

        for path, payload in payloads:
            code, resp = post_json(identity.api, path, payload)
            print(
                f"[M1091U2_ANALYTICS_COMPONENT] {path} http={code} "
                f"total_seen={metrics.total_seen} total_audited={metrics.total_audited} "
                f"avg_its={metrics.avg_its} real_score_available={sem.real_score_available} "
                f"training_mode={sem.training_mode} score_mode={sem.score_mode} reason={sem.reason} resp={resp}",
                flush=True,
            )

        time.sleep(identity.poll_sec)

if __name__ == "__main__":
    main()
