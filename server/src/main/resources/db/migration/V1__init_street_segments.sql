-- V1: Initial schema for street segments with WSI scores
-- PostGIS extension is required: enabled in docker-compose via postgis/postgis image

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS street_segments (
    id           BIGSERIAL PRIMARY KEY,
    segment_id   VARCHAR(64)    NOT NULL UNIQUE,
    wsi_score    DECIMAL(4, 3)  NOT NULL CHECK (wsi_score >= 0 AND wsi_score <= 1),
    confidence   DECIMAL(4, 3)  NOT NULL DEFAULT 0 CHECK (confidence >= 0 AND confidence <= 1),

    -- Simple bounding coordinates (MVP placeholder)
    -- TODO: replace with geometry column once hibernate-spatial is wired up:
    --   segment_path  geometry(LineString, 4326)
    start_lat    DECIMAL(10, 7) NOT NULL,
    start_lng    DECIMAL(10, 7) NOT NULL,
    end_lat      DECIMAL(10, 7) NOT NULL,
    end_lng      DECIMAL(10, 7) NOT NULL,

    hour_of_day  SMALLINT       CHECK (hour_of_day >= 0 AND hour_of_day <= 23),
    scored_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_street_segments_wsi ON street_segments (wsi_score);
CREATE INDEX IF NOT EXISTS idx_street_segments_scored_at ON street_segments (scored_at DESC);
