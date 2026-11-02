# deleteDB.PractI.RangubhotlaM.VinaitheerthaJ.R
# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026
#
# Part D: drops all of our tables (and the Part G procedures) so we
# can start over with createDB. 


rm(list = ls())

packages <- c("DBI", "RMySQL")
missing  <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(missing) > 0) install.packages(missing)
invisible(lapply(packages, library, character.only = TRUE))

source("dbConfig.R")

# visits first since it points to everything else restaurants last
tables <- c("visits", "servers", "customers",
            "meal_types", "payment_methods", "restaurants")

mydb <- connectMySQL()

for (t in tables) {
  dbExecute(mydb, paste0("DROP TABLE IF EXISTS ", t))
  cat("dropped:", t, "\n")
}

# procedures from Part G
dbExecute(mydb, "DROP PROCEDURE IF EXISTS storeNewVisit")
dbExecute(mydb, "DROP PROCEDURE IF EXISTS modifyServer")

# should print character(0)
print(dbListTables(mydb))

dbDisconnect(mydb)
