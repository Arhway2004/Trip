-- +goose Up
CREATE TABLE trip_plans (
  trip_id uuid PRIMARY KEY REFERENCES trips(id) ON DELETE CASCADE,
  version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
  package jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE trip_plans;
