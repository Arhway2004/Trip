-- +goose Up
-- Keep mobile packages losslessly while web planning editors are introduced.
-- Media stays in the package; it is never written to paths from the archive.
CREATE TABLE imported_trip_packages (
    trip_id UUID PRIMARY KEY REFERENCES trips(id) ON DELETE CASCADE,
    package JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE imported_trip_packages;
