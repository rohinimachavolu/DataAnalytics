# -------------------------------------
# loadAnalyticsDB.PractII.MachavoluR.R
# Part C / Load Analytics Database
# Rohini Machavolu
# Spring 2025
# -------------------------------------
# Acknowledgement: 
# AI assistance (ChatGPT) was used for reference and clarification on R syntax and code structure. 
# All final code was reviewed and edited manually, and I am able to explain each part.

# Clean the environment
rm(list = ls())

# Install and load required packages
installRequiredPackages <- function() {
  packages <- c("RMySQL", "DBI", "testthat", "kableExtra", "jsonlite", "lubridate", "RSQLite")
  installed_packages <- packages %in% rownames(installed.packages())
  if (any(installed_packages == FALSE)) {
    install.packages(packages[!installed_packages])
  }
}

loadRequiredPackages <- function() {
  suppressMessages({
    library(RMySQL)
    library(DBI)
    library(kableExtra)
    library(testthat)
    library(jsonlite)
    library(lubridate)
    library(RSQLite)
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

# Connect to databases
mysql_con <- connectToDatabase()
film_con <- dbConnect(RSQLite::SQLite(), "film-sales.db")
music_con <- dbConnect(RSQLite::SQLite(), "music-sales.db")

# Chunked Data Extraction

fetchData <- function(con, query, chunk_size = 100000) {
  offset <- 0
  results <- list()
  repeat {
    chunk_query <- sprintf("%s LIMIT %d OFFSET %d", query, chunk_size, offset)
    chunk <- dbGetQuery(con, chunk_query)
    if (nrow(chunk) == 0) break
    results[[length(results) + 1]] <- chunk
    offset <- offset + chunk_size
  }
  if (length(results) == 0) return(data.frame())
  do.call(rbind, results)
}

# Queries to extract only necessary data
film_query <- "
  SELECT 
    r.rental_id AS sale_id,
    DATE(r.rental_date) AS sale_date,
    c.customer_id,
    co.country AS country_name,
    p.amount AS revenue,
    'film' AS product_type
  FROM rental r
  JOIN payment p ON r.rental_id = p.rental_id
  JOIN customer c ON r.customer_id = c.customer_id
  JOIN address a ON c.address_id = a.address_id
  JOIN city ci ON a.city_id = ci.city_id
  JOIN country co ON ci.country_id = co.country_id
"
music_query <- "
  SELECT 
    i.InvoiceId AS sale_id,
    DATE(i.InvoiceDate) AS sale_date,
    i.CustomerId AS customer_id,
    cu.Country AS country_name,
    i.Total AS revenue,
    'music' AS product_type
  FROM invoices i
  JOIN customers cu ON i.CustomerId = cu.CustomerId
  GROUP BY i.InvoiceId, i.InvoiceDate, i.CustomerId, cu.Country
"
# Fetch data in chunks
film_data <- fetchData(film_con, film_query)
music_data <- fetchData(music_con, music_query)

# Type conversions
film_data$sale_date <- as.Date(film_data$sale_date)
music_data$sale_date <- as.Date(music_data$sale_date)
film_data$product_type <- as.character(film_data$product_type)
music_data$product_type <- as.character(music_data$product_type)


# Process Dimensions

# Initialize dimension tables
dim_date <- data.frame(date_id = integer(), sale_date = as.Date(character()), year = integer(), month = integer(), quarter = integer())
dim_country <- data.frame(country_id = integer(), country_name = character())
dim_customer <- data.frame(customer_dim_id = integer(), customer_id = integer(), customer_type = character())

# Process dimensions incrementally
processDimensions <- function(data, dim_date, dim_country, dim_customer) {
  if (nrow(data) == 0) return(list(dim_date = dim_date, dim_country = dim_country, dim_customer = dim_customer))
  
  # Extract date components
  data$year <- lubridate::year(data$sale_date)
  data$month <- lubridate::month(data$sale_date)
  data$quarter <- lubridate::quarter(data$sale_date)
  
  # Update dim_date
  new_dates <- unique(data[, c("sale_date", "year", "month", "quarter")])
  new_dates <- new_dates[!new_dates$sale_date %in% dim_date$sale_date, ]
  if (nrow(new_dates) > 0) {
    new_dates$date_id <- seq_len(nrow(new_dates)) + nrow(dim_date)
    dim_date <- rbind(dim_date, new_dates[, c("date_id", "sale_date", "year", "month", "quarter")])
  }
  
  # Update dim_country
  new_countries <- unique(data$country_name)
  new_countries <- new_countries[!new_countries %in% dim_country$country_name]
  if (length(new_countries) > 0) {
    new_dim_country <- data.frame(
      country_name = new_countries,
      country_id = seq_len(length(new_countries)) + nrow(dim_country)
    )
    dim_country <- rbind(dim_country, new_dim_country)
  }
  
  # Update dim_customer
  new_customers <- unique(data[, c("customer_id", "product_type")])
  new_customers$key <- paste(new_customers$customer_id, new_customers$product_type)
  existing_keys <- paste(dim_customer$customer_id, dim_customer$customer_type)
  new_customers <- new_customers[!new_customers$key %in% existing_keys, ]
  if (nrow(new_customers) > 0) {
    new_customers$customer_dim_id <- seq_len(nrow(new_customers)) + nrow(dim_customer)
    new_customers$customer_type <- new_customers$product_type
    dim_customer <- rbind(dim_customer, new_customers[, c("customer_dim_id", "customer_id", "customer_type")])
  }
  
  list(
    dim_date = dim_date,
    dim_country = dim_country,
    dim_customer = dim_customer,
    data = data
  )
}

# Process film and music data
result <- processDimensions(film_data, dim_date, dim_country, dim_customer)
dim_date <- result$dim_date
dim_country <- result$dim_country
dim_customer <- result$dim_customer
film_data <- result$data

result <- processDimensions(music_data, dim_date, dim_country, dim_customer)
dim_date <- result$dim_date
dim_country <- result$dim_country
dim_customer <- result$dim_customer
music_data <- result$data


# Compute Facts

# Combine data
combined_data <- rbind(film_data, music_data)
combined_data <- combined_data[order(combined_data$sale_date), ]
# Add a new unique sale_id
combined_data$new_sale_id <- seq_len(nrow(combined_data))

# Create fact table
sales_facts <- data.frame(
  sale_id = combined_data$new_sale_id,
  date_id = match(combined_data$sale_date, dim_date$sale_date),
  country_id = match(combined_data$country_name, dim_country$country_name),
  customer_dim_id = match(
    paste(combined_data$customer_id, combined_data$product_type),
    paste(dim_customer$customer_id, dim_customer$customer_type)
  ),
  product_type = combined_data$product_type,
  revenue = combined_data$revenue
)

# Check for NA in foreign keys
if (any(is.na(sales_facts$date_id))) stop("NA found in date_id")
if (any(is.na(sales_facts$country_id))) stop("NA found in country_id")
if (any(is.na(sales_facts$customer_dim_id))) stop("NA found in customer_dim_id")


# Load into MySQL

# Batch insert function
batchInsert <- function(con, table_name, data, batch_size = 500) {
  n_rows <- nrow(data)
  if (n_rows == 0) {
    cat("No rows to insert into", table_name, "\n")
    return()
  }
  
  cols <- paste(colnames(data), collapse = ", ")
  
  for (start in seq(1, n_rows, by = batch_size)) {
    end <- min(start + batch_size - 1, n_rows)
    batch_data <- data[start:end, , drop = FALSE]
    
    value_rows <- character()
    for (i in 1:nrow(batch_data)) {
      row <- batch_data[i, ]
      formatted <- sapply(row, function(val) {
        if (is.na(val)) {
          "NULL"
        } else if (is.character(val) || inherits(val, "Date")) {
          sprintf("'%s'", gsub("'", "''", as.character(val)))
        } else {
          as.character(val)
        }
      })
      value_rows <- c(value_rows, paste0("(", paste(formatted, collapse = ", "), ")"))
    }
    
    if (length(value_rows) > 0) {
      values <- paste(value_rows, collapse = ", ")
      sql <- sprintf("INSERT INTO %s (%s) VALUES %s", table_name, cols, values)
      
      tryCatch({
        dbExecute(con, sql)
      }, error = function(e) {
        cat("Error inserting into", table_name, ":", e$message, "\n")
        cat("SQL:", sql, "\n")
      })
    }
  }
}

# Load data
dbExecute(mysql_con, "SET FOREIGN_KEY_CHECKS = 0;")
batchInsert(mysql_con, "dim_date", dim_date, batch_size = 500)
batchInsert(mysql_con, "dim_country", dim_country, batch_size = 500)
batchInsert(mysql_con, "dim_customer", dim_customer, batch_size = 500)
batchInsert(mysql_con, "sales_facts", sales_facts, batch_size = 500)
dbExecute(mysql_con, "SET FOREIGN_KEY_CHECKS = 1;")


# Validation Queries


# Revenue Check for Music
cloud_music_revenue <- dbGetQuery(mysql_con, "
  SELECT SUM(revenue) AS music_revenue 
  FROM sales_facts 
  WHERE product_type = 'music'
")$music_revenue

local_music_revenue <- sum(music_data$revenue, na.rm = TRUE)

cat("Music revenue - Cloud:", cloud_music_revenue, "| Local:", local_music_revenue, "\n")

# Revenue Check for Film
cloud_film_revenue <- dbGetQuery(mysql_con, "
  SELECT SUM(revenue) AS film_revenue 
  FROM sales_facts 
  WHERE product_type = 'film'
")$film_revenue

local_film_revenue <- sum(film_data$revenue, na.rm = TRUE)

cat("Film revenue - Cloud:", cloud_film_revenue, "| Local:", local_film_revenue, "\n")

# Total Revenue Check
cloud_total_revenue <- dbGetQuery(mysql_con, "
  SELECT SUM(revenue) AS total_revenue 
  FROM sales_facts
")$total_revenue

local_total_revenue <- sum(combined_data$revenue, na.rm = TRUE)

cat("Total revenue - Cloud:", cloud_total_revenue, "| Local:", local_total_revenue, "\n")

# Row Count Check
cloud_music_count <- dbGetQuery(mysql_con, "
  SELECT COUNT(*) AS count 
  FROM sales_facts 
  WHERE product_type = 'music'
")$count

local_music_count <- nrow(music_data)

cat("Music rows - Cloud:", cloud_music_count, "| Local:", local_music_count, "\n")

cloud_film_count <- dbGetQuery(mysql_con, "
  SELECT COUNT(*) AS count 
  FROM sales_facts 
  WHERE product_type = 'film'
")$count

local_film_count <- nrow(film_data)

cat("Film rows - Cloud:", cloud_film_count, "| Local:", local_film_count, "\n")

# Customers per Country Validation
# Cloud
cloud_customer_country <- dbGetQuery(mysql_con, "
  SELECT d.country_name, COUNT(DISTINCT f.customer_dim_id) AS num_customers
  FROM sales_facts f
  JOIN dim_country d ON f.country_id = d.country_id
  GROUP BY d.country_name
  ORDER BY d.country_name
")

# Local
getCustomerCountryCounts <- function(data) {
  aggregate(customer_id ~ country_name, data = data, FUN = function(x) length(unique(x)))
}

local_film_customers <- getCustomerCountryCounts(film_data)
local_music_customers <- getCustomerCountryCounts(music_data)

local_total_customers <- merge(
  local_film_customers, local_music_customers, 
  by = "country_name", all = TRUE, suffixes = c("_film", "_music")
)

local_total_customers[is.na(local_total_customers)] <- 0
local_total_customers$total_customers <- local_total_customers$customer_id_film + local_total_customers$customer_id_music

# Now match with cloud
cat("\nCustomers by Country - Comparison:\n")
merged <- merge(
  cloud_customer_country, 
  local_total_customers[, c("country_name", "total_customers")], 
  by = "country_name", 
  all = TRUE
)
print(merged)


# Cleanup
dbDisconnect(film_con)
dbDisconnect(music_con)
dbDisconnect(mysql_con)
