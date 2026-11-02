# Mohana Rangubhotla, Jayshree Vinaitheertha
# CS5200, Fall 2026

if (!dir.exists("data"))    dir.create("data")
if (!dir.exists("private")) dir.create("private")

csv_zip_url <- "https://s3.us-east-2.amazonaws.com/artificium.us/datasets/restaurant-visits-209874.csv.zip"
sqlite_url  <- "https://s3.us-east-2.amazonaws.com/artificium.us/datasets/restaurants-db-02102026.sqlitedb"

csv_zip  <- "data/restaurant-visits-209874.csv.zip"
sqlitedb <- "data/restaurants-db-02102026.sqlitedb"

# wb mode so windows does not mess up the binary files
if (!file.exists(csv_zip))  download.file(csv_zip_url, csv_zip,  mode = "wb")
if (!file.exists(sqlitedb)) download.file(sqlite_url,  sqlitedb, mode = "wb")

# only need the csv out of the zip, the __MACOSX folder is junk
unzip(csv_zip, files = "restaurant-visits-209874.csv", exdir = "data")
if (dir.exists("data/__MACOSX")) unlink("data/__MACOSX", recursive = TRUE)

print(list.files("data"))
