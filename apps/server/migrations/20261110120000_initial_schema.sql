CREATE TABLE users (
  id            INT          NOT NULL AUTO_INCREMENT,
  first_name    VARCHAR(80)  NOT NULL,
  last_name     VARCHAR(80)  NOT NULL,
  email         VARCHAR(190) NOT NULL,
  phone_number  VARCHAR(32)  NOT NULL,
  date_of_birth DATE         NOT NULL,
  role          VARCHAR(16)  NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at    DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT users_email_unique UNIQUE (email),
  CONSTRAINT users_role_valid CHECK (role IN ('user', 'owner', 'admin'))
);

CREATE TABLE sports_fields (
  id                INT          NOT NULL AUTO_INCREMENT,
  owner_id          INT          NOT NULL,
  name              VARCHAR(120) NOT NULL,
  description       TEXT         NOT NULL,
  sport             VARCHAR(32)  NOT NULL,
  address           VARCHAR(200) NOT NULL,
  city              VARCHAR(80)  NOT NULL,
  price_per_hour    INT          NOT NULL,
  contact_phone     VARCHAR(32)  NOT NULL,
  confirmation_mode VARCHAR(16)  NOT NULL,
  is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
  approval_status   VARCHAR(16)  NOT NULL DEFAULT 'pending',
  created_at        DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT sports_fields_owner_fk FOREIGN KEY (owner_id) REFERENCES users (id),
  CONSTRAINT sports_fields_sport_valid CHECK (sport IN (
    'football', 'basketball', 'tennis', 'padel', 'volleyball', 'swimming', 'futsal', 'other'
  )),
  CONSTRAINT sports_fields_price_valid CHECK (price_per_hour >= 0),
  CONSTRAINT sports_fields_confirmation_valid CHECK (confirmation_mode IN ('automatic', 'manual')),
  CONSTRAINT sports_fields_approval_valid CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  INDEX sports_fields_catalog_idx (approval_status, is_active, city, sport),
  INDEX sports_fields_owner_idx (owner_id)
);

CREATE TABLE field_images (
  field_id INT           NOT NULL,
  position INT           NOT NULL,
  url      VARCHAR(500)  NOT NULL,
  PRIMARY KEY (field_id, position),
  CONSTRAINT field_images_field_fk FOREIGN KEY (field_id) REFERENCES sports_fields (id) ON DELETE CASCADE,
  CONSTRAINT field_images_position_valid CHECK (position >= 0)
);

CREATE TABLE field_schedules (
  field_id    INT         NOT NULL,
  day_of_week VARCHAR(16) NOT NULL,
  opens_at    TIME        NOT NULL,
  closes_at   TIME        NOT NULL,
  is_open     BOOLEAN     NOT NULL DEFAULT TRUE,
  PRIMARY KEY (field_id, day_of_week),
  CONSTRAINT field_schedules_field_fk FOREIGN KEY (field_id) REFERENCES sports_fields (id) ON DELETE CASCADE,
  CONSTRAINT field_schedules_day_valid CHECK (day_of_week IN (
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  )),
  CONSTRAINT field_schedules_hours_valid CHECK (is_open = FALSE OR opens_at < closes_at)
);

CREATE TABLE blocked_periods (
  id         INT          NOT NULL AUTO_INCREMENT,
  field_id   INT          NOT NULL,
  start_time DATETIME(3)  NOT NULL,
  end_time   DATETIME(3)  NOT NULL,
  reason     VARCHAR(200) NULL,
  created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT blocked_periods_field_fk FOREIGN KEY (field_id) REFERENCES sports_fields (id) ON DELETE CASCADE,
  CONSTRAINT blocked_periods_range_valid CHECK (start_time < end_time),
  INDEX blocked_periods_field_time_idx (field_id, start_time, end_time)
);

CREATE TABLE reservations (
  id                  INT          NOT NULL AUTO_INCREMENT,
  field_id            INT          NOT NULL,
  user_id             INT          NOT NULL,
  start_time          DATETIME(3)  NOT NULL,
  end_time            DATETIME(3)  NOT NULL,
  total_price         INT          NOT NULL,
  status              VARCHAR(16)  NOT NULL,
  payment_status      VARCHAR(16)  NOT NULL DEFAULT 'unpaid',
  checked_in_at       DATETIME(3)  NULL,
  cancellation_reason VARCHAR(500) NULL,
  created_at          DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at          DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT reservations_field_fk FOREIGN KEY (field_id) REFERENCES sports_fields (id),
  CONSTRAINT reservations_user_fk FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT reservations_range_valid CHECK (start_time < end_time),
  CONSTRAINT reservations_price_valid CHECK (total_price >= 0),
  CONSTRAINT reservations_status_valid CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  CONSTRAINT reservations_payment_valid CHECK (payment_status IN ('unpaid', 'paid')),
  INDEX reservations_field_time_idx (field_id, start_time, end_time),
  INDEX reservations_user_time_idx (user_id, start_time)
);

CREATE TABLE reviews (
  id                INT         NOT NULL AUTO_INCREMENT,
  reservation_id    INT         NOT NULL,
  reviewer_id       INT         NOT NULL,
  type              VARCHAR(8)  NOT NULL,
  reviewed_field_id INT         NULL,
  reviewed_user_id  INT         NULL,
  rating            TINYINT     NOT NULL,
  comment           TEXT        NULL,
  created_at        DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT reviews_reservation_fk FOREIGN KEY (reservation_id) REFERENCES reservations (id),
  CONSTRAINT reviews_reviewer_fk FOREIGN KEY (reviewer_id) REFERENCES users (id),
  CONSTRAINT reviews_field_fk FOREIGN KEY (reviewed_field_id) REFERENCES sports_fields (id),
  CONSTRAINT reviews_user_fk FOREIGN KEY (reviewed_user_id) REFERENCES users (id),
  CONSTRAINT reviews_type_valid CHECK (type IN ('field', 'user')),
  CONSTRAINT reviews_rating_valid CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT reviews_target_valid CHECK (
    (type = 'field' AND reviewed_field_id IS NOT NULL AND reviewed_user_id IS NULL) OR
    (type = 'user' AND reviewed_user_id IS NOT NULL AND reviewed_field_id IS NULL)
  ),
  CONSTRAINT reviews_one_per_reservation UNIQUE (reservation_id, reviewer_id, type)
);
