# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026

rm(list = ls())

library(DBI)
library(RSQLite)

csv_file    <- "data/restaurant-visits-209874.csv"
sqlite_file <- "data/restaurants-db-02102026.sqlitedb"

# just the first 2000 rows, the full file is slow to read
df.peek <- read.csv(csv_file, nrows = 2000, stringsAsFactors = FALSE)

print(colnames(df.peek))
print(head(df.peek, 3))
print(sapply(df.peek, class))
print(summary(df.peek))

# values in the category columns
for (col in c("MealType", "PaymentMethod", "orderedAlcohol", "LoyaltyMember")) {
  cat("\n", col, "\n")
  print(table(df.peek[[col]], useNA = "ifany"))
}

# tables in the sqlite file
litedb <- dbConnect(RSQLite::SQLite(), sqlite_file)
for (t in dbListTables(litedb)) {
  cat("\n", t, "\n")
  print(dbListFields(litedb, t))
  print(dbGetQuery(litedb, paste0("SELECT * FROM ", t, " LIMIT 3")))
  print(dbGetQuery(litedb, paste0("SELECT COUNT(*) AS n FROM ", t)))
}
dbDisconnect(litedb)

cat("\ncsv rows:", length(readLines(csv_file)) - 1, "\n")
