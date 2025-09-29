# ----------------------------------------------------
# testDBLoading.PractI.MachavoluR.R
# Part F / Test Data Loading Process
# Rohini Machavolu
# Spring 2025
# ----------------------------------------------------

# Clean environment
rm(list = ls())

# Load required packages
suppressMessages({
  library(RMySQL)
  library(DBI)
  library(dplyr)
  library(readr)
})

# Connect to database
connectToDatabase <- function() {
  dbConnect(
    RMySQL::MySQL(),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD"),
    dbname = Sys.getenv("DB_NAME"),
    host = Sys.getenv("DB_HOST"),
    port = as.integer(Sys.getenv("DB_PORT"))
  )
}


# Load data (again, swap in URL before submission)
#df.orig <- read_csv("200va.csv")
df.orig <- read_csv("https://s3.us-east-2.amazonaws.com/artificium.us/datasets/restaurant-visits-139874.csv")

# Establish database connection
con <- connectToDatabase()

# Helper function for comparison messages
compareValues <- function(label, csvValue, dbValue) {
  if (csvValue == dbValue) {
    message(sprintf("[PASS] %s matches: %.2f", label, csvValue))
  } else {
    message(sprintf("[FAIL] %s does not match: CSV=%.2f, DB=%.2f", label, csvValue, dbValue))
  }
}
# Test 1: Counts --------------------------------------------------

# Unique counts in CSV (excluding empty strings and NA)
csv_restaurants <- n_distinct(df.orig$Restaurant[!is.na(df.orig$Restaurant) & df.orig$Restaurant != ""])
csv_customers   <- n_distinct(df.orig$CustomerName[!is.na(df.orig$CustomerName) & df.orig$CustomerName != ""])
csv_servers     <- n_distinct(df.orig$ServerEmpID[!is.na(df.orig$ServerEmpID) & df.orig$ServerEmpID != ""])
csv_visits      <- nrow(df.orig)

# Counts in DB
db_restaurants <- dbGetQuery(con, "SELECT COUNT(*) AS count FROM Restaurant")$count
db_customers   <- dbGetQuery(con, "SELECT COUNT(*) AS count FROM Customer")$count
db_servers     <- dbGetQuery(con, "SELECT COUNT(*) AS count FROM Server")$count
db_visits      <- dbGetQuery(con, "SELECT COUNT(*) AS count FROM Visit")$count

# Compare counts
compareValues("Restaurants", csv_restaurants, db_restaurants)
compareValues("Customers", csv_customers, db_customers)
compareValues("Servers", csv_servers, db_servers)
compareValues("Visits", csv_visits, db_visits)

# Test 2: Total Sums --------------------------------------------------

# Totals from CSV
csv_foodbill <- sum(df.orig$FoodBill, na.rm = TRUE)
csv_alcohol  <- sum(df.orig$AlcoholBill, na.rm = TRUE)
csv_tip      <- sum(df.orig$TipAmount, na.rm = TRUE)
suppressWarnings({
  # Your code here

# Totals from DB (Visit table)
db_foodbill <- dbGetQuery(con, "SELECT SUM(FoodBill) AS total FROM Visit")$total
db_alcohol  <- dbGetQuery(con, "SELECT SUM(AlcoholBill) AS total FROM Visit")$total
db_tip      <- dbGetQuery(con, "SELECT SUM(TipAmount) AS total FROM Visit")$total

# Compare sums
compareValues("Total Food Bill", round(csv_foodbill, 2), round(db_foodbill, 2))
compareValues("Total Alcohol Bill", round(csv_alcohol, 4), round(db_alcohol, 4))
compareValues("Total Tip Amount", round(csv_tip, 2), round(db_tip, 2))
})
# Disconnect
dbDisconnect(con)
