#!/usr/bin/env python3
from dataclasses import dataclass

@dataclass(frozen=True)
class Semantics:
    real_score_available: bool
    training_mode: str
    score_mode: str
    fullscore_count: int
    reason: str

def classify(identity, metrics):
    backend = (identity.backend or "").lower()
    platform = (identity.platform or "").lower()

    if "avx512" in backend and metrics.saw_hi_timing:
        return Semantics(True, "real_score", "avx512_hi_timing", metrics.total_audited, "avx512_hi_timing")

    if ("arm" in backend or "arm" in platform or "macos" in platform) and (
        metrics.saw_qatum_reference_score or metrics.saw_real_score
    ):
        return Semantics(True, "real_score", "arm_qatum_reference", metrics.total_audited, "explicit_arm_real_score_marker")

    if metrics.saw_scalar_console or metrics.saw_direct_score:
        return Semantics(False, "shadow_only", "portable_scalar_diagnostic", 0, "scalar_or_direct_score_without_real_score_marker")

    return Semantics(False, "shadow_only", "unknown", 0, "no_real_score_evidence")
