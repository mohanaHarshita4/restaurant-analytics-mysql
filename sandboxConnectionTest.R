# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026


rm(list = ls())

# install anything missing, then load
packages <- c("DBI", "RMySQL", "RSQLite")
missing  <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(missing) > 0) install.packages(missing)
invisible(lapply(packages, library, character.only = TRUE))

source("dbConfig.R")

# MySQL check
mydb <- connectMySQL()
print(dbGetQuery(mydb, "SELECT VERSION() AS version"))

dbExecute(mydb, "DROP TABLE IF EXISTS connection_test")
dbExecute(mydb, "CREATE TABLE connection_test (
                   cid INTEGER NOT NULL PRIMARY KEY,
                   title VARCHAR(32) NOT NULL,
                   credits INTEGER NOT NULL,
                   CHECK (credits > 1))")

# Aiven wants single quotes around text
dbExecute(mydb, "INSERT INTO connection_test VALUES
                   (5200, 'DBMS', 4),
                   (5030, 'Intro ML', 3)")
print(dbGetQuery(mydb, "SELECT * FROM connection_test"))

# remove the test table so the database is empty again
dbExecute(mydb, "DROP TABLE connection_test")
print(dbListTables(mydb))
dbDisconnect(mydb)

# SQLite check
litedb <- connectSQLite()
print(dbListTables(litedb))
dbDisconnect(litedb)

cat("connection test passed\n")
