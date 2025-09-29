# -------------------------------------
# createDB.PractI.MachavoluR.R
# Part C / Realize Database
# Rohini Machavolu
# 11 March 2025
# -------------------------------------
  
# Clean the environment before beginning the execution
rm(list = ls())

# Install required packages
installRequiredPackages <- function() {
  packages <- c("RMySQL", "DBI", "testthat", "kableExtra", "jsonlite")
  installed_packages <- packages %in% rownames(installed.packages())
  if (any(installed_packages == FALSE)) {
    install.packages(packages[!installed_packages])
  }
}

# Load the required packages
loadRequiredPackages <- function() {
  suppressMessages({
    library(RMySQL)
    library(DBI)
    library(kableExtra)
    library(testthat)
    library(jsonlite)
  })
}

installRequiredPackages()
loadRequiredPackages()

# Function to connect to the database
connectToDatabase <- function() {
  dbName <- Sys.getenv("DB_NAME")
  dbUser <- Sys.getenv("DB_USER")
  dbPassword <- Sys.getenv("DB_PASSWORD")
  dbHost <- Sys.getenv("DB_HOST")
  dbPort <- as.integer(Sys.getenv("DB_PORT"))
  
  return (
    dbConnect(
      RMySQL::MySQL(),
      user = dbUser,
      password = dbPassword,
      dbname = dbName,
      host = dbHost,
      port = dbPort
    )
  )
}

# Table creation functions (with 3NF normalization and constraints)

CreateRestaurant <- function() {
  return ('CREATE TABLE IF NOT EXISTS Restaurant (
    RestaurantID INT PRIMARY KEY AUTO_INCREMENT,
    RestaurantName VARCHAR(255) UNIQUE NOT NULL
  );')
}

CreateServer <- function() {
  return ('CREATE TABLE IF NOT EXISTS Server (
    ServerEmpID INT PRIMARY KEY,
    ServerName VARCHAR(255) ,
    StartDateHired DATE ,
    EndDateHired DATE ,
    HourlyRate DECIMAL(5,2) DEFAULT 0 CHECK (HourlyRate >= 0),
    ServerBirthDate DATE,
    ServerTIN VARCHAR(15)
  );')
}

CreateCustomer <- function() {
  return ('CREATE TABLE IF NOT EXISTS Customer (
    CustomerID INT PRIMARY KEY AUTO_INCREMENT,
    CustomerName VARCHAR(255),
    CustomerPhone VARCHAR(20),
    CustomerEmail VARCHAR(255) UNIQUE,
    LoyaltyMember BOOLEAN DEFAULT FALSE
  );')
}

CreatePaymentMethod <- function() {
  return ('CREATE TABLE IF NOT EXISTS PaymentMethod (
    PaymentMethodID INT PRIMARY KEY AUTO_INCREMENT,
    PaymentMethodName VARCHAR(50) UNIQUE NOT NULL
  );')
}

CreateMealType <- function() {
  return ('CREATE TABLE IF NOT EXISTS MealType (
    MealTypeID INT PRIMARY KEY AUTO_INCREMENT,
    MealTypeName VARCHAR(50) UNIQUE NOT NULL
  );')
}

CreateVisit <- function() {
  return ('CREATE TABLE IF NOT EXISTS Visit (
    VisitID INT PRIMARY KEY AUTO_INCREMENT,
    RestaurantID INT NOT NULL,
    ServerEmpID INT ,
    CustomerID INT ,
    VisitDate DATE NOT NULL,
    VisitTime TIME ,
    MealTypeID INT DEFAULT 1, -- Defaults to Take-Out (ID 1)
    PartySize INT NOT NULL DEFAULT 1 CHECK (PartySize > 0),
    Genders VARCHAR(50) DEFAULT NULL,
    WaitTime INT DEFAULT 0 CHECK (WaitTime >= 0),
    FoodBill DECIMAL(7,2) NOT NULL CHECK (FoodBill >= 0),
    TipAmount DECIMAL(7,2) DEFAULT 0 CHECK (TipAmount >= 0),
    DiscountApplied DECIMAL(5,2) DEFAULT 0 CHECK (DiscountApplied >= 0),
    PaymentMethodID INT NOT NULL DEFAULT 2,  -- Default is Cash
    OrderedAlcohol BOOLEAN NOT NULL DEFAULT FALSE,
    AlcoholBill DECIMAL(7,4) NOT NULL DEFAULT 0 CHECK (AlcoholBill >= 0),
    CHECK (
      (OrderedAlcohol = TRUE AND AlcoholBill >= 0)
      OR
      (OrderedAlcohol = FALSE AND AlcoholBill = 0)
    ),
    FOREIGN KEY (RestaurantID) REFERENCES Restaurant(RestaurantID),
    FOREIGN KEY (ServerEmpID) REFERENCES Server(ServerEmpID),
    FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID),
    FOREIGN KEY (MealTypeID) REFERENCES MealType(MealTypeID),
    FOREIGN KEY (PaymentMethodID) REFERENCES PaymentMethod(PaymentMethodID)
  );')
}

# Function to execute SQL commands
executeSQL <- function(connection, sql) {
  dbExecute(connection, sql)
}

# Connect to the database
con <- connectToDatabase()

# Create Tables
executeSQL(con, CreateRestaurant())
executeSQL(con, CreateServer())
executeSQL(con, CreateCustomer())
executeSQL(con, CreatePaymentMethod())
executeSQL(con, CreateMealType())
executeSQL(con, CreateVisit())

# Disconnect from the database
dbDisconnect(con)
