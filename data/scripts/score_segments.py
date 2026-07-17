#!/usr/bin/env python3
"""
Sample scoring script — rule-based WSI calculation on dummy coordinates.

Usage:
    uv run python scripts/score_segments.py
    uv run python scripts/score_segments.py --hour 22

This script demonstrates the pipeline structure without real data.
Replace dummy_segments() with actual DB/file reads in future iterations.
"""

from __future__ import annotations

import argparse
import json
import sys

sys.path.insert(0, "src")  # resolve halo_data package when run from data/

from halo_data.scoring.wsi_calculator import SegmentFeatures, SegmentWsi, calculate_wsi


def dummy_segments(hour: int) -> list[SegmentFeatures]:
    """
    Placeholder: returns hardcoded segment features.
    Replace with DB query or CSV read in real pipeline.
    """
    # Night hours (21–05): lower lighting
    is_night = hour >= 21 or hour <= 5
    base_lux = 8.0 if is_night else 35.0

    return [
        SegmentFeatures(
            segment_id="seg-downtown-main-01",
            avg_lux=base_lux * 1.5,  # well-lit block
            incident_count_90d=3,
            avg_noise_db=62.0,
        ),
        SegmentFeatures(
            segment_id="seg-downtown-alley-07",
            avg_lux=base_lux * 0.2,  # poorly lit alley
            incident_count_90d=18,
            avg_noise_db=48.0,
        ),
        SegmentFeatures(
            segment_id="seg-residential-oak-03",
            avg_lux=base_lux,
            incident_count_90d=1,
            avg_noise_db=40.0,
        ),
    ]


def print_results(results: list[SegmentWsi]) -> None:
    for r in results:
        band = "🟢" if r.wsi_score >= 0.7 else ("🟡" if r.wsi_score >= 0.4 else "🔴")
        print(
            f"{band} {r.segment_id:<35} "
            f"WSI={r.wsi_score:.3f}  "
            f"(light={r.lighting_score:.2f}, "
            f"incident={r.incident_score:.2f}, "
            f"noise={r.noise_score:.2f}, "
            f"confidence={r.confidence:.2f})"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Score street segments")
    parser.add_argument("--hour", type=int, default=22, help="Hour of day 0-23 (default: 22)")
    parser.add_argument("--json", action="store_true", help="Output JSON instead of pretty print")
    args = parser.parse_args()

    segments = dummy_segments(args.hour)
    results = [calculate_wsi(f) for f in segments]

    if args.json:
        import dataclasses
        print(json.dumps([dataclasses.asdict(r) for r in results], indent=2))
    else:
        print(f"\n=== WSI Scores (hour={args.hour:02d}:00) ===")
        print_results(results)
        avg = sum(r.wsi_score for r in results) / len(results)
        print(f"\nAverage WSI: {avg:.3f}")


if __name__ == "__main__":
    main()
