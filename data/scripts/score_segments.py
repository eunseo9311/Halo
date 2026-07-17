#!/usr/bin/env python3
"""
WSI scoring pipeline — reads segment IDs from street_segments,
computes WSI scores, and writes results back to the DB.

Feature values are currently *mock* (derived deterministically from
segment_id hash) so the pipeline can run end-to-end without external
data sources.  When real data is available, replace _mock_features()
with functions that read LAPD incident counts, streetlight proximity, etc.

Usage:
    cd data/
    uv run python scripts/score_segments.py              # score all, write to DB
    uv run python scripts/score_segments.py --dry-run    # print without writing
    uv run python scripts/score_segments.py --hour 22    # score for 10 pm
    uv run python scripts/score_segments.py --limit 100  # score first 100 only

Env var required:
    DATABASE_URL=postgresql://halo:halo_secret@localhost:5432/halo
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys

import psycopg
from dotenv import load_dotenv

sys.path.insert(0, "src")
from halo_data.scoring.wsi_calculator import SegmentFeatures, SegmentWsi, calculate_wsi

# Confidence level for mock-sourced scores.
# Real data sources (LAPD, streetlights) should push this toward 1.0.
_MOCK_CONFIDENCE = 0.3

_BATCH_SIZE = 500  # rows per executemany call


# ── Mock feature derivation ───────────────────────────────────────────────────

def _mock_features(segment_id: str, hour: int) -> SegmentFeatures:
    """
    Deterministic mock features derived from segment_id hash.

    The hash spreads segments across the full WSI range so the map shows
    a realistic mix of GREEN / YELLOW / RED without real sensor data.
    Night hours (21–05) apply a lighting penalty to reflect real conditions.
    """
    h = int(hashlib.md5(segment_id.encode()).hexdigest(), 16)

    # Lighting: 1–59 lux, reduced at night
    base_lux = float(1 + h % 59)
    is_night = hour >= 21 or hour <= 5
    avg_lux = base_lux * (0.25 if is_night else 1.0)

    # Incidents in last 90 days: 0–24
    incident_count_90d = (h >> 8) % 25

    # Noise: 35–84 dB(A)
    avg_noise_db = 35.0 + float((h >> 16) % 50)

    return SegmentFeatures(
        segment_id=segment_id,
        avg_lux=avg_lux,
        incident_count_90d=incident_count_90d,
        avg_noise_db=avg_noise_db,
    )


# ── DB I/O ────────────────────────────────────────────────────────────────────

def _fetch_segment_ids(conn: psycopg.Connection, limit: int | None) -> list[str]:
    sql = "SELECT segment_id FROM street_segments ORDER BY segment_id"
    if limit:
        sql += f" LIMIT {limit}"
    with conn.cursor() as cur:
        cur.execute(sql)
        return [row[0] for row in cur.fetchall()]


_UPDATE_SQL = """
UPDATE street_segments
SET
    wsi_score  = %s,
    confidence = %s,
    hour_of_day = %s,
    scored_at  = NOW(),
    updated_at = NOW()
WHERE segment_id = %s
"""


def _write_scores(conn: psycopg.Connection, scores: list[SegmentWsi], hour: int) -> int:
    rows = [
        (s.wsi_score, s.confidence, hour, s.segment_id)
        for s in scores
    ]
    written = 0
    with conn.cursor() as cur:
        for i in range(0, len(rows), _BATCH_SIZE):
            batch = rows[i : i + _BATCH_SIZE]
            cur.executemany(_UPDATE_SQL, batch)
            written += len(batch)
    conn.commit()
    return written


# ── Reporting ─────────────────────────────────────────────────────────────────

def _band(score: float) -> str:
    return "🟢" if score >= 0.7 else ("🟡" if score >= 0.4 else "🔴")


def _print_summary(scores: list[SegmentWsi]) -> None:
    green  = sum(1 for s in scores if s.wsi_score >= 0.7)
    yellow = sum(1 for s in scores if 0.4 <= s.wsi_score < 0.7)
    red    = sum(1 for s in scores if s.wsi_score < 0.4)
    avg    = sum(s.wsi_score for s in scores) / len(scores) if scores else 0.0

    print(f"\n{'─'*50}")
    print(f"  Segments scored : {len(scores):>6}")
    print(f"  🟢 GREEN  (≥0.7): {green:>6}  ({green/len(scores)*100:.1f}%)")
    print(f"  🟡 YELLOW (0.4–): {yellow:>6}  ({yellow/len(scores)*100:.1f}%)")
    print(f"  🔴 RED    (<0.4): {red:>6}  ({red/len(scores)*100:.1f}%)")
    print(f"  Average WSI     : {avg:.3f}")
    print(f"{'─'*50}\n")


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Compute and store WSI scores")
    parser.add_argument("--hour",    type=int, default=22, help="Hour of day 0–23 (default: 22)")
    parser.add_argument("--limit",   type=int, default=None, help="Process only first N segments")
    parser.add_argument("--dry-run", action="store_true", help="Compute but do not write to DB")
    args = parser.parse_args()

    load_dotenv()
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        print("ERROR: DATABASE_URL not set", file=sys.stderr)
        sys.exit(1)

    with psycopg.connect(db_url) as conn:
        segment_ids = _fetch_segment_ids(conn, args.limit)
        print(f"Fetched {len(segment_ids)} segment IDs (hour={args.hour:02d}:00)")

        scores: list[SegmentWsi] = [
            calculate_wsi(_mock_features(sid, args.hour), confidence=_MOCK_CONFIDENCE)
            for sid in segment_ids
        ]

        _print_summary(scores)

        if args.dry_run:
            print("Dry-run mode — no DB writes.")
            return

        written = _write_scores(conn, scores, args.hour)
        print(f"✓ Updated {written} rows in street_segments")


if __name__ == "__main__":
    main()
