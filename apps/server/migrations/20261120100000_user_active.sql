-- migrate:up
ALTER TABLE users ADD COLUMN is_active boolean NOT NULL DEFAULT true;

-- migrate:down
ALTER TABLE users DROP COLUMN is_active;
