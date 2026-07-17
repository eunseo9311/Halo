"""
WSI (Walkability/Safety Index) calculator — rule-based MVP.

Score components (all 0.0–1.0, higher = better):
  - lighting_score:  derived from streetlight density near segment
  - incident_score:  inverse of normalized incident count
  - noise_score:     inverse of normalized noise level

Final WSI = weighted sum of component scores.

This module is intentionally framework-free so it can be unit-tested
without any DB or external dependency.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SegmentFeatures:
    """Raw feature values for a single street segment."""

    segment_id: str
    # Lighting: average lux level (0–∞; capped at MAX_LUX for scoring)
    avg_lux: float
    # Incidents: count in last 90 days within 100m radius
    incident_count_90d: int
    # Noise: average dB(A) during scoring window
    avg_noise_db: float


@dataclass(frozen=True)
class SegmentWsi:
    """Computed WSI and sub-scores for a street segment."""

    segment_id: str
    wsi_score: float        # 0.0–1.0 (final composite)
    lighting_score: float   # 0.0–1.0
    incident_score: float   # 0.0–1.0
    noise_score: float      # 0.0–1.0
    confidence: float       # 0.0–1.0 (data availability)


# ── Tunable constants ────────────────────────────────────────────────────────

# Lux threshold at which lighting score saturates to 1.0
_MAX_LUX: float = 50.0

# Incident count at which incident score reaches 0.0 (fully penalised)
_MAX_INCIDENTS: int = 30

# Noise level (dB) at which noise score reaches 0.0
_MAX_NOISE_DB: float = 85.0
_MIN_NOISE_DB: float = 30.0   # ambient baseline

# Composite weights (must sum to 1.0)
_WEIGHTS: dict[str, float] = {
    "lighting": 0.50,
    "incident": 0.35,
    "noise": 0.15,
}


# ── Core calculation ─────────────────────────────────────────────────────────


def calculate_wsi(features: SegmentFeatures, confidence: float = 1.0) -> SegmentWsi:
    """
    Compute WSI score from raw segment features.

    Args:
        features:   Raw sensor/data values for the segment.
        confidence: Data availability ratio (0.0 = no data, 1.0 = full coverage).

    Returns:
        SegmentWsi with final score and sub-scores.
    """
    lighting = _score_lighting(features.avg_lux)
    incident = _score_incidents(features.incident_count_90d)
    noise = _score_noise(features.avg_noise_db)

    wsi = (
        _WEIGHTS["lighting"] * lighting
        + _WEIGHTS["incident"] * incident
        + _WEIGHTS["noise"] * noise
    )

    return SegmentWsi(
        segment_id=features.segment_id,
        wsi_score=round(wsi, 4),
        lighting_score=round(lighting, 4),
        incident_score=round(incident, 4),
        noise_score=round(noise, 4),
        confidence=round(confidence, 4),
    )


def _score_lighting(avg_lux: float) -> float:
    """Higher lux → score closer to 1.0."""
    if avg_lux <= 0:
        return 0.0
    return min(avg_lux / _MAX_LUX, 1.0)


def _score_incidents(count: int) -> float:
    """Fewer incidents → score closer to 1.0."""
    if count <= 0:
        return 1.0
    return max(1.0 - count / _MAX_INCIDENTS, 0.0)


def _score_noise(avg_db: float) -> float:
    """Lower noise → score closer to 1.0. Clamped to [0.0, 1.0]."""
    noise_range = _MAX_NOISE_DB - _MIN_NOISE_DB
    normalised = (avg_db - _MIN_NOISE_DB) / noise_range
    return max(0.0, min(1.0, 1.0 - normalised))
