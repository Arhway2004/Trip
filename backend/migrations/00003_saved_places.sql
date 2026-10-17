-- +goose Up
-- Places saved to a trip from search, "explore nearby" or a map tap (mobile
-- schema v5). Coordinates are WGS84 and required: a saved place always has
-- real coordinates from a provider, a map tap or an import, never invented ones.
CREATE TABLE saved_places (
    id                UUID PRIMARY KEY,
    trip_id           UUID             NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    name              TEXT             NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 300),
    category          TEXT             NOT NULL DEFAULT 'attraction' CHECK (category IN
        ('attraction', 'restaurant', 'hotel', 'airport', 'railwayStation', 'busStation', 'other')),
    lat               DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN -90 AND 90),
    lng               DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN -180 AND 180),
    address           TEXT,
    coordinate_source TEXT,            -- 'map' | 'search:<provider>' | 'import'
    notes             TEXT,
    created_by        UUID             REFERENCES users (id) ON DELETE SET NULL,
    version           BIGINT           NOT NULL DEFAULT 1,
    created_at        TIMESTAMPTZ      NOT NULL,
    updated_at        TIMESTAMPTZ      NOT NULL
);

CREATE INDEX saved_places_trip_idx ON saved_places (trip_id, category);

CREATE TRIGGER saved_places_sync AFTER INSERT OR UPDATE OR DELETE ON saved_places
    FOR EACH ROW EXECUTE FUNCTION record_sync_change();

-- +goose Down
DROP TRIGGER saved_places_sync ON saved_places;
DROP TABLE saved_places;
