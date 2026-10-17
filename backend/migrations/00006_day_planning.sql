-- +goose Up
-- Day planning (mobile schema v6): how the traveller reaches each stop,
-- opening hours, reservations to make, and per-day start/end points.
ALTER TABLE activities
    ADD COLUMN arrival_mode         TEXT     CHECK (arrival_mode IN ('walking', 'cycling', 'driving', 'transit')),
    -- The traveller's own estimate; transit is never calculated.
    ADD COLUMN arrival_minutes      SMALLINT CHECK (arrival_minutes BETWEEN 0 AND 2880),
    ADD COLUMN opens_at             SMALLINT CHECK (opens_at BETWEEN 0 AND 1439),
    ADD COLUMN closes_at            SMALLINT CHECK (closes_at BETWEEN 0 AND 1440),
    -- ISO weekdays, 1 = Monday … 7 = Sunday.
    ADD COLUMN closed_weekdays      SMALLINT[] NOT NULL DEFAULT '{}'
        CHECK (closed_weekdays <@ '{1,2,3,4,5,6,7}'::SMALLINT[] AND cardinality(closed_weekdays) < 7),
    ADD COLUMN reservation_required BOOLEAN  NOT NULL DEFAULT FALSE,
    ADD COLUMN reservation_via      TEXT,
    ADD COLUMN book_ahead_days      SMALLINT CHECK (book_ahead_days BETWEEN 0 AND 365),
    ADD COLUMN remind_to_book       BOOLEAN  NOT NULL DEFAULT FALSE,
    ADD CONSTRAINT activities_hours_both_or_neither CHECK ((opens_at IS NULL) = (closes_at IS NULL)),
    ADD CONSTRAINT activities_reminder_needs_lead_time CHECK (NOT remind_to_book OR (reservation_required AND book_ahead_days IS NOT NULL));

CREATE TABLE day_plans (
    trip_id             UUID             NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    date                DATE             NOT NULL,
    start_name          TEXT,
    start_lat           DOUBLE PRECISION CHECK (start_lat BETWEEN -90 AND 90),
    start_lng           DOUBLE PRECISION CHECK (start_lng BETWEEN -180 AND 180),
    start_source        TEXT,
    end_name            TEXT,
    end_lat             DOUBLE PRECISION CHECK (end_lat BETWEEN -90 AND 90),
    end_lng             DOUBLE PRECISION CHECK (end_lng BETWEEN -180 AND 180),
    end_source          TEXT,
    end_arrival_mode    TEXT     CHECK (end_arrival_mode IN ('walking', 'cycling', 'driving', 'transit')),
    end_arrival_minutes SMALLINT CHECK (end_arrival_minutes BETWEEN 0 AND 2880),
    version             BIGINT   NOT NULL DEFAULT 1,
    PRIMARY KEY (trip_id, date),
    CONSTRAINT day_plans_start_coords_pair CHECK ((start_lat IS NULL) = (start_lng IS NULL)),
    CONSTRAINT day_plans_end_coords_pair CHECK ((end_lat IS NULL) = (end_lng IS NULL))
);

-- Synced like the other trip tables (entity key = the date).
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION record_sync_change() RETURNS trigger
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
        COALESCE(r ->> 'id', r ->> 'currency', r ->> 'date', r ->> 'user_id', r ->> 'trip_id'),
        CASE WHEN TG_OP = 'DELETE' THEN 'delete' ELSE 'upsert' END,
        (r ->> 'version')::bigint,
        actor::uuid
    );
    RETURN NULL;
END
$$;
-- +goose StatementEnd

CREATE TRIGGER day_plans_sync AFTER INSERT OR UPDATE OR DELETE ON day_plans
    FOR EACH ROW EXECUTE FUNCTION record_sync_change();

-- Reminders the notification worker must send (book-by date has come).
CREATE INDEX activities_booking_due_idx ON activities (date, book_ahead_days)
    WHERE reservation_required AND remind_to_book AND booking_status = 'notBooked';

-- +goose Down
DROP INDEX activities_booking_due_idx;
DROP TRIGGER day_plans_sync ON day_plans;
DROP TABLE day_plans;
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION record_sync_change() RETURNS trigger
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
ALTER TABLE activities
    DROP CONSTRAINT activities_reminder_needs_lead_time,
    DROP CONSTRAINT activities_hours_both_or_neither,
    DROP COLUMN remind_to_book,
    DROP COLUMN book_ahead_days,
    DROP COLUMN reservation_via,
    DROP COLUMN reservation_required,
    DROP COLUMN closed_weekdays,
    DROP COLUMN closes_at,
    DROP COLUMN opens_at,
    DROP COLUMN arrival_minutes,
    DROP COLUMN arrival_mode;
