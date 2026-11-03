# testDBLoading.PractI.RangubhotlaM.VinaitheerthaJ.R
# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026
#
# Part F: reloads the original CSV and checks that the counts and money
# totals in the MySQL database match it. Prints PASS or FAIL per check.
# Run after loadDB.
#
# AI use: Claude (Anthropic) helped us write parts of this script. We went
# through every line, ran it, and can explain it.

rm(list = ls())

packages <- c("DBI", "RMySQL", "RSQLite")
missing  <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")
invisible(lapply(packages, library, character.only = TRUE))

source("dbConfig.R")

csv_file <- "data/restaurant-visits-209874.csv"


# ---------- helpers ----------

results <- c()

# counts must match exactly; money within one cent (never == on decimals)
check <- function(label, csv_val, db_val, money = FALSE) {
  csv_val <- as.numeric(csv_val)
  db_val  <- as.numeric(db_val)
  ok <- if (money) abs(csv_val - db_val) < 0.01 else csv_val == db_val
  fmt <- if (money) "%-22s CSV: %14.2f   DB: %14.2f   -> %s\n"
         else       "%-22s CSV: %14.0f   DB: %14.0f   -> %s\n"
  cat(sprintf(fmt, label, csv_val, db_val, ifelse(ok, "PASS", "FAIL")))
  results <<- c(results, ok)
}

dbValue <- function(con, sql) {
  dbGetQuery(con, sql)[1, 1]
}


# ---------- load CSV and connect ----------

df <- read.csv(csv_file, stringsAsFactors = FALSE)
cat("rows in CSV:", nrow(df), "\n\n")

mydb   <- connectMySQL()
litedb <- connectSQLite()


# ---------- counts ----------

cat("Counts\n")

check("unique restaurants",
      length(unique(df$RestaurantID)),
      dbValue(mydb, "SELECT COUNT(*) FROM restaurants"))

# only loyalty customers have an email, so those are the customers we store
check("unique customers",
      length(unique(df$CustomerEmail[df$CustomerEmail != ""])),
      dbValue(mydb, "SELECT COUNT(*) FROM customers"))

# servers table also holds servers with no visits (from SQLite), so compare
# the CSV servers with the distinct servers referenced by visits
check("unique servers (visits)",
      length(unique(df$ServerEmpID[!is.na(df$ServerEmpID)])),
      dbValue(mydb, "SELECT COUNT(DISTINCT emp_id) FROM visits
                     WHERE emp_id IS NOT NULL"))

# and the servers table against SQLite after removing the duplicate EmpIDs
check("servers table vs SQLite",
      dbValue(litedb, "SELECT COUNT(DISTINCT EmpID) FROM servers"),
      dbValue(mydb, "SELECT COUNT(*) FROM servers"))

check("visits",
      nrow(df),
      dbValue(mydb, "SELECT COUNT(*) FROM visits"))


# ---------- money totals ----------

cat("\nMoney totals\n")

check("total food",
      sum(df$FoodBill),
      dbValue(mydb, "SELECT SUM(food_bill) FROM visits"), money = TRUE)

check("total alcohol",
      sum(df$AlcoholBill),
      dbValue(mydb, "SELECT SUM(alcohol_bill) FROM visits"), money = TRUE)

check("total tips",
      sum(df$TipAmount),
      dbValue(mydb, "SELECT SUM(tip_amount) FROM visits"), money = TRUE)


# ---------- summary ----------

cat(sprintf("\n%d of %d checks passed\n", sum(results), length(results)))
cat("Note: the servers table has", dbValue(mydb, "SELECT COUNT(*) FROM servers"),
    "rows because SQLite also lists servers who have no visits in the CSV.\n")

dbDisconnect(mydb)
dbDisconnect(litedb)
