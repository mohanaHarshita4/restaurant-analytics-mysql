-- schema.RangubhotlaM.VinaitheerthaJ.sql
-- Mohana Rangubhotla, Jayshree Vinaitheertha
-- CS5200, Fall 2026
-- Table definitions for our 3NF design from Part B.
-- createDB reads this file and runs each statement (split on the semicolon).
-- constraint against the data and tested it on our Aiven database.

-- one row per restaurant (comes from the sqlite restaurants table)
CREATE TABLE IF NOT EXISTS restaurants (
  rid                INT          NOT NULL,
  restaurant_name    VARCHAR(100) NOT NULL,
  city               VARCHAR(60)  NOT NULL,
  state              CHAR(2)      NOT NULL,
  has_table_service  BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (rid),
  CHECK (CHAR_LENGTH(state) = 2)
);

-- lookup for MealType (Breakfast, Lunch, Dinner, Take-Out)
CREATE TABLE IF NOT EXISTS meal_types (
  mtid       INT         NOT NULL,
  meal_type  VARCHAR(20) NOT NULL,
  PRIMARY KEY (mtid),
  UNIQUE (meal_type)
);

-- lookup for PaymentMethod (Cash, Credit Card, Mobile Payment)
CREATE TABLE IF NOT EXISTS payment_methods (
  pmid            INT         NOT NULL,
  payment_method  VARCHAR(20) NOT NULL,
  PRIMARY KEY (pmid),
  UNIQUE (payment_method)
);

-- loyalty customers, only these have name/phone/email in the csv
CREATE TABLE IF NOT EXISTS customers (
  cid             INT          NOT NULL AUTO_INCREMENT,
  customer_name   VARCHAR(100) NOT NULL,
  customer_phone  VARCHAR(20)  NOT NULL,
  customer_email  VARCHAR(100) NOT NULL,
  loyalty_member  BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (cid),
  UNIQUE (customer_email),
  UNIQUE (customer_phone)
);

-- servers, each works at one restaurant
-- end date, birth date and ssn can be missing so they allow NULL
CREATE TABLE IF NOT EXISTS servers (
  emp_id            INT          NOT NULL,
  server_name       VARCHAR(100) NOT NULL,
  start_date_hired  DATE         NOT NULL,
  end_date_hired    DATE         NULL DEFAULT NULL,
  hourly_rate       DECIMAL(6,2) NOT NULL DEFAULT 0.00,
  birth_date        DATE         NULL DEFAULT NULL,
  ssn               CHAR(11)     NULL DEFAULT NULL,
  rid               INT          NOT NULL,
  PRIMARY KEY (emp_id),
  UNIQUE (ssn),
  FOREIGN KEY (rid) REFERENCES restaurants(rid),
  CHECK (hourly_rate >= 0),
  CHECK (end_date_hired IS NULL OR end_date_hired >= start_date_hired)
);

-- one row per visit (each csv row), includes the bill amounts
-- emp_id and cid are NULL when there was no server or no loyalty customer
CREATE TABLE IF NOT EXISTS visits (
  vid                INT          NOT NULL AUTO_INCREMENT,
  rid                INT          NOT NULL,
  emp_id             INT          NULL DEFAULT NULL,
  cid                INT          NULL DEFAULT NULL,
  visit_date         DATE         NOT NULL,
  visit_time         TIME         NULL DEFAULT NULL,
  mtid               INT          NOT NULL,
  party_size         INT          NULL DEFAULT NULL,
  wait_time          INT          NULL DEFAULT NULL,
  food_bill          DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  tip_amount         DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  food_discount_pct  DECIMAL(4,2) NOT NULL DEFAULT 0.00,
  pmid               INT          NOT NULL,
  alcohol_bill       DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (vid),
  FOREIGN KEY (rid)    REFERENCES restaurants(rid),
  FOREIGN KEY (emp_id) REFERENCES servers(emp_id),
  FOREIGN KEY (cid)    REFERENCES customers(cid),
  FOREIGN KEY (mtid)   REFERENCES meal_types(mtid),
  FOREIGN KEY (pmid)   REFERENCES payment_methods(pmid),
  INDEX idx_visit_date (visit_date),
  CHECK (party_size IS NULL OR party_size BETWEEN 1 AND 50),
  CHECK (wait_time IS NULL OR wait_time >= 0),
  CHECK (food_bill >= 0),
  CHECK (tip_amount >= 0),
  CHECK (food_discount_pct BETWEEN 0 AND 1),
  CHECK (alcohol_bill >= 0)
);
