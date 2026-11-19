-- migrate:up
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE users (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text NOT NULL,
  phone_number text NOT NULL,
  date_of_birth date NOT NULL,
  role text NOT NULL CHECK (role IN ('user', 'owner', 'admin')),
  password_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX users_email_unique ON users (lower(email));

CREATE TABLE sports_fields (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  owner_id integer NOT NULL REFERENCES users (id),
  name text NOT NULL,
  description text NOT NULL,
  sport text NOT NULL CHECK (sport IN ('football', 'basketball', 'tennis', 'padel', 'volleyball', 'swimming', 'futsal', 'other')),
  address text NOT NULL,
  city text NOT NULL,
  price_per_hour integer NOT NULL CHECK (price_per_hour >= 0),
  contact_phone text NOT NULL,
  confirmation_mode text NOT NULL CHECK (confirmation_mode IN ('automatic', 'manual')),
  is_active boolean NOT NULL DEFAULT true,
  approval_status text NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  rejection_reason text,
  reviewed_by integer REFERENCES users (id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX sports_fields_catalog ON sports_fields (approval_status, is_active, city, sport);
CREATE INDEX sports_fields_by_owner ON sports_fields (owner_id);

CREATE TABLE field_images (
  field_id integer NOT NULL REFERENCES sports_fields (id) ON DELETE CASCADE,
  position integer NOT NULL CHECK (position >= 0),
  url text NOT NULL,
  PRIMARY KEY (field_id, position)
);

CREATE TABLE field_schedules (
  field_id integer NOT NULL REFERENCES sports_fields (id) ON DELETE CASCADE,
  day_of_week text NOT NULL CHECK (day_of_week IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')),
  opens_at time NOT NULL,
  closes_at time NOT NULL,
  is_open boolean NOT NULL DEFAULT true,
  PRIMARY KEY (field_id, day_of_week),
  CHECK (NOT is_open OR opens_at < closes_at)
);

CREATE TABLE blocked_periods (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  field_id integer NOT NULL REFERENCES sports_fields (id) ON DELETE CASCADE,
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (start_time < end_time)
);

CREATE INDEX blocked_periods_by_field ON blocked_periods (field_id, start_time);

CREATE TABLE reservations (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  field_id integer NOT NULL REFERENCES sports_fields (id),
  user_id integer NOT NULL REFERENCES users (id),
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  total_price integer NOT NULL CHECK (total_price >= 0),
  status text NOT NULL CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  payment_status text NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid')),
  checked_in_at timestamptz,
  cancellation_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (start_time < end_time),
  CONSTRAINT reservations_no_double_booking EXCLUDE USING gist (
    field_id WITH =,
    tstzrange(start_time, end_time) WITH &&
  ) WHERE (status IN ('pending', 'confirmed')),
  CONSTRAINT reservations_one_field_per_user EXCLUDE USING gist (
    user_id WITH =,
    tstzrange(start_time, end_time) WITH &&
  ) WHERE (status IN ('pending', 'confirmed'))
);

CREATE INDEX reservations_by_user ON reservations (user_id, start_time);
CREATE INDEX reservations_by_start ON reservations (start_time);

CREATE TABLE reviews (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reservation_id integer NOT NULL REFERENCES reservations (id),
  reviewer_id integer NOT NULL REFERENCES users (id),
  type text NOT NULL CHECK (type IN ('field', 'user')),
  reviewed_field_id integer REFERENCES sports_fields (id),
  reviewed_user_id integer REFERENCES users (id),
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reservation_id, reviewer_id, type),
  CHECK (
    (type = 'field' AND reviewed_field_id IS NOT NULL AND reviewed_user_id IS NULL)
    OR (type = 'user' AND reviewed_user_id IS NOT NULL AND reviewed_field_id IS NULL)
  )
);

-- migrate:down
DROP TABLE reviews;
DROP TABLE reservations;
DROP TABLE blocked_periods;
DROP TABLE field_schedules;
DROP TABLE field_images;
DROP TABLE sports_fields;
DROP TABLE users;
