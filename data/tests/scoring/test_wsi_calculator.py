"""Unit tests for WSI calculator (no DB, no external deps)."""

from halo_data.scoring.wsi_calculator import SegmentFeatures, calculate_wsi


def _features(**kwargs: object) -> SegmentFeatures:
    defaults: dict[str, object] = {
        "segment_id": "test-seg",
        "avg_lux": 30.0,
        "incident_count_90d": 5,
        "avg_noise_db": 55.0,
    }
    defaults.update(kwargs)
    return SegmentFeatures(**defaults)  # type: ignore[arg-type]


def test_perfect_conditions_gives_high_score() -> None:
    features = _features(avg_lux=100.0, incident_count_90d=0, avg_noise_db=30.0)
    result = calculate_wsi(features)
    assert result.wsi_score >= 0.95
    assert result.lighting_score == 1.0
    assert result.incident_score == 1.0
    assert result.noise_score == 1.0


def test_worst_conditions_gives_low_score() -> None:
    features = _features(avg_lux=0.0, incident_count_90d=30, avg_noise_db=85.0)
    result = calculate_wsi(features)
    assert result.wsi_score == 0.0


def test_score_is_bounded_0_to_1() -> None:
    for lux in [0, 10, 50, 200]:
        for incidents in [0, 5, 50]:
            for noise in [20.0, 55.0, 100.0]:
                features = _features(avg_lux=float(lux), incident_count_90d=incidents, avg_noise_db=noise)
                result = calculate_wsi(features)
                assert 0.0 <= result.wsi_score <= 1.0, f"Out of range: {result}"


def test_more_lighting_improves_score() -> None:
    low = calculate_wsi(_features(avg_lux=5.0))
    high = calculate_wsi(_features(avg_lux=45.0))
    assert high.wsi_score > low.wsi_score


def test_more_incidents_lowers_score() -> None:
    few = calculate_wsi(_features(incident_count_90d=0))
    many = calculate_wsi(_features(incident_count_90d=20))
    assert few.wsi_score > many.wsi_score


def test_segment_id_is_preserved() -> None:
    result = calculate_wsi(_features(segment_id="seg-xyz-42"))
    assert result.segment_id == "seg-xyz-42"
