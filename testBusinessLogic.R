# testBusinessLogic.R
# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026
#
# Part G tests: shows a pass and a fail case for storeNewVisit and
# modifyServer. Run after configBusinessLogic. Every change made here is
# undone at the end so the Part F checks still match.
#
# AI use: Claude (Anthropic) helped us write parts of this script. We went
# through every line, ran it, and can explain it.

rm(list = ls())

packages <- c("DBI", "RMySQL")
missing  <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")
invisible(lapply(packages, library, character.only = TRUE))

source("dbConfig.R")


# ---------- helpers ----------

# CALL needs the multi-results client flag. Each call uses its own
# connection and drains extra result sets, which avoids the
# "commands out of sync" error from lesson 70.907.
callProc <- function(sql) {
  con <- DBI::dbConnect(RMySQL::MySQL(),
                        user = db_user, password = db_pwd, dbname = db_name,
                        host = db_host, port = db_port,
                        sslmode = "require", sslcert = db_cert,
                        client.flag = RMySQL::CLIENT_MULTI_RESULTS)
  on.exit(dbDisconnect(con))
  rs <- dbSendQuery(con, sql)
  dbClearResult(rs)
  try(while (dbMoreResults(con)) dbClearResult(dbNextResult(con)), silent = TRUE)
  invisible(TRUE)
}

# expect_ok = TRUE: the call should work. FALSE: it should be rejected.
runCase <- function(label, sql, expect_ok) {
  msg <- tryCatch({ callProc(sql); "ok" },
                  error = function(e) conditionMessage(e))
  worked <- identical(msg, "ok")
  verdict <- if (worked == expect_ok) "PASS" else "FAIL"
  detail  <- if (worked) "call succeeded" else paste("rejected:", msg)
  cat(sprintf("[%s] %s\n       %s\n", verdict, label, detail))
  results <<- c(results, worked == expect_ok)
}

results <- c()

mydb <- connectMySQL()
count <- function(sql) as.numeric(dbGetQuery(mydb, sql)[1, 1])


# ---------- storeNewVisit ----------

cat("\n=== storeNewVisit ===\n")

# a real server at restaurant 101, so the test uses existing data
test_emp <- count("SELECT MIN(emp_id) FROM servers WHERE rid = 101")
visits_before <- count("SELECT COUNT(*) FROM visits")
max_vid_before <- count("SELECT MAX(vid) FROM visits")

# pass case: valid lunch visit
runCase("pass: valid new visit",
        sprintf("CALL storeNewVisit(101, %d, NULL, '2026-11-03', '12:30:00',
                 'Lunch', 2, 5, 25.50, 5.00, 0.00, 'Cash', 0.00)", test_emp),
        expect_ok = TRUE)

visits_after <- count("SELECT COUNT(*) FROM visits")
cat(sprintf("       visits: %d -> %d (expected +1) -> %s\n",
            visits_before, visits_after,
            ifelse(visits_after == visits_before + 1, "PASS", "FAIL")))
results <- c(results, visits_after == visits_before + 1)
print(dbGetQuery(mydb, sprintf("SELECT vid, rid, emp_id, visit_date, mtid, food_bill
                                FROM visits WHERE vid > %d", max_vid_before)))

# fail case 1: meal type not in the lookup table
runCase("fail: unknown meal type 'Brunch'",
        sprintf("CALL storeNewVisit(101, %d, NULL, '2026-11-03', '10:00:00',
                 'Brunch', 2, 5, 25.50, 5.00, 0.00, 'Cash', 0.00)", test_emp),
        expect_ok = FALSE)

# fail case 2: negative bill
runCase("fail: negative food bill",
        sprintf("CALL storeNewVisit(101, %d, NULL, '2026-11-03', '12:30:00',
                 'Lunch', 2, 5, -10.00, 5.00, 0.00, 'Cash', 0.00)", test_emp),
        expect_ok = FALSE)

visits_final <- count("SELECT COUNT(*) FROM visits")
cat(sprintf("       visits after fail cases: %d (expected %d) -> %s\n",
            visits_final, visits_after,
            ifelse(visits_final == visits_after, "PASS", "FAIL")))
results <- c(results, visits_final == visits_after)


# ---------- modifyServer ----------

cat("\n=== modifyServer ===\n")

test_server <- 38924
orig_rate <- count(sprintf("SELECT hourly_rate FROM servers WHERE emp_id = %d",
                           test_server))
cat(sprintf("       server %d current hourly_rate: %.2f\n", test_server, orig_rate))

# pass case: change the hourly rate and read it back
runCase("pass: change hourly rate to 18.25",
        sprintf("CALL modifyServer(%d, NULL, NULL, NULL, 18.25, NULL, NULL, NULL)",
                test_server),
        expect_ok = TRUE)
new_rate <- count(sprintf("SELECT hourly_rate FROM servers WHERE emp_id = %d",
                          test_server))
cat(sprintf("       hourly_rate now %.2f -> %s\n", new_rate,
            ifelse(abs(new_rate - 18.25) < 0.001, "PASS", "FAIL")))
results <- c(results, abs(new_rate - 18.25) < 0.001)

# fail cases: one per integrity check we want to show
runCase("fail: server does not exist (emp_id 99999)",
        "CALL modifyServer(99999, NULL, NULL, NULL, 20.00, NULL, NULL, NULL)",
        expect_ok = FALSE)

runCase("fail: negative hourly rate",
        sprintf("CALL modifyServer(%d, NULL, NULL, NULL, -5.00, NULL, NULL, NULL)",
                test_server),
        expect_ok = FALSE)

runCase("fail: restaurant does not exist (rid 999)",
        sprintf("CALL modifyServer(%d, NULL, NULL, NULL, NULL, NULL, NULL, 999)",
                test_server),
        expect_ok = FALSE)

runCase("fail: empty name",
        sprintf("CALL modifyServer(%d, '  ', NULL, NULL, NULL, NULL, NULL, NULL)",
                test_server),
        expect_ok = FALSE)

runCase("fail: end date before start date",
        sprintf("CALL modifyServer(%d, NULL, NULL, '2000-01-01', NULL, NULL, NULL, NULL)",
                test_server),
        expect_ok = FALSE)

rate_after_fails <- count(sprintf("SELECT hourly_rate FROM servers WHERE emp_id = %d",
                                  test_server))
cat(sprintf("       hourly_rate after fail cases still %.2f -> %s\n", rate_after_fails,
            ifelse(abs(rate_after_fails - 18.25) < 0.001, "PASS", "FAIL")))
results <- c(results, abs(rate_after_fails - 18.25) < 0.001)


# ---------- clean up so Part F still matches ----------

cat("\n=== clean up ===\n")
dbExecute(mydb, sprintf("DELETE FROM visits WHERE vid > %d", max_vid_before))
callProc(sprintf("CALL modifyServer(%d, NULL, NULL, NULL, %.2f, NULL, NULL, NULL)",
                 test_server, orig_rate))
cat(sprintf("visits back to %d, server %d rate back to %.2f\n",
            count("SELECT COUNT(*) FROM visits"), test_server,
            count(sprintf("SELECT hourly_rate FROM servers WHERE emp_id = %d",
                          test_server))))

cat(sprintf("\n%d of %d checks passed\n", sum(results), length(results)))

dbDisconnect(mydb)
