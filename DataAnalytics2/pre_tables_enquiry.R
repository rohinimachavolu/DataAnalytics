# Load necessary libraries
library(DBI)
library(RSQLite)
library(dplyr)

# Connect to both databases
film_db <- dbConnect(RSQLite::SQLite(), "film-sales.db")
music_db <- dbConnect(RSQLite::SQLite(), "music-sales.db")

# Helper function to inspect a database
inspect_db <- function(con, db_name) {
  cat(paste0("\n### Inspecting: ", db_name, " ###\n"))
  
  # List all tables
  tables <- dbListTables(con)
  cat("Tables:\n")
  print(tables)
  
  # For each table, show its structure
  for (table in tables) {
    cat(paste0("\nStructure of table: ", table, "\n"))
    print(dbGetQuery(con, paste0("PRAGMA table_info(", table, ");")))
    
    # Preview first 5 rows
    cat(paste0("First 5 rows of ", table, ":\n"))
    print(dbGetQuery(con, paste0("SELECT * FROM ", table, " LIMIT 5;")))
  }
}

# Inspect both databases
inspect_db(film_db, "film-sales.db")
inspect_db(music_db, "music-sales.db")

# Disconnect when done
dbDisconnect(film_db)
dbDisconnect(music_db)

