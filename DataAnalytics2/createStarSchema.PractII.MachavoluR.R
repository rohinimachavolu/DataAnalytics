# -------------------------------------
# createStarSchema.PractII.MachavoluR.R
# Part B / Create Star Schema
# Rohini Machavolu
# Spring 2025
# -------------------------------------

# Clean the environment
rm(list = ls())

# Install and load required packages
installRequiredPackages <- function() {
  packages <- c("RMySQL", "DBI")
  installed_packages <- packages %in% rownames(installed.packages())
  if (any(installed_packages == FALSE)) {
    install.packages(packages[!installed_packages])
  }
}

loadRequiredPackages <- function() {
  suppressMessages({
    library(RMySQL)
    library(DBI)
  })
}

installRequiredPackages()
loadRequiredPackages()

# Function to connect to MySQL database
connectToDatabase <- function() {
  dbName <- Sys.getenv("DB_NAME")
  dbUser <- Sys.getenv("DB_USER")
  dbPassword <- Sys.getenv("DB_PASSWORD")
  dbHost <- Sys.getenv("DB_HOST")
  dbPort <- as.integer(Sys.getenv("DB_PORT"))
  
  return(
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

# Connect to MySQL database
mysql_con <- tryCatch({
  connectToDatabase()
}, error = function(e) {
  message("Failed to connect to MySQL: ", e$message)
  message("Switching to SQLite database as fallback.")
  dbConnect(RSQLite::SQLite(), "analytics.db")
})

# Drop existing tables to ensure clean schema
dbExecute(mysql_con, "DROP TABLE IF EXISTS sales_facts;")
dbExecute(mysql_con, "DROP TABLE IF EXISTS dim_customer;")
dbExecute(mysql_con, "DROP TABLE IF EXISTS dim_country;")
dbExecute(mysql_con, "DROP TABLE IF EXISTS dim_date;")

# Create dimension tables
dbExecute(mysql_con, "
  CREATE TABLE dim_date (
    date_id INT PRIMARY KEY,
    sale_date DATE,
    year INT,
    month INT,
    quarter INT
  );")

dbExecute(mysql_con, "
  CREATE TABLE dim_country (
    country_id INT PRIMARY KEY,
    country_name VARCHAR(100)
  );")

dbExecute(mysql_con, "
  CREATE TABLE dim_customer (
    customer_dim_id INT PRIMARY KEY,
    customer_id INT,
    customer_type ENUM('music', 'film')
  );")

# Create fact table
dbExecute(mysql_con, "
  CREATE TABLE sales_facts (
    sale_id INT PRIMARY KEY,
    date_id INT,
    country_id INT,
    customer_dim_id INT,
    product_type ENUM('music', 'film'),
    revenue DECIMAL(10, 4),
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    FOREIGN KEY (country_id) REFERENCES dim_country(country_id),
    FOREIGN KEY (customer_dim_id) REFERENCES dim_customer(customer_dim_id)
  );")

# Disconnect
dbDisconnect(mysql_con)
