# ----------------------------------------------------
# configBusinessLogic.PractI.LastNameF.R
# Part H / Add Business Logic
# Rohini Machavolu
# Spring 2025
# ----------------------------------------------------

# Load necessary libraries
library(DBI)
library(RMySQL)

# Establish the database connection
con <- dbConnect(
  RMySQL::MySQL(),
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD"),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST"),
  port = as.integer(Sys.getenv("DB_PORT"))
)
dbExecute(con, "DROP PROCEDURE IF EXISTS storeVisit;")
dbExecute(con, "DROP PROCEDURE IF EXISTS storeNewVisit;")

# Part H.2
# SQL to create storeVisit stored procedure
storeVisit_procedure <- "CREATE PROCEDURE storeVisit(
    IN p_restaurant_id INT,
    IN p_server_emp_id INT,
    IN p_customer_id INT,
    IN p_visit_date DATE,
    IN p_visit_time TIME,
    IN p_party_size INT,
    IN p_food_bill DECIMAL(10,2),
    IN p_alcohol_bill DECIMAL(10,2),
    IN p_tip_amount DECIMAL(10,2),
    IN p_wait_time INT,
    IN p_meal_type_id INT,
    IN p_payment_method_id INT,
    IN p_ordered_alcohol BOOLEAN
)
BEGIN
    -- Insert a new visit into the Visit table
    INSERT INTO Visit (
        RestaurantID, ServerEmpID, CustomerID, VisitDate, VisitTime, 
        PartySize, WaitTime, FoodBill, TipAmount, PaymentMethodID, 
        OrderedAlcohol, AlcoholBill, MealTypeID
    )
    VALUES (
        p_restaurant_id, p_server_emp_id, p_customer_id, p_visit_date, p_visit_time,
        p_party_size, p_wait_time, p_food_bill, p_tip_amount, p_payment_method_id,
        p_ordered_alcohol, p_alcohol_bill, p_meal_type_id
    );
END"

# Part H.3
# SQL to create storeNewVisit stored procedure
storeNewVisit_procedure <- "
CREATE PROCEDURE storeNewVisit(
    IN p_restaurant_name VARCHAR(255),
    IN p_server_emp_id INT,
    IN p_customer_name VARCHAR(255),
    IN p_customer_phone VARCHAR(20),
    IN p_customer_email VARCHAR(255),
    IN p_visit_date DATE,
    IN p_visit_time TIME,
    IN p_party_size INT,
    IN p_food_bill DECIMAL(10,2),
    IN p_alcohol_bill DECIMAL(10,2),
    IN p_tip_amount DECIMAL(10,2),
    IN p_wait_time INT,
    IN p_meal_type VARCHAR(50),
    IN p_genders VARCHAR(255),
    IN p_payment_method_name VARCHAR(50),
    IN p_ordered_alcohol BOOLEAN
)
BEGIN
    -- Declare variables at the beginning of the procedure
    DECLARE v_restaurant_id INT;
    DECLARE v_customer_id INT;
    DECLARE v_payment_method_id INT;
    DECLARE v_meal_type_id INT;
    DECLARE v_server_exists INT;

    -- Check if the restaurant exists
    SET v_restaurant_id = (SELECT RestaurantID FROM Restaurant WHERE RestaurantName = p_restaurant_name LIMIT 1);

    IF v_restaurant_id IS NULL THEN
        -- Insert restaurant if not exists
        INSERT INTO Restaurant (RestaurantName) VALUES (p_restaurant_name);
        SET v_restaurant_id = LAST_INSERT_ID();
    END IF;

    -- Check if the customer exists
    SET v_customer_id = (SELECT CustomerID FROM Customer WHERE CustomerName = p_customer_name LIMIT 1);

    IF v_customer_id IS NULL THEN
        -- Insert customer if not exists
        INSERT INTO Customer (CustomerName, CustomerPhone, CustomerEmail) 
        VALUES (p_customer_name, p_customer_phone, p_customer_email);
        SET v_customer_id = LAST_INSERT_ID();
    END IF;

    -- Check if the payment method exists, otherwise set default
    IF p_payment_method_name IS NULL OR p_payment_method_name = '' THEN
        SET v_payment_method_id = 2;  -- Default payment method ID
    ELSE
        SET v_payment_method_id = (SELECT PaymentMethodID FROM PaymentMethod WHERE PaymentMethodName = p_payment_method_name LIMIT 1);

        IF v_payment_method_id IS NULL THEN
            -- Insert payment method if not exists
            INSERT INTO PaymentMethod (PaymentMethodName) VALUES (p_payment_method_name);
            SET v_payment_method_id = LAST_INSERT_ID();
        END IF;
    END IF;

    -- Check if the meal type exists, otherwise set default
    IF p_meal_type IS NULL OR p_meal_type = '' THEN
        SET v_meal_type_id = 1;  -- Default meal type ID
    ELSE
        SET v_meal_type_id = (SELECT MealTypeID FROM MealType WHERE MealTypeName = p_meal_type LIMIT 1);

        IF v_meal_type_id IS NULL THEN
            -- Insert meal type if not exists
            INSERT INTO MealType (MealTypeName) VALUES (p_meal_type);
            SET v_meal_type_id = LAST_INSERT_ID();
        END IF;
    END IF;

   -- Check if the server exists
SET v_server_exists = (SELECT COUNT(*) FROM Server WHERE ServerEmpID = p_server_emp_id);

IF v_server_exists = 0 THEN
    -- Insert new server if not exists
    INSERT INTO Server (ServerEmpID) VALUES (p_server_emp_id);
END IF;

    -- Insert into Visit table with proper references
    INSERT INTO Visit (
        RestaurantID, ServerEmpID, CustomerID, VisitDate, VisitTime, 
        PartySize, WaitTime, FoodBill, TipAmount, PaymentMethodID, 
        OrderedAlcohol, AlcoholBill, MealTypeID, Genders
    )
    VALUES (
        v_restaurant_id, p_server_emp_id, v_customer_id, p_visit_date, p_visit_time,
        p_party_size, p_wait_time, p_food_bill, p_tip_amount, v_payment_method_id,
        p_ordered_alcohol, p_alcohol_bill, v_meal_type_id , p_genders
    );
END;
"

# Execute the queries to create the procedures
dbExecute(con, storeNewVisit_procedure)
dbExecute(con, storeVisit_procedure)


# Function to execute queries and handle errors
execute_query <- function(query) {
  tryCatch({
    dbExecute(con, query)
    message("Query executed successfully")
  }, error = function(e) {
    message("Error executing query: ", e)
  })
}


# Test the procedures
storeNewVisitquery <- "CALL storeNewVisit(
    'lol',  -- Restaurant name
    001,             -- Server employee ID
    'lol',      -- Customer name
    '123-456-7890',  -- Customer phone
    'lol@email.com', -- Customer email
    '2025-03-11',    -- Visit date
    '19:30:00',      -- Visit time
    4,               -- Party size
    50.00,           -- Food bill
    20.00,           -- Alcohol bill
    10.00,           -- Tip amount
    30,              -- Wait time in minutes
    'lol',     -- Meal type (empty, default to 1)
    'mmmf',          -- Gender
    NULL,            -- Payment method (empty, default to 2)
    TRUE             -- Ordered alcohol
);
"
storeVisitquery <- "CALL storeVisit(
    1,                -- Restaurant ID
    1843,              -- Server employee ID
    2,              -- Customer ID
    '2025-03-11',     -- Visit date
    '19:30:00',       -- Visit time
    4,                -- Party size
    100.00,           -- Food bill
    40.00,            -- Alcohol bill
    15.00,            -- Tip amount
    25,               -- Wait time in minutes
    1,                -- Meal type ID (assuming default)
    2,                -- Payment method ID (assuming default)
    TRUE              -- Ordered alcohol
);"
suppressWarnings({
  # Your code here

execute_query(storeNewVisitquery)
execute_query(storeVisitquery)

# Checking if the rows inserted by the stored procedure were successfully added
last_rows <- dbGetQuery(con, "SELECT * FROM Visit ORDER BY VisitDate DESC LIMIT 3")
print(last_rows)
})
# Close the database connection when done
dbDisconnect(con)
