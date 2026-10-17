-- +goose Up
-- Full WanderPlan domain schema (PostgreSQL 15+).
--
-- Conventions
--   * Primary keys are client-generated UUIDs (the app creates records offline).
--   * Enumerations are TEXT + CHECK (easy to extend in later migrations).
--   * Every synced row carries `version` (optimistic concurrency / ETag).
--   * Money is NUMERIC(14,2); exchange rates NUMERIC(20,10).
--   * Local calendar dates are DATE; times of day are minutes after midnight
--     (SMALLINT), local to the trip's time zone, exactly like the app.
--   * Coordinates are WGS84 decimal degrees (PostGIS can be added later).
--   * Changes to trip data are captured by a trigger into sync_changes,
--     which drives the app's pull-based sync.

-- ---------------------------------------------------------------- trips (tighten v1)

ALTER TABLE trips
    ADD CONSTRAINT trips_currency_format CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
    ADD CONSTRAINT trips_budget_needs_currency CHECK (total_budget IS NULL OR currency IS NOT NULL),
    ADD CONSTRAINT trips_stage_valid CHECK (stage IN ('dreaming', 'planning')),
    ADD CONSTRAINT trips_travel_style_valid CHECK (travel_style IS NULL OR travel_style IN
        ('relaxed', 'balanced', 'packed', 'budget', 'comfort', 'luxury', 'adventure', 'family')),
    ADD CONSTRAINT trips_title_length CHECK (char_length(title) <= 200),
    ADD CONSTRAINT trips_departure_needs_start CHECK (departure_time IS NULL OR start_date IS NOT NULL);

CREATE INDEX trips_owner_idx ON trips (owner_id);

-- ---------------------------------------------------------------- media

-- Binary files live in object storage (S3/R2); this table is their catalogue.
CREATE TABLE media_objects (
    id           UUID PRIMARY KEY,
    owner_id     UUID        NOT NULL REFERENCES users (id),
    trip_id      UUID        REFERENCES trips (id) ON DELETE CASCADE,
    storage_key  TEXT        NOT NULL UNIQUE,
    content_type TEXT        NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf')),
    byte_size    BIGINT      NOT NULL CHECK (byte_size > 0 AND byte_size <= 52428800),
    width        INTEGER     CHECK (width > 0),
    height       INTEGER     CHECK (height > 0),
    sha256       BYTEA       CHECK (octet_length(sha256) = 32),
    status       TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'uploaded', 'deleted')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    uploaded_at  TIMESTAMPTZ,
    CHECK ((status = 'uploaded') = (uploaded_at IS NOT NULL) OR status = 'deleted')
);

CREATE INDEX media_objects_trip_idx ON media_objects (trip_id);

-- ---------------------------------------------------------------- trip aggregate children

CREATE TABLE trip_destinations (
    id       UUID PRIMARY KEY,
    trip_id  UUID    NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    position INTEGER NOT NULL CHECK (position >= 0), -- 0 = main destination
    city     TEXT,
    country  TEXT,
    CHECK (nullif(btrim(city), '') IS NOT NULL OR nullif(btrim(country), '') IS NOT NULL),
    UNIQUE (trip_id, position) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE trip_banners (
    trip_id         UUID PRIMARY KEY REFERENCES trips (id) ON DELETE CASCADE,
    kind            TEXT     NOT NULL DEFAULT 'gradient' CHECK (kind IN ('photo', 'gradient', 'solid')),
    image_media_id  UUID     REFERENCES media_objects (id) ON DELETE SET NULL,
    -- Non-destructive crop: zoom and focal point over the original image.
    scale           REAL     NOT NULL DEFAULT 1 CHECK (scale >= 1 AND scale <= 4),
    align_x         REAL     NOT NULL DEFAULT 0 CHECK (align_x BETWEEN -1 AND 1),
    align_y         REAL     NOT NULL DEFAULT 0 CHECK (align_y BETWEEN -1 AND 1),
    color_a         BIGINT   NOT NULL CHECK (color_a BETWEEN 0 AND 4294967295), -- ARGB
    color_b         BIGINT   CHECK (color_b BETWEEN 0 AND 4294967295),
    show_title      BOOLEAN  NOT NULL DEFAULT TRUE,
    title_placement TEXT     NOT NULL DEFAULT 'bottomLeft' CHECK (title_placement IN ('topLeft', 'center', 'bottomLeft', 'bottomCenter')),
    text_color      BIGINT   NOT NULL DEFAULT 4294967295 CHECK (text_color BETWEEN 0 AND 4294967295),
    style           TEXT     NOT NULL DEFAULT 'classic' CHECK (style IN ('classic', 'minimal', 'bold', 'framed')),
    version         BIGINT   NOT NULL DEFAULT 1,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
    -- A photo banner whose image was deleted keeps kind='photo' briefly; the app falls back to colors.
);

-- ---------------------------------------------------------------- gallery

CREATE TABLE trip_photos (
    id          UUID PRIMARY KEY,
    trip_id     UUID        NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    media_id    UUID        NOT NULL REFERENCES media_objects (id) ON DELETE RESTRICT,
    caption     TEXT,
    is_favorite BOOLEAN     NOT NULL DEFAULT FALSE,
    taken_at    TIMESTAMPTZ,
    created_by  UUID        REFERENCES users (id) ON DELETE SET NULL,
    version     BIGINT      NOT NULL DEFAULT 1,
    created_at  TIMESTAMPTZ NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL
);

CREATE INDEX trip_photos_trip_idx ON trip_photos (trip_id, created_at DESC);

-- ---------------------------------------------------------------- checklist ("Before you go")

CREATE TABLE checklist_items (
    id         UUID PRIMARY KEY,
    trip_id    UUID        NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    title      TEXT        NOT NULL CHECK (length(btrim(title)) > 0),
    notes      TEXT,
    category   TEXT        NOT NULL DEFAULT 'other' CHECK (category IN
        ('documents', 'bookings', 'packing', 'health', 'money', 'connectivity', 'home', 'other')),
    due_date   DATE,
    is_done    BOOLEAN     NOT NULL DEFAULT FALSE,
    done_at    TIMESTAMPTZ,
    position   INTEGER     NOT NULL DEFAULT 0,
    created_by UUID        REFERENCES users (id) ON DELETE SET NULL,
    version    BIGINT      NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CHECK (is_done = (done_at IS NOT NULL))
);

CREATE INDEX checklist_items_trip_idx ON checklist_items (trip_id, is_done, due_date NULLS LAST, position);

-- ---------------------------------------------------------------- itinerary

CREATE TABLE activities (
    id                 UUID PRIMARY KEY,
    trip_id            UUID        NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    title              TEXT        NOT NULL CHECK (length(btrim(title)) > 0),
    kind               TEXT        NOT NULL DEFAULT 'sightseeing' CHECK (kind IN
        ('sightseeing', 'food', 'activity', 'shopping', 'rest', 'flight', 'train', 'bus',
         'transfer', 'ferry', 'transport', 'hotel', 'other')),
    -- Local date/time in the trip time zone. Times are NULL while undecided
    -- (never guessed); both or neither must be set.
    date               DATE        NOT NULL,
    start_minute       SMALLINT    CHECK (start_minute BETWEEN 0 AND 1439),
    end_date           DATE,
    end_minute         SMALLINT    CHECK (end_minute BETWEEN 0 AND 1440),
    location_name      TEXT,
    location_lat       DOUBLE PRECISION CHECK (location_lat BETWEEN -90 AND 90),
    location_lng       DOUBLE PRECISION CHECK (location_lng BETWEEN -180 AND 180),
    destination_name   TEXT,
    destination_lat    DOUBLE PRECISION CHECK (destination_lat BETWEEN -90 AND 90),
    destination_lng    DOUBLE PRECISION CHECK (destination_lng BETWEEN -180 AND 180),
    coordinate_source  TEXT,           -- 'map' | 'search:<provider>' | 'import'
    cost               NUMERIC(14, 2) CHECK (cost >= 0),
    currency           CHAR(3)     CHECK (currency ~ '^[A-Z]{3}$'),
    booking_status     TEXT        NOT NULL DEFAULT 'notBooked' CHECK (booking_status IN ('notBooked', 'booked', 'confirmed', 'cancelled')),
    provider           TEXT,
    service_number     TEXT,
    -- Private: encrypted by the API (AES-256-GCM, key from KMS); never plaintext.
    booking_reference_ciphertext BYTEA,
    booking_url        TEXT,
    is_locked          BOOLEAN     NOT NULL DEFAULT FALSE,
    is_optional        BOOLEAN     NOT NULL DEFAULT FALSE,
    notes              TEXT,
    created_by         UUID        REFERENCES users (id) ON DELETE SET NULL,
    updated_by         UUID        REFERENCES users (id) ON DELETE SET NULL,
    version            BIGINT      NOT NULL DEFAULT 1,
    created_at         TIMESTAMPTZ NOT NULL,
    updated_at         TIMESTAMPTZ NOT NULL,
    CONSTRAINT activities_times_both_or_neither CHECK ((start_minute IS NULL) = (end_minute IS NULL)),
    CONSTRAINT activities_end_date_after_start CHECK (end_date IS NULL OR end_date >= date),
    CONSTRAINT activities_ends_after_start CHECK (
        start_minute IS NULL
        OR (COALESCE(end_date, date) - date) * 1440 + end_minute > start_minute),
    CONSTRAINT activities_location_coords_pair CHECK ((location_lat IS NULL) = (location_lng IS NULL)),
    CONSTRAINT activities_destination_coords_pair CHECK ((destination_lat IS NULL) = (destination_lng IS NULL)),
    UNIQUE (trip_id, id) -- lets expenses reference an activity of the same trip
);

CREATE INDEX activities_trip_date_idx ON activities (trip_id, date, start_minute NULLS FIRST);

-- ---------------------------------------------------------------- budget

CREATE TABLE expenses (
    id               UUID PRIMARY KEY,
    trip_id          UUID           NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    title            TEXT           NOT NULL CHECK (length(btrim(title)) > 0),
    category         TEXT           NOT NULL DEFAULT 'misc' CHECK (category IN
        ('flights', 'trains', 'buses', 'taxis', 'transport', 'hotels', 'food', 'attractions',
         'activities', 'internet', 'insurance', 'shopping', 'emergency', 'misc')),
    amount           NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
    currency         CHAR(3)        NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    kind             TEXT           NOT NULL DEFAULT 'actual' CHECK (kind IN ('planned', 'actual')),
    is_paid          BOOLEAN        NOT NULL DEFAULT TRUE,
    expense_date     DATE,
    activity_id      UUID,
    is_shared        BOOLEAN        NOT NULL DEFAULT TRUE, -- split across all travelers
    paid_by          UUID           REFERENCES users (id) ON DELETE SET NULL,
    receipt_media_id UUID           REFERENCES media_objects (id) ON DELETE SET NULL,
    notes            TEXT,
    created_by       UUID           REFERENCES users (id) ON DELETE SET NULL,
    version          BIGINT         NOT NULL DEFAULT 1,
    created_at       TIMESTAMPTZ    NOT NULL,
    updated_at       TIMESTAMPTZ    NOT NULL,
    -- The linked activity must belong to the same trip; deleting it keeps the expense.
    FOREIGN KEY (trip_id, activity_id) REFERENCES activities (trip_id, id) ON DELETE SET NULL (activity_id)
);

CREATE INDEX expenses_trip_idx ON expenses (trip_id, kind, expense_date);

-- 1 unit of `currency` = `rate` units of the trip's currency.
CREATE TABLE exchange_rates (
    trip_id    UUID           NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    currency   CHAR(3)        NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    rate       NUMERIC(20, 10) NOT NULL CHECK (rate > 0),
    source     TEXT           NOT NULL DEFAULT 'manual', -- 'manual' = user-entered, not verified
    updated_at TIMESTAMPTZ    NOT NULL DEFAULT now(),
    PRIMARY KEY (trip_id, currency)
);

-- ---------------------------------------------------------------- collaboration

-- Invite links. Only a SHA-256 hash of the token is stored.
CREATE TABLE trip_invites (
    id          UUID PRIMARY KEY,
    trip_id     UUID        NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    token_hash  BYTEA       NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
    role        TEXT        NOT NULL CHECK (role IN ('editor', 'viewer')),
    created_by  UUID        NOT NULL REFERENCES users (id),
    expires_at  TIMESTAMPTZ NOT NULL,
    max_uses    INTEGER     CHECK (max_uses > 0),
    use_count   INTEGER     NOT NULL DEFAULT 0 CHECK (use_count >= 0),
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (max_uses IS NULL OR use_count <= max_uses)
);

CREATE INDEX trip_invites_trip_idx ON trip_invites (trip_id);

-- Devices for push notifications (departure, check-in, booking reminders).
CREATE TABLE user_devices (
    id           UUID PRIMARY KEY,
    user_id      UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    platform     TEXT        NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    push_token   TEXT        NOT NULL UNIQUE,
    locale       TEXT,
    app_version  TEXT,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX user_devices_user_idx ON user_devices (user_id);

-- ---------------------------------------------------------------- sync

-- Append-only change feed. Clients pull `seq > cursor` for the trips they
-- belong to. No FK to trips: tombstones must outlive deleted trips.
CREATE TABLE sync_changes (
    seq         BIGSERIAL PRIMARY KEY,
    trip_id     UUID        NOT NULL,
    entity_type TEXT        NOT NULL,
    entity_key  TEXT        NOT NULL,
    op          TEXT        NOT NULL CHECK (op IN ('upsert', 'delete')),
    version     BIGINT,
    changed_by  UUID,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX sync_changes_trip_seq_idx ON sync_changes (trip_id, seq);

-- The API runs `SET LOCAL app.user_id = '<uuid>'` in each transaction so
-- changes are attributed without passing the user through every query.
-- +goose StatementBegin
CREATE FUNCTION record_sync_change() RETURNS trigger
    LANGUAGE plpgsql AS
$$
DECLARE
    r       jsonb;
    actor   text := nullif(current_setting('app.user_id', true), '');
BEGIN
    IF TG_OP = 'DELETE' THEN
        r := to_jsonb(OLD);
    ELSE
        r := to_jsonb(NEW);
    END IF;
    INSERT INTO sync_changes (trip_id, entity_type, entity_key, op, version, changed_by)
    VALUES (
        CASE WHEN TG_TABLE_NAME = 'trips' THEN (r ->> 'id')::uuid ELSE (r ->> 'trip_id')::uuid END,
        TG_TABLE_NAME,
        COALESCE(r ->> 'id', r ->> 'currency', r ->> 'user_id', r ->> 'trip_id'),
        CASE WHEN TG_OP = 'DELETE' THEN 'delete' ELSE 'upsert' END,
        (r ->> 'version')::bigint,
        actor::uuid
    );
    RETURN NULL;
END
$$;
-- +goose StatementEnd

CREATE TRIGGER trips_sync AFTER INSERT OR UPDATE OR DELETE ON trips FOR EACH ROW EXECUTE FUNCTION record_sync_change();
CREATE TRIGGER trip_members_sync AFTER INSERT OR UPDATE OR DELETE ON trip_members FOR EACH ROW EXECUTE FUNCTION record_sync_change();
CREATE TRIGGER trip_destinations_sync AFTER INSERT OR UPDATE OR DELETE ON trip_destinations FOR EACH ROW EXECUTE FUNCTION record_sync_change();
CREATE TRIGGER trip_banners_sync AFTER INSERT OR UPDATE OR DELETE ON trip_banners FOR EACH ROW EXECUTE FUNCTION record_sync_change();
CREATE TRIGGER trip_photos_sync AFTER INSERT OR UPDATE OR DELETE ON trip_photos FOR EACH ROW EXECUTE FUNCTION record_sync_change();
CREATE TRIGGER checklist_items_sync AFTER INSERT OR UPDATE OR DELETE ON checklist_items FOR EACH ROW EXECUTE FUNCTION record_sync_change();
CREATE TRIGGER activities_sync AFTER INSERT OR UPDATE OR DELETE ON activities FOR EACH ROW EXECUTE FUNCTION record_sync_change();
CREATE TRIGGER expenses_sync AFTER INSERT OR UPDATE OR DELETE ON expenses FOR EACH ROW EXECUTE FUNCTION record_sync_change();
CREATE TRIGGER exchange_rates_sync AFTER INSERT OR UPDATE OR DELETE ON exchange_rates FOR EACH ROW EXECUTE FUNCTION record_sync_change();

-- Safe retries for POST/PUT from flaky mobile networks (Idempotency-Key header).
CREATE TABLE idempotency_keys (
    user_id         UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    key             TEXT        NOT NULL CHECK (char_length(key) BETWEEN 8 AND 128),
    request_hash    BYTEA       NOT NULL,
    response_status INTEGER     NOT NULL,
    response_body   JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, key)
);

CREATE INDEX idempotency_keys_created_idx ON idempotency_keys (created_at); -- purge job

-- ---------------------------------------------------------------- integration & compliance

-- Transactional outbox: events written in the same transaction as the change,
-- published later by a worker (push notifications, emails, webhooks).
CREATE TABLE outbox_events (
    id             BIGSERIAL PRIMARY KEY,
    topic          TEXT        NOT NULL,
    aggregate_type TEXT        NOT NULL,
    aggregate_id   UUID        NOT NULL,
    payload        JSONB       NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at   TIMESTAMPTZ,
    attempts       INTEGER     NOT NULL DEFAULT 0,
    last_error     TEXT
);

CREATE INDEX outbox_events_unpublished_idx ON outbox_events (id) WHERE published_at IS NULL;

-- Who did what, for security reviews and support.
CREATE TABLE audit_log (
    id          BIGSERIAL PRIMARY KEY,
    actor_id    UUID REFERENCES users (id) ON DELETE SET NULL,
    action      TEXT        NOT NULL,       -- e.g. 'trip.delete', 'member.invite'
    entity_type TEXT        NOT NULL,
    entity_id   TEXT        NOT NULL,
    trip_id     UUID,
    ip          INET,
    user_agent  TEXT,
    details     JSONB,
    at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_trip_idx ON audit_log (trip_id, at DESC);
CREATE INDEX audit_log_actor_idx ON audit_log (actor_id, at DESC);

-- ---------------------------------------------------------------- reporting

-- Per-trip budget in the trip's currency, same rules as the app:
-- planned = activity costs + planned expenses; spent = actual expenses.
-- Amounts in a currency without a rate are excluded and counted separately.
CREATE VIEW trip_budget_summary AS
WITH lines AS (
    SELECT a.trip_id, 'planned' AS bucket, a.cost AS amount, COALESCE(a.currency, t.currency) AS currency
    FROM activities a JOIN trips t ON t.id = a.trip_id
    WHERE a.cost IS NOT NULL AND a.booking_status <> 'cancelled'
    UNION ALL
    SELECT e.trip_id, CASE e.kind WHEN 'planned' THEN 'planned' ELSE 'spent' END, e.amount, e.currency
    FROM expenses e
),
converted AS (
    SELECT l.trip_id, l.bucket,
           l.amount * CASE WHEN l.currency = t.currency THEN 1 ELSE r.rate END AS amount_in_trip_currency
    FROM lines l
    JOIN trips t ON t.id = l.trip_id
    LEFT JOIN exchange_rates r ON r.trip_id = l.trip_id AND r.currency = l.currency
)
SELECT t.id                                                                    AS trip_id,
       t.currency,
       t.total_budget,
       COALESCE(SUM(c.amount_in_trip_currency) FILTER (WHERE c.bucket = 'planned'), 0)   AS planned,
       COALESCE(SUM(c.amount_in_trip_currency) FILTER (WHERE c.bucket = 'spent'), 0)     AS spent,
       COUNT(*) FILTER (WHERE c.trip_id IS NOT NULL AND c.amount_in_trip_currency IS NULL) AS unconverted_lines
FROM trips t
LEFT JOIN converted c ON c.trip_id = t.id
GROUP BY t.id, t.currency, t.total_budget;

-- +goose Down
DROP VIEW trip_budget_summary;
DROP TABLE audit_log;
DROP TABLE outbox_events;
DROP TABLE idempotency_keys;
DROP TRIGGER exchange_rates_sync ON exchange_rates;
DROP TRIGGER expenses_sync ON expenses;
DROP TRIGGER activities_sync ON activities;
DROP TRIGGER checklist_items_sync ON checklist_items;
DROP TRIGGER trip_photos_sync ON trip_photos;
DROP TRIGGER trip_banners_sync ON trip_banners;
DROP TRIGGER trip_destinations_sync ON trip_destinations;
DROP TRIGGER trip_members_sync ON trip_members;
DROP TRIGGER trips_sync ON trips;
DROP FUNCTION record_sync_change();
DROP TABLE sync_changes;
DROP TABLE user_devices;
DROP TABLE trip_invites;
DROP TABLE exchange_rates;
DROP TABLE expenses;
DROP TABLE activities;
DROP TABLE checklist_items;
DROP TABLE trip_photos;
DROP TABLE trip_banners;
DROP TABLE trip_destinations;
DROP TABLE media_objects;
DROP INDEX trips_owner_idx;
ALTER TABLE trips
    DROP CONSTRAINT trips_departure_needs_start,
    DROP CONSTRAINT trips_title_length,
    DROP CONSTRAINT trips_travel_style_valid,
    DROP CONSTRAINT trips_stage_valid,
    DROP CONSTRAINT trips_budget_needs_currency,
    DROP CONSTRAINT trips_currency_format;
