# loadDB.PractI.RangubhotlaM.VinaitheerthaJ.R
# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026
#
# Part E: loads the full CSV into df.data, then fills every table in the
# Aiven MySQL database from df.data and the SQLite restaurants/servers tables.
# The SQLite file is only read from, never written to.
# Run order: deleteDB -> createDB -> loadDB -> testDBLoading
#
# AI use: Claude (Anthropic) helped us write parts of this script. We went
# through every line, ran it, and can explain it.

rm(list = ls())

packages <- c("DBI", "RMySQL", "RSQLite")
missing  <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")
invisible(lapply(packages, library, character.only = TRUE))

source("dbConfig.R")

csv_file   <- "data/restaurant-visits-209874.csv"
batch_size <- 1000

# set to TRUE while developing to load only the first subset_n rows
use_subset <- FALSE
subset_n   <- 5000


# ---------- helpers: turn R vectors into SQL literals ----------

# text -> 'value' with apostrophes doubled; NA or blank -> NULL
sqlText <- function(x) {
  out <- paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
  out[is.na(x) | x == ""] <- "NULL"
  out
}

# whole number -> as is; NA -> NULL
sqlInt <- function(x) {
  out <- as.character(as.integer(x))
  out[is.na(x)] <- "NULL"
  out
}

# money / decimal -> 2 decimal places; NA -> NULL
sqlDec <- function(x, digits = 2) {
  out <- sprintf(paste0("%.", digits, "f"), x)
  out[is.na(x)] <- "NULL"
  out
}

# m/d/yyyy text -> 'YYYY-MM-DD' text; blank or bad -> NULL
mdyToSql <- function(x) {
  d <- as.Date(x, format = "%m/%d/%Y")
  sqlText(ifelse(is.na(d), NA, format(d, "%Y-%m-%d")))
}

# one multi-row INSERT per batch instead of one INSERT per row
insertBatches <- function(con, table, cols, values, batch_size = 1000) {
  n      <- length(values)
  starts <- seq(1, n, by = batch_size)
  prefix <- paste0("INSERT INTO ", table, " (",
                   paste(cols, collapse = ", "), ") VALUES ")
  for (b in seq_along(starts)) {
    s <- starts[b]
    e <- min(s + batch_size - 1, n)
    tryCatch(
      dbExecute(con, paste0(prefix, paste(values[s:e], collapse = ", "))),
      error = function(err) {
        stop(sprintf("%s: batch %d (rows %d-%d) failed: %s",
                     table, b, s, e, conditionMessage(err)))
      })
  }
  cat(sprintf("%-16s inserted %d rows\n", table, n))
}


# ---------- step 1: read the CSV ----------

df.data <- read.csv(csv_file, stringsAsFactors = FALSE)
if (use_subset) df.data <- df.data[1:subset_n, ]
cat("rows in df.data:", nrow(df.data), "\n")


# ---------- step 2: build each table's rows ----------

buildRestaurants <- function(litedb) {
  r <- dbGetQuery(litedb, "SELECT rID, RestaurantName, City, State,
                                  hasTableService FROM restaurants")
  vals <- paste0("(", sqlInt(r$rID), ",", sqlText(r$RestaurantName), ",",
                 sqlText(r$City), ",", sqlText(r$State), ",",
                 ifelse(tolower(r$hasTableService) == "yes", 1, 0), ")")
  list(cols = c("rid", "restaurant_name", "city", "state", "has_table_service"),
       vals = vals)
}

# lookup tables: ids 1..n in sorted order, the same order visits uses below
buildLookup <- function(values, id_col, name_col) {
  vals <- paste0("(", seq_along(values), ",", sqlText(values), ")")
  list(cols = c(id_col, name_col), vals = vals)
}

# only rows with an email are loyalty customers; one row per email
buildCustomers <- function(df) {
  c <- df[df$CustomerEmail != "", c("CustomerName", "CustomerPhone",
                                    "CustomerEmail", "LoyaltyMember")]
  c <- c[!duplicated(c$CustomerEmail), ]
  vals <- paste0("(", seq_len(nrow(c)), ",", sqlText(c$CustomerName), ",",
                 sqlText(c$CustomerPhone), ",", sqlText(c$CustomerEmail), ",",
                 as.integer(as.logical(c$LoyaltyMember)), ")")
  list(cols = c("cid", "customer_name", "customer_phone",
                "customer_email", "loyalty_member"),
       vals = vals, emails = c$CustomerEmail)
}

# EmpID 83459, 93168, 80238 appear twice in SQLite: keep the last row
buildServers <- function(litedb) {
  s <- dbGetQuery(litedb, "SELECT * FROM servers")
  s <- s[!duplicated(s$EmpID, fromLast = TRUE), ]
  vals <- paste0("(", sqlInt(s$EmpID), ",", sqlText(s$ServerName), ",",
                 sqlText(s$StartDateHired), ",", sqlText(s$EndDateHired), ",",
                 sqlDec(as.numeric(s$HourlyRate)), ",", mdyToSql(s$BirthDate), ",",
                 sqlText(s$SSN), ",", sqlInt(s$rID), ")")
  list(cols = c("emp_id", "server_name", "start_date_hired", "end_date_hired",
                "hourly_rate", "birth_date", "ssn", "rid"),
       vals = vals)
}

buildVisits <- function(df, meal_types, pay_methods, cust_emails) {
  # visit_date is NOT NULL, so stop instead of guessing if any date is bad
  bad_date <- is.na(as.Date(df$VisitDate, format = "%Y-%m-%d"))
  if (any(bad_date)) stop(sum(bad_date), " rows have a missing/invalid VisitDate")

  emp_id     <- df$ServerEmpID                       # NA when no server ("N/A")
  cid        <- match(df$CustomerEmail, cust_emails) # NA when blank / no match
  visit_time <- ifelse(df$VisitTime == "", NA, paste0(df$VisitTime, ":00"))
  party_size <- ifelse(df$PartySize == 99, NA, df$PartySize)  # 99 = unknown
  wait_time  <- ifelse(df$WaitTime < 0, NA, df$WaitTime)      # negative = invalid
  mtid       <- match(df$MealType, meal_types)
  pmid       <- match(df$PaymentMethod, pay_methods)

  vals <- paste0("(", seq_len(nrow(df)), ",", sqlInt(df$RestaurantID), ",",
                 sqlInt(emp_id), ",", sqlInt(cid), ",",
                 sqlText(df$VisitDate), ",", sqlText(visit_time), ",",
                 mtid, ",", sqlInt(party_size), ",", sqlInt(wait_time), ",",
                 sqlDec(df$FoodBill), ",", sqlDec(df$TipAmount), ",",
                 sqlDec(df$FoodDiscountPercentage), ",", pmid, ",",
                 sqlDec(df$AlcoholBill), ")")
  list(cols = c("vid", "rid", "emp_id", "cid", "visit_date", "visit_time",
                "mtid", "party_size", "wait_time", "food_bill", "tip_amount",
                "food_discount_pct", "pmid", "alcohol_bill"),
       vals = vals)
}


# ---------- step 3: load, parents before children ----------

mydb   <- connectMySQL()
litedb <- connectSQLite()

# loading twice would hit duplicate keys, so require empty tables
if (dbGetQuery(mydb, "SELECT COUNT(*) AS n FROM visits")$n > 0) {
  stop("visits is not empty: run deleteDB and createDB first")
}

start_time <- Sys.time()

meal_types  <- sort(unique(df.data$MealType))
pay_methods <- sort(unique(df.data$PaymentMethod))

rest <- buildRestaurants(litedb)
insertBatches(mydb, "restaurants", rest$cols, rest$vals, batch_size)

mt <- buildLookup(meal_types, "mtid", "meal_type")
insertBatches(mydb, "meal_types", mt$cols, mt$vals, batch_size)

pm <- buildLookup(pay_methods, "pmid", "payment_method")
insertBatches(mydb, "payment_methods", pm$cols, pm$vals, batch_size)

cust <- buildCustomers(df.data)
insertBatches(mydb, "customers", cust$cols, cust$vals, batch_size)

srv <- buildServers(litedb)
insertBatches(mydb, "servers", srv$cols, srv$vals, batch_size)

# visits in one transaction: faster, and all or nothing
vis <- buildVisits(df.data, meal_types, pay_methods, cust$emails)
dbBegin(mydb)
tryCatch({
  insertBatches(mydb, "visits", vis$cols, vis$vals, batch_size)
  dbCommit(mydb)
}, error = function(err) {
  dbRollback(mydb)
  stop(err)
})

elapsed <- difftime(Sys.time(), start_time, units = "secs")
cat(sprintf("load finished in %.1f seconds\n", as.numeric(elapsed)))

# quick row counts (testDBLoading does the full checks)
for (t in c("restaurants", "meal_types", "payment_methods",
            "customers", "servers", "visits")) {
  n <- dbGetQuery(mydb, paste0("SELECT COUNT(*) AS n FROM ", t))$n
  cat(sprintf("%-16s %d rows\n", t, n))
}

dbDisconnect(mydb)
dbDisconnect(litedb)
