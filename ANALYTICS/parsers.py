#!/usr/bin/env python3
from dataclasses import dataclass, field
import os
import re

@dataclass
class Metrics:
    total_seen: int = 0
    total_audited: int = 0
    scores: list = field(default_factory=list)
    max_score: int = 0
    avg_its: float = 0.0
    last_its: float = 0.0
    algo0_avg_ms: float = 0.0

    saw_scalar_console: bool = False
    saw_direct_score: bool = False
    saw_hi_timing: bool = False
    saw_real_score: bool = False
    saw_qatum_reference_score: bool = False

def _tail(path, max_bytes=512000):
    if not path or not os.path.exists(path):
        return ""
    with open(path, "rb") as f:
        f.seek(max(0, os.path.getsize(path) - max_bytes))
        return f.read().decode("utf-8", errors="ignore")

def parse_log(path):
    text = _tail(path)
    m = Metrics()
    direct_seen = 0
    direct_avg_sum = 0.0
    direct_avg_n = 0

    for line in text.splitlines():
        if "[HI_TIMING" in line:
            m.saw_hi_timing = True
            for rx in (r"\bglobal_count=([0-9]+)", r"\btotal=([0-9]+)", r"\balgo0_count=([0-9]+)"):
                g = re.search(rx, line)
                if g:
                    v = int(g.group(1))
                    m.total_seen = max(m.total_seen, v)
                    m.total_audited = max(m.total_audited, v)
            g = re.search(r"\balgo0_avg_ms=([0-9]+(?:\.[0-9]+)?)", line)
            if g:
                m.algo0_avg_ms = float(g.group(1))

            # ARM reference HI_TIMING format:
            # [HI_TIMING] ... last_ms=21009.7 local_avg_ms=21494.9 score=308 algo=0
            hm = re.search(r"\blocal_avg_ms=([0-9]+(?:\.[0-9]+)?)", line)
            if hm:
                m.algo0_avg_ms = float(hm.group(1))
            # M1091U4_HI_TIMING_IS_TIMING_NOT_SCORE_SAMPLE
            # HI_TIMING is used for timing/counts only.
            # Authoritative ARM score samples come from REAL_SCORE_AUDIT_DEBUG.

        pm = re.search(r"(?i)\|\s*\[([A-Z0-9_-]+)\]\s*([0-9]+(?:\.[0-9]+)?)\s*it/s\s*\|\s*([0-9]+(?:\.[0-9]+)?)\s*avg\s*it/s", line)
        if pm:
            m.saw_scalar_console = True
            m.last_its = float(pm.group(2))
            m.avg_its = float(pm.group(3))

        if "[DIRECT_SCORE]" in line:
            m.saw_direct_score = True
            for dm in re.finditer(r"\bchecked=([0-9]+)\b", line):
                v = int(dm.group(1))
                if 0 < v <= 4096:
                    direct_seen += v
            for am in re.finditer(r"\bavg_ms=([0-9]+(?:\.[0-9]+)?)", line):
                v = float(am.group(1))
                if 0 < v < 10:
                    direct_avg_sum += v
                    direct_avg_n += 1

        # M1091U3_PARSE_REAL_SCORE_AUDIT_DEBUG
        # Authoritative ARM/macOS reference scorer emits:
        # [REAL_SCORE_AUDIT_DEBUG] ... count=N shadow_score=X real_score=Y algo=0 ...
        if "QATUM_REFERENCE_SCORE" in line or "QATUM_REAL_SCORE" in line:
            m.saw_qatum_reference_score = True

        if "REAL_SCORE" in line:
            m.saw_real_score = True

        if "[REAL_SCORE_AUDIT_DEBUG]" in line:
            m.saw_real_score = True

            cm = re.search(r"\bcount=([0-9]+)", line)
            if cm:
                c = int(cm.group(1))
                if c > 0:
                    m.total_seen = max(m.total_seen, c)
                    m.total_audited = max(m.total_audited, c)

            rm = re.search(r"\breal_score=([0-9]+)", line)
            if rm:
                score = int(rm.group(1))
                m.scores.append(score)
                m.max_score = max(m.max_score, score)

        for sm in re.finditer(r"\breal_score=([0-9]+)", line):
            s = int(sm.group(1))
            if s not in m.scores[-3:]:
                m.scores.append(s)
            m.max_score = max(m.max_score, s)

    if m.total_seen <= 0 and direct_seen > 0:
        m.total_seen = direct_seen
        m.total_audited = direct_seen

    if m.algo0_avg_ms <= 0 and direct_avg_n > 0:
        m.algo0_avg_ms = direct_avg_sum / direct_avg_n

    return m

def bucket(scores, lo, hi=None):
    if hi is None:
        return sum(1 for s in scores if s >= lo)
    return sum(1 for s in scores if lo <= s <= hi)
