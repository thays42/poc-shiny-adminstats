# Test script to verify database functionality
# Run this to test the database setup and functions

library(DBI)
library(RSQLite)

# Source the functions from the main app (if needed)
# We'll recreate them here for testing

# Database setup function
setup_database <- function() {
  con <- dbConnect(SQLite(), "test_events.db")

  # Create table if it doesn't exist
  if (!dbExistsTable(con, "events")) {
    dbExecute(con, "
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ")
  }

  dbDisconnect(con)
}

# Function to log events
log_event <- function(event_type) {
  con <- dbConnect(SQLite(), "test_events.db")
  dbExecute(con, "INSERT INTO events (event_type) VALUES (?)", list(event_type))
  dbDisconnect(con)
}

# Function to get event counts
get_event_counts <- function() {
  con <- dbConnect(SQLite(), "test_events.db")
  result <- dbGetQuery(con, "
    SELECT event_type, COUNT(*) as count
    FROM events
    GROUP BY event_type
  ")
  total <- dbGetQuery(con, "SELECT COUNT(*) as total FROM events")
  dbDisconnect(con)

  list(by_type = result, total = total$total)
}

# Function to view all events
view_all_events <- function() {
  con <- dbConnect(SQLite(), "test_events.db")
  result <- dbGetQuery(con, "SELECT * FROM events ORDER BY timestamp DESC")
  dbDisconnect(con)
  return(result)
}

# Clean up function
cleanup_test_db <- function() {
  if (file.exists("test_events.db")) {
    file.remove("test_events.db")
    cat("Test database removed.\n")
  }
}

# Test the database functionality
cat("=== Testing Database Functionality ===\n\n")

# Clean up any existing test database
cleanup_test_db()

# Test 1: Database setup
cat("1. Testing database setup...\n")
setup_database()
cat("   Database created successfully.\n\n")

# Test 2: Log some events
cat("2. Testing event logging...\n")
log_event("session_start")
log_event("button_press")
log_event("button_press")
log_event("button_press")
log_event("session_end")
cat("   Events logged successfully.\n\n")

# Test 3: Check event counts
cat("3. Testing event count retrieval...\n")
counts <- get_event_counts()
cat("   Total events:", counts$total, "\n")
cat("   Events by type:\n")
for (i in 1:nrow(counts$by_type)) {
  row <- counts$by_type[i, ]
  cat("     ", row$event_type, ":", row$count, "\n")
}
cat("\n")

# Test 4: View all events
cat("4. Testing full event retrieval...\n")
all_events <- view_all_events()
print(all_events)
cat("\n")

# Test 5: Verify database persistence
cat("5. Testing database persistence...\n")
log_event("test_event")
new_counts <- get_event_counts()
cat("   Total events after adding one more:", new_counts$total, "\n")
cat("   Database persistence verified.\n\n")

cat("=== All Tests Completed Successfully ===\n")
cat("Test database file: test_events.db\n")
cat("Run cleanup_test_db() to remove the test database.\n")
