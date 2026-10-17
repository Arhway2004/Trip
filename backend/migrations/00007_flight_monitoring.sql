-- +goose Up
-- Agency flight monitoring: bookings point to shared operating flights; each
-- flight (code + departure date) is refreshed once per interval for everyone.

-- Customer side: who booked what. Customer details never go in the flight cache.
CREATE TABLE bookings (
    id         UUID PRIMARY KEY,
    owner_id   UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    trip_id    UUID        REFERENCES trips (id) ON DELETE SET NULL,
    traveler   TEXT        NOT NULL CHECK (length(btrim(traveler)) BETWEEN 1 AND 200),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX bookings_owner_idx ON bookings (owner_id, created_at DESC);

-- Flight side: one row per operating flight and departure date.
CREATE TABLE flights (
    id                   UUID PRIMARY KEY,
    code                 TEXT        NOT NULL CHECK (code ~ '^([A-Z0-9]{2}|[A-Z]{3})[0-9]{1,4}[A-Z]?$'),
    flight_date          DATE        NOT NULL,
    status               JSONB,      -- latest successful answer (domain.Status)
    last_checked_at      TIMESTAMPTZ,
    last_success_at      TIMESTAMPTZ,
    next_check_at        TIMESTAMPTZ, -- NULL = no more checks (landed, cancelled, past)
    consecutive_failures INTEGER     NOT NULL DEFAULT 0 CHECK (consecutive_failures >= 0),
    created_at           TIMESTAMPTZ NOT NULL,
    UNIQUE (code, flight_date)
);

CREATE INDEX flights_due_idx ON flights (next_check_at) WHERE next_check_at IS NOT NULL;

CREATE TABLE booking_segments (
    id         UUID PRIMARY KEY,
    booking_id UUID     NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
    position   SMALLINT NOT NULL CHECK (position BETWEEN 0 AND 19),
    flight_id  UUID     NOT NULL REFERENCES flights (id) ON DELETE RESTRICT,
    UNIQUE (booking_id, position)
);

CREATE INDEX booking_segments_flight_idx ON booking_segments (flight_id);

-- History: the first answer ("original") and every answer that changed something.
CREATE TABLE flight_snapshots (
    id          BIGSERIAL PRIMARY KEY,
    flight_id   UUID        NOT NULL REFERENCES flights (id) ON DELETE CASCADE,
    fetched_at  TIMESTAMPTZ NOT NULL,
    is_original BOOLEAN     NOT NULL DEFAULT FALSE,
    status      JSONB       NOT NULL
);

CREATE INDEX flight_snapshots_flight_idx ON flight_snapshots (flight_id, fetched_at);

CREATE TABLE flight_changes (
    id          BIGSERIAL PRIMARY KEY,
    flight_id   UUID        NOT NULL REFERENCES flights (id) ON DELETE CASCADE,
    detected_at TIMESTAMPTZ NOT NULL,
    kind        TEXT        NOT NULL CHECK (kind IN ('status', 'departureTime', 'arrivalTime', 'departureTerminal',
                                                     'departureGate', 'arrivalTerminal', 'arrivalGate', 'baggageBelt')),
    old_value   TEXT,
    new_value   TEXT        NOT NULL,
    notified_at TIMESTAMPTZ -- set by the notification worker
);

CREATE INDEX flight_changes_flight_idx ON flight_changes (flight_id, detected_at);
CREATE INDEX flight_changes_unnotified_idx ON flight_changes (id) WHERE notified_at IS NULL;

-- Provider requests per month, so the plan's quota is never exceeded.
CREATE TABLE flight_provider_usage (
    provider TEXT    NOT NULL,
    month    TEXT    NOT NULL CHECK (month ~ '^[0-9]{4}-[0-9]{2}$'),
    requests INTEGER NOT NULL DEFAULT 0 CHECK (requests >= 0),
    PRIMARY KEY (provider, month)
);

-- +goose Down
DROP TABLE flight_provider_usage;
DROP TABLE flight_changes;
DROP TABLE flight_snapshots;
DROP TABLE booking_segments;
DROP TABLE flights;
DROP TABLE bookings;
