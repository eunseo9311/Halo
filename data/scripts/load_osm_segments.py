#!/usr/bin/env python3
"""
Download pedestrian-accessible street segments for downtown LA
from the Overpass API and bulk-upsert them into street_segments.

WSI scores are set to a neutral placeholder (0.5) — the Python
pipeline (feature/python-pipeline) will overwrite them with real
rule-based scores once feature data is available.

Usage:
    cd data/
    uv run python scripts/load_osm_segments.py

Env var required:
    DATABASE_URL=postgresql://halo:halo_secret@localhost:5432/halo
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from urllib.parse import urlencode

import psycopg
from dotenv import load_dotenv

# ── Area of interest ─────────────────────────────────────────────────────────
# Downtown LA, roughly 4 km × 5 km bounding box.
# Overpass bbox format: (south, west, north, east)
BBOX = (34.03, -118.27, 34.07, -118.22)

# OSM highway tags that are meaningful for pedestrian routing
_PEDESTRIAN_HIGHWAYS = "|".join([
    "primary", "secondary", "tertiary",
    "residential", "living_street", "unclassified",
    "footway", "path", "pedestrian", "steps",
])

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Placeholder values until the real scoring pipeline runs
_PLACEHOLDER_WSI = 0.5
_PLACEHOLDER_CONFIDENCE = 0.0


# ── Overpass fetch ────────────────────────────────────────────────────────────

def _build_query(bbox: tuple[float, float, float, float]) -> str:
    s, w, n, e = bbox
    return f"""
[out:json][timeout:60];
(
  way["highway"~"^({_PEDESTRIAN_HIGHWAYS})$"]({s},{w},{n},{e});
);
out body;
>;
out skel qt;
""".strip()


def fetch_osm(bbox: tuple[float, float, float, float]) -> dict:
    query = _build_query(bbox)
    payload = urlencode({"data": query}).encode()
    req = urllib.request.Request(
        OVERPASS_URL,
        data=payload,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "HaloApp/0.1 (SafeSound LA pedestrian routing; contact@safesoundla.com)",
        },
    )
    print(f"Querying Overpass API for bbox {bbox} …")
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read().decode())


# ── Parse segments ────────────────────────────────────────────────────────────

def parse_segments(osm: dict) -> list[dict]:
    """
    Convert OSM ways into a flat list of consecutive-node segments.

    Each way [A → B → C → D] produces segments [A→B, B→C, C→D].
    segment_id = "osm-{way_id}-{index}" — stable, traceable back to OSM.
    """
    nodes: dict[int, tuple[float, float]] = {}
    for el in osm["elements"]:
        if el["type"] == "node":
            nodes[el["id"]] = (el["lat"], el["lon"])

    segments: list[dict] = []
    for el in osm["elements"]:
        if el["type"] != "way":
            continue
        way_id = el["id"]
        refs = el.get("nodes", [])
        for i in range(len(refs) - 1):
            n1, n2 = refs[i], refs[i + 1]
            if n1 not in nodes or n2 not in nodes:
                continue
            lat1, lng1 = nodes[n1]
            lat2, lng2 = nodes[n2]
            segments.append({
                "segment_id": f"osm-{way_id}-{i}",
                "start_lat": lat1,
                "start_lng": lng1,
                "end_lat": lat2,
                "end_lng": lng2,
            })

    return segments


# ── DB upsert ─────────────────────────────────────────────────────────────────

_UPSERT_SQL = """
INSERT INTO street_segments
    (segment_id, wsi_score, confidence, start_lat, start_lng, end_lat, end_lng)
VALUES
    (%s, %s, %s, %s, %s, %s, %s)
ON CONFLICT (segment_id) DO UPDATE SET
    wsi_score   = EXCLUDED.wsi_score,
    confidence  = EXCLUDED.confidence,
    updated_at  = NOW()
"""


def upsert_segments(conn: psycopg.Connection, segments: list[dict]) -> int:
    rows = [
        (
            seg["segment_id"],
            _PLACEHOLDER_WSI,
            _PLACEHOLDER_CONFIDENCE,
            seg["start_lat"],
            seg["start_lng"],
            seg["end_lat"],
            seg["end_lng"],
        )
        for seg in segments
    ]
    with conn.cursor() as cur:
        cur.executemany(_UPSERT_SQL, rows)
    conn.commit()
    return len(rows)


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    load_dotenv()
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        print("ERROR: DATABASE_URL env var not set", file=sys.stderr)
        sys.exit(1)

    osm = fetch_osm(BBOX)

    segments = parse_segments(osm)
    print(f"Parsed {len(segments)} segments from OSM")

    if not segments:
        print("No segments found — check bbox and highway filter.")
        return

    with psycopg.connect(db_url) as conn:
        count = upsert_segments(conn, segments)

    print(f"✓ Upserted {count} segments into street_segments")


if __name__ == "__main__":
    main()
