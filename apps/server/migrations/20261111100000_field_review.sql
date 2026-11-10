ALTER TABLE sports_fields
  ADD COLUMN rejection_reason VARCHAR(500) NULL,
  ADD COLUMN reviewed_by INT NULL,
  ADD COLUMN reviewed_at DATETIME(3) NULL,
  ADD CONSTRAINT sports_fields_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id);

CREATE INDEX sports_fields_review_idx ON sports_fields (approval_status, created_at);
