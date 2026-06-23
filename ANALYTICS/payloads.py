#!/usr/bin/env python3
import time
from pathlib import Path
from .parsers import bucket
from .semantics import classify

def build_payloads(identity, metrics, log):
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    run_id = Path(log).name.replace(".log", "") if log else f"LIVE_{identity.rig_id}_T{identity.threshold}_ANALYTICS"
    sem = classify(identity, metrics)

    scores = metrics.scores
    total_seen = int(metrics.total_seen or 0)
    total_audited = int(metrics.total_audited or 0)
    total_pass = sum(1 for s in scores if identity.threshold > 0 and s >= identity.threshold)
    max_score = max(scores) if scores else 0
    real300 = bucket(scores, 300)
    real310 = bucket(scores, 310)
    real321 = bucket(scores, 321)

    raw = {
        "source": "M1091U2_ANALYTICS_COMPONENT",
        "posted_at": now,
        "log": log,
        "platform": identity.platform,
        "arch": identity.arch,
        "backend": identity.backend,
        "real_score_available": sem.real_score_available,
        "training_mode": sem.training_mode,
        "score_mode": sem.score_mode,
        "semantic_reason": sem.reason,
        "saw_scalar_console": metrics.saw_scalar_console,
        "saw_direct_score": metrics.saw_direct_score,
        "saw_hi_timing": metrics.saw_hi_timing,
        "saw_real_score": metrics.saw_real_score,
        "saw_qatum_reference_score": metrics.saw_qatum_reference_score,
    }

    heartbeat = {
        "run_id": run_id,
        "rig_id": identity.rig_id,
        "worker_name": identity.worker_name,
        "status": "running",
        "live_status": "running",
        "threshold": identity.threshold,
        "threads": identity.threads,
        "backend": identity.backend,
        "active_backend": identity.backend,
        "avg_its": metrics.avg_its,
        "last_its": metrics.last_its,
        "total_seen": total_seen,
        "total_pass": total_pass,
        "total_skip": 0,
        "total_audited": total_audited,
        "false_negative": 0,
        "max_real_score_passed": max_score,
        "max_real_score_audited_skip": max_score,
        "pass_rate": (total_pass / total_audited) if total_audited else 0,
        "meta": raw,
    }

    perf = {
        "rig_id": identity.rig_id,
        "run_id": run_id,
        "worker_name": identity.worker_name,
        "threshold": identity.threshold,
        "backend": identity.backend,
        "threads": identity.threads,
        "avg_its": metrics.avg_its,
        "last_its": metrics.last_its,
        "total_seen": total_seen,
        "total_pass": total_pass,
        "total_audited": total_audited,
        "fullscore_count": sem.fullscore_count,
        "false_negative": 0,
        "real300": real300,
        "real310": real310,
        "real321": real321,
        "router_name": identity.router,
        "priority_budget_matrix": identity.matrix,
        "algo0_avg_ms": metrics.algo0_avg_ms,
        "raw": raw,
    }

    score = {
        "run_id": run_id,
        "rig_id": identity.rig_id,
        "worker_name": identity.worker_name,
        "epoch": identity.epoch,
        "backend": identity.backend,
        "threshold": identity.threshold,
        "threads": identity.threads,
        "batch_size": 0,
        "audit_rate": 500,
        "total_seen": total_seen,
        "total_pass": total_pass,
        "total_skip": 0,
        "total_audited": total_audited,
        "false_negative": 0,
        "max_score": max_score,
        "max_pass_score": max_score,
        "max_audited_skip_score": max_score,
        "score_260_269": bucket(scores, 260, 269),
        "score_270_279": bucket(scores, 270, 279),
        "score_280_289": bucket(scores, 280, 289),
        "score_290_299": bucket(scores, 290, 299),
        "score_300_309": bucket(scores, 300, 309),
        "score_310_320": bucket(scores, 310, 320),
        "score_321_plus": bucket(scores, 321),
        "raw": raw,
    }

    priority = {
        "run_id": run_id,
        "rig_id": identity.rig_id,
        "worker_name": identity.worker_name,
        "threshold": identity.threshold,
        "version": identity.router,
        "router_name": identity.router,
        "matrix": identity.matrix,
        "priority_budget_matrix": identity.matrix,
        "audited_skip": total_audited,
        "false_negative": 0,
        "p0_seen": total_seen,
        "p0_scored": total_audited,
        "p0_skipped": 0,
        "p0_score_rate": (total_audited / total_seen) if total_seen else 0,
        "p0_real280": bucket(scores, 280),
        "p0_real290": bucket(scores, 290),
        "p0_real300": real300,
        "p0_real310": real310,
        "p0_real321": real321,
        "p0_d300": real300,
        "p0_d321": real321,
        "raw": raw,
    }

    for i in (1, 2, 3):
        for k in ("seen","scored","skipped","score_rate","real280","real290","real300","real310","real321","d300","d321"):
            priority[f"p{i}_{k}"] = 0

    policy = {
        "run_id": run_id,
        "rig_id": identity.rig_id,
        "worker_name": identity.worker_name,
        "threshold": identity.threshold,
        "policy_name": identity.router,
        "router_name": identity.router,
        "pass": total_pass,
        "real280": bucket(scores, 280),
        "real290": bucket(scores, 290),
        "real300": real300,
        "real310": real310,
        "real321": real321,
        "pass_per_seen": (total_pass / total_seen) if total_seen else 0,
        "real300_per_pass": (real300 / total_pass) if total_pass else 0,
        "real310_per_pass": (real310 / total_pass) if total_pass else 0,
        "raw": raw,
    }

    histogram = {
        "run_id": run_id,
        "rig_id": identity.rig_id,
        "worker_name": identity.worker_name,
        "threshold": identity.threshold,
        "router_name": identity.router,
        "priority_budget_matrix": identity.matrix,
        "rows": [
            {"shadow_score": b, "total": bucket(scores, b), "real300": real300, "real310": real310, "real321": real321}
            for b in [270, 280, 290, 300, 310, 321]
        ],
        "raw": raw,
    }

    return [
        ("/analytics/runs/heartbeat", heartbeat),
        ("/analytics/performance-snapshot", perf),
        ("/analytics/score-distribution-snapshot", score),
        ("/analytics/priority-budget-snapshot", priority),
        ("/analytics/shadow-policy-snapshot", policy),
        ("/analytics/shadow-histogram-snapshot", histogram),
    ], sem
