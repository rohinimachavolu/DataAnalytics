# -------------------------------------
# loadDB.PractI.MachavoluR.R
# Part E / Populate Database
# Rohini Machavolu
# Spring 2025
# -------------------------------------


# Clean environment
rm(list = ls())

# Load required packages
suppressMessages({
  library(RMySQL)
  library(DBI)
  library(dplyr)
  library(lubridate)
  library(readr)
  library(stringr)
})

# Connect to DB
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

# Load and clean data
#df.orig <- read_csv("200va.csv")
df.orig <- read_csv("https://s3.us-east-2.amazonaws.com/artificium.us/datasets/restaurant-visits-139874.csv")
# Function to safely convert dates
head(df.orig)
# Check the first few rows of date columns

df.orig <- df.orig %>%
  mutate(

    VisitDate = ymd(VisitDate),
    StartDateHired = ymd(StartDateHired),
    EndDateHired = ymd(EndDateHired),
    ServerBirthDate = mdy(ServerBirthDate),
    PartySize = ifelse(PartySize == 99, 1, PartySize),
    ServerName = na_if(ServerName, "N/A"),
    HourlyRate = na_if(HourlyRate, 0),
    TipAmount = pmax(TipAmount, 0),
    WaitTime = pmax(WaitTime, 0),
    orderedAlcohol = tolower(orderedAlcohol) == "yes",
    AlcoholBill = ifelse(!orderedAlcohol, 0, AlcoholBill)
  )


# Insert already pre Knew Values into PaymentMethod
InsertIntoPaymentMethod <- function() {
  return (
    "INSERT IGNORE INTO PaymentMethod (PaymentMethodID, PaymentMethodName) VALUES
      (1, 'Mobile Payment'),
      (2, 'Cash'),
      (3, 'Credit Card');"
  )
}

# Insert already pre Knew Values into MealType
InsertIntoMealType <- function() {
  return (
    "INSERT IGNORE INTO MealType (MealTypeID, MealTypeName) VALUES
      (1, 'Take-Out'),
      (2, 'Breakfast'),
      (3, 'Lunch'),
      (4, 'Dinner');"
  )
}


# Pre-populate lookup tables (skip if already populated)
insertFixedValues <- function(dbCon) {
  dbExecute(dbCon, InsertIntoPaymentMethod())
  dbExecute(dbCon, InsertIntoMealType())
}

# Generic batch insert
insertInBatches <- function(dbCon, tableName, columns, data, batchSize = 2000) {
  total <- nrow(data)
  numBatches <- ceiling(total / batchSize)
  
  for (i in seq_len(numBatches)) {
    start <- (i - 1) * batchSize + 1
    end <- min(i * batchSize, total)
    batch <- data[start:end, ]
    
    values <- apply(batch, 1, function(row) {
      vals <- sapply(row, function(x) {
        if (is.na(x) || x == "NULL") "NULL"
        else sprintf("'%s'", gsub("'", "''", x))
      })
      paste0("(", paste(vals, collapse = ","), ")")
    })
    
    query <- sprintf("INSERT IGNORE INTO %s (%s) VALUES %s;",
                     tableName,
                     paste(columns, collapse = ", "),
                     paste(values, collapse = ", "))
    
    dbExecute(dbCon, query)
  }
}

# Insert Restaurants
insertRestaurants <- function(dbCon, df) {
  restaurants <- df %>%
    select(Restaurant) %>%
    distinct() %>%
    rename(RestaurantName = Restaurant)
  
  insertInBatches(dbCon, "Restaurant", c("RestaurantName"), restaurants)
}

# Insert Servers (batch insert and update)
insertServers <- function(dbCon, df) {
  servers <- df %>%
    select(ServerEmpID, ServerName, StartDateHired, EndDateHired, HourlyRate, ServerBirthDate, ServerTIN) %>%
    filter(!is.na(ServerEmpID)) %>%
    distinct()
  
  insertInBatches(dbCon, "Server",
                  c("ServerEmpID", "ServerName", "StartDateHired", "EndDateHired", "HourlyRate", "ServerBirthDate", "ServerTIN"),
                  servers)
}

# Insert Customers
insertCustomers <- function(dbCon, df) {
  customers <- df %>%
    select(CustomerName, CustomerPhone, CustomerEmail, LoyaltyMember) %>%
    filter(!is.na(CustomerName) & CustomerName != "") %>%
    distinct() %>%
    mutate(LoyaltyMember = ifelse(LoyaltyMember == "TRUE", 1, 0))
  
  insertInBatches(dbCon, "Customer",
                  c("CustomerName", "CustomerPhone", "CustomerEmail", "LoyaltyMember"),
                  customers)
}

# Fetch ID Mappings for joins
getMappings <- function(dbCon) {
  list(
    Restaurant = dbGetQuery(dbCon, "SELECT RestaurantID, RestaurantName FROM Restaurant"),
    Customer = dbGetQuery(dbCon, "SELECT CustomerID, CustomerName FROM Customer"),
    MealType = dbGetQuery(dbCon, "SELECT MealTypeID, MealTypeName FROM MealType"),
    PaymentMethod = dbGetQuery(dbCon, "SELECT PaymentMethodID, PaymentMethodName FROM PaymentMethod")
  )
}

# Prepare Visit records
prepareVisits <- function(df, mappings) {
  df %>%
    left_join(mappings$Restaurant, by = c("Restaurant" = "RestaurantName")) %>%
    left_join(mappings$Customer, by = c("CustomerName" = "CustomerName")) %>%
    left_join(mappings$MealType, by = c("MealType" = "MealTypeName")) %>%
    left_join(mappings$PaymentMethod, by = c("PaymentMethod" = "PaymentMethodName")) %>%
    mutate(
      OrderedAlcohol = ifelse(orderedAlcohol, 1, 0),
      VisitTime = ifelse(is.na(VisitTime), "", VisitTime)
    ) %>%
    select(RestaurantID, ServerEmpID, CustomerID,
           VisitDate, VisitTime, MealTypeID,
           PartySize, Genders, WaitTime,
           FoodBill, TipAmount, DiscountApplied,
           PaymentMethodID, OrderedAlcohol, AlcoholBill)
}

# Insert Visits
insertVisits <- function(dbCon, visits) {
  insertInBatches(dbCon, "Visit",
                  c("RestaurantID", "ServerEmpID", "CustomerID", "VisitDate", "VisitTime",
                    "MealTypeID", "PartySize", "Genders", "WaitTime",
                    "FoodBill", "TipAmount", "DiscountApplied",
                    "PaymentMethodID", "OrderedAlcohol", "AlcoholBill"),
                  visits)
}

# MAIN EXECUTION
con <- connectToDatabase()

insertFixedValues(con)

insertRestaurants(con, df.orig)
insertServers(con, df.orig)
insertCustomers(con, df.orig)

mappings <- getMappings(con)

visits <- prepareVisits(df.orig, mappings)

insertVisits(con, visits)

dbDisconnect(con)

print("Database population complete!")
