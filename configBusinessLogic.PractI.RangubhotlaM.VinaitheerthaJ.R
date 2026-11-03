# configBusinessLogic.PractI.RangubhotlaM.VinaitheerthaJ.R
# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026
#
# Part G: creates the stored procedures storeNewVisit and modifyServer in
# the Aiven MySQL database. Tests are in testBusinessLogic.R.
# No DELIMITER is needed: each CREATE PROCEDURE is sent as one statement.
#
# AI use: Claude (Anthropic) helped us write parts of this script. We went
# through every line, ran it, and can explain it.

rm(list = ls())

packages <- c("DBI", "RMySQL")
missing  <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")
invisible(lapply(packages, library, character.only = TRUE))

source("dbConfig.R")


# ---------- storeNewVisit ----------
# Adds one visit. Restaurant and server are assumed to exist (brief), and the
# lookup tables are assumed to exist (instructor on Teams). Meal type and
# payment method come in as text and are looked up; an unknown value is
# rejected. Missing amounts default to 0. vid is AUTO_INCREMENT.

sql_store_new_visit <- "
CREATE PROCEDURE storeNewVisit(
  IN p_rid          INT,
  IN p_emp_id       INT,
  IN p_cid          INT,
  IN p_visit_date   DATE,
  IN p_visit_time   TIME,
  IN p_meal_type    VARCHAR(20),
  IN p_party_size   INT,
  IN p_wait_time    INT,
  IN p_food_bill    DECIMAL(8,2),
  IN p_tip          DECIMAL(8,2),
  IN p_discount     DECIMAL(4,2),
  IN p_payment      VARCHAR(20),
  IN p_alcohol_bill DECIMAL(8,2))
BEGIN
  DECLARE v_mtid INT DEFAULT NULL;
  DECLARE v_pmid INT DEFAULT NULL;

  -- SET with a subquery gives NULL when nothing matches (no warning)
  SET v_mtid = (SELECT mtid FROM meal_types WHERE meal_type = p_meal_type);
  SET v_pmid = (SELECT pmid FROM payment_methods WHERE payment_method = p_payment);

  IF v_mtid IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'storeNewVisit: unknown meal type';
  END IF;
  IF v_pmid IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'storeNewVisit: unknown payment method';
  END IF;
  IF p_visit_date IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'storeNewVisit: visit date is required';
  END IF;
  IF COALESCE(p_food_bill, 0) < 0 OR COALESCE(p_tip, 0) < 0
     OR COALESCE(p_alcohol_bill, 0) < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'storeNewVisit: amounts cannot be negative';
  END IF;
  IF COALESCE(p_discount, 0) < 0 OR COALESCE(p_discount, 0) > 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'storeNewVisit: discount must be between 0 and 1';
  END IF;
  IF p_party_size IS NOT NULL AND (p_party_size < 1 OR p_party_size > 50) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'storeNewVisit: party size must be 1 to 50';
  END IF;
  IF p_wait_time IS NOT NULL AND p_wait_time < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'storeNewVisit: wait time cannot be negative';
  END IF;
  IF p_cid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM customers WHERE cid = p_cid) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'storeNewVisit: customer does not exist';
  END IF;

  INSERT INTO visits (rid, emp_id, cid, visit_date, visit_time, mtid,
                      party_size, wait_time, food_bill, tip_amount,
                      food_discount_pct, pmid, alcohol_bill)
  VALUES (p_rid, p_emp_id, p_cid, p_visit_date, p_visit_time, v_mtid,
          p_party_size, p_wait_time, COALESCE(p_food_bill, 0), COALESCE(p_tip, 0),
          COALESCE(p_discount, 0), v_pmid, COALESCE(p_alcohol_bill, 0));
END"


# ---------- modifyServer ----------
# Updates a server. A NULL argument means keep the current value.
# Integrity checks:
#   - the server must exist
#   - name cannot be set to empty
#   - hourly rate cannot be negative
#   - a new restaurant must exist
#   - a new SSN cannot belong to another server
#   - end date cannot be before start date (using the values after the update)
#   - birth date must be before the hire date
#   - a new end date cannot be before visits the server already has

sql_modify_server <- "
CREATE PROCEDURE modifyServer(
  IN p_emp_id      INT,
  IN p_server_name VARCHAR(100),
  IN p_start_date  DATE,
  IN p_end_date    DATE,
  IN p_hourly_rate DECIMAL(6,2),
  IN p_birth_date  DATE,
  IN p_ssn         CHAR(11),
  IN p_rid         INT)
BEGIN
  DECLARE v_start DATE;
  DECLARE v_end   DATE;
  DECLARE v_birth DATE;

  IF NOT EXISTS (SELECT 1 FROM servers WHERE emp_id = p_emp_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'modifyServer: server does not exist';
  END IF;
  IF p_server_name IS NOT NULL AND TRIM(p_server_name) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'modifyServer: name cannot be empty';
  END IF;
  IF p_hourly_rate IS NOT NULL AND p_hourly_rate < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'modifyServer: hourly rate cannot be negative';
  END IF;
  IF p_rid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM restaurants WHERE rid = p_rid) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'modifyServer: restaurant does not exist';
  END IF;
  IF p_ssn IS NOT NULL AND EXISTS (SELECT 1 FROM servers
                                   WHERE ssn = p_ssn AND emp_id <> p_emp_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'modifyServer: SSN belongs to another server';
  END IF;

  -- values the row will have after the update
  SET v_start = COALESCE(p_start_date,
                         (SELECT start_date_hired FROM servers WHERE emp_id = p_emp_id));
  SET v_end   = COALESCE(p_end_date,
                         (SELECT end_date_hired FROM servers WHERE emp_id = p_emp_id));
  SET v_birth = COALESCE(p_birth_date,
                         (SELECT birth_date FROM servers WHERE emp_id = p_emp_id));

  IF v_end IS NOT NULL AND v_end < v_start THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'modifyServer: end date is before start date';
  END IF;
  IF v_birth IS NOT NULL AND v_birth >= v_start THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'modifyServer: birth date must be before hire date';
  END IF;
  IF p_end_date IS NOT NULL AND EXISTS (SELECT 1 FROM visits
                                        WHERE emp_id = p_emp_id
                                          AND visit_date > p_end_date) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'modifyServer: server has visits after that end date';
  END IF;

  UPDATE servers
     SET server_name      = COALESCE(TRIM(p_server_name), server_name),
         start_date_hired = v_start,
         end_date_hired   = v_end,
         hourly_rate      = COALESCE(p_hourly_rate, hourly_rate),
         birth_date       = v_birth,
         ssn              = COALESCE(p_ssn, ssn),
         rid              = COALESCE(p_rid, rid)
   WHERE emp_id = p_emp_id;
END"


# ---------- create both ----------

mydb <- connectMySQL()

dbExecute(mydb, "DROP PROCEDURE IF EXISTS storeNewVisit")
dbExecute(mydb, sql_store_new_visit)
cat("created procedure: storeNewVisit\n")

dbExecute(mydb, "DROP PROCEDURE IF EXISTS modifyServer")
dbExecute(mydb, sql_modify_server)
cat("created procedure: modifyServer\n")

print(dbGetQuery(mydb, "SELECT ROUTINE_NAME FROM information_schema.ROUTINES
                        WHERE ROUTINE_SCHEMA = DATABASE()
                          AND ROUTINE_TYPE = 'PROCEDURE'"))

dbDisconnect(mydb)
