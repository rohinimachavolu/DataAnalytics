# -------------------------------------
# deleteDB.PractI.MachavoluR.R
# Part D / Delete Database
# Rohini Machavolu
# Spring 2025
# -------------------------------------


# Clean environment
rm(list = ls())

# Install required packages
installRequiredPackages <- function() {
  packages <- c("RMySQL", "DBI")
  installed_packages <- packages %in% rownames(installed.packages())
  if (any(installed_packages == FALSE)) {
    install.packages(packages[!installed_packages])
  }
}

# Load required packages
loadRequiredPackages <- function() {
  suppressMessages({
    library(RMySQL)
    library(DBI)
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

# Function to drop tables (in reverse order due to foreign key constraints)
dropTables <- function(connection) {
  tables <- c("Visit", "MealType", "PaymentMethod", "Customer", "Server", "Restaurant")
  
  for (table in tables) {
    dropSQL <- paste0("DROP TABLE IF EXISTS ", table, ";")
    message("Dropping table: ", table)
    
    tryCatch({
      dbExecute(connection, dropSQL)
    }, error = function(e) {
      message("Error dropping table ", table, ": ", e$message)
    })
  }
}

# MAIN PROGRAM EXECUTION
con <- connectToDatabase()

# Disable foreign key checks to prevent errors when dropping tables
dbExecute(con, "SET FOREIGN_KEY_CHECKS = 0;")

# Drop all tables
dropTables(con)

# Re-enable foreign key checks
dbExecute(con, "SET FOREIGN_KEY_CHECKS = 1;")

message("All tables dropped successfully!")

# Disconnect from the database
dbDisconnect(con)


