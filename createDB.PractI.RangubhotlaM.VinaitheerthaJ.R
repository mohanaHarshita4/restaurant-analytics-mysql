# createDB.PractI.RangubhotlaM.VinaitheerthaJ.R
# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026
#
# Part C: builds our tables in the Aiven MySQL database. The CREATE
# statements are in schema.RangubhotlaM.VinaitheerthaJ.sql and not in
# this script



rm(list = ls())

# install anything missing then load
packages <- c("DBI", "RMySQL", "RSQLite")
missing  <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(missing) > 0) install.packages(missing)
invisible(lapply(packages, library, character.only = TRUE))

source("dbConfig.R")

schema_file <- "schema.RangubhotlaM.VinaitheerthaJ.sql"


readSqlStatements <- function(file) {
  lines <- readLines(file, warn = FALSE)
  lines <- lines[!grepl("^\\s*--", lines)]
  stmts <- unlist(strsplit(paste(lines, collapse = "\n"), ";"))
  stmts <- trimws(stmts)
  stmts[nchar(stmts) > 0]
}

createSchema <- function(con, file) {
  stmts <- readSqlStatements(file)
  for (s in stmts) {
    dbExecute(con, s)
    table_name <- sub(".*EXISTS\\s+(\\w+).*", "\\1", s)
    cat("table ready:", table_name, "\n")
  }
}

# connect to both databases
mydb   <- connectMySQL()
litedb <- connectSQLite()

createSchema(mydb, schema_file)
print(dbListTables(mydb))

# done, close both connections
dbDisconnect(mydb)
dbDisconnect(litedb)
