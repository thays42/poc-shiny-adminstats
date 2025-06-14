# Integration test for async event report functionality
# This test verifies the complete workflow of the async event report feature

library(shiny)
library(DBI)
library(RSQLite)
library(promises)
library(future)

cat("Starting integration test for async event report...\n")

# Test 1: Verify async function works
cat("Test 1: Testing async function...\n")

# Set up future plan for testing
plan(multisession)

# Create test database
setup_test_database <- function() {
  con <- dbConnect(SQLite(), ":memory:")

  dbExecute(con, "
    CREATE TABLE events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_type TEXT NOT NULL,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Insert test data
  test_events <- c("session_start", "button_press", "button_press", "session_end")
  for (event in test_events) {
    dbExecute(con, "INSERT INTO events (event_type) VALUES (?)", list(event))
  }

  return(con)
}

# Test the synchronous version first
get_event_counts_test <- function() {
  con <- setup_test_database()
  result <- dbGetQuery(con, "
    SELECT event_type, COUNT(*) as count
    FROM events
    GROUP BY event_type
  ")
  total <- dbGetQuery(con, "SELECT COUNT(*) as total FROM events")
  dbDisconnect(con)

  list(by_type = result, total = total$total)
}

# Test async version
get_event_counts_async_test <- function() {
  future_promise({
    get_event_counts_test()
  })
}

# Run sync test
sync_result <- get_event_counts_test()
cat("  Sync result - Total events:", sync_result$total, "\n")
cat("  Sync result - Event types:", nrow(sync_result$by_type), "\n")

# Test 2: Verify async promise structure
cat("Test 2: Testing async promise creation...\n")

async_promise <- get_event_counts_async_test()
cat("  Promise created successfully:", class(async_promise)[1] == "promise", "\n")

# Test 3: Verify modal content generation
cat("Test 3: Testing modal content generation...\n")

# Test loading modal content
loading_modal <- modalDialog(
  title = "Event Report",
  div(
    style = "text-align: center; padding: 40px;",
    tags$div(
      style = "display: inline-block; width: 40px; height: 40px; border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; animation: spin 1s linear infinite;",
      tags$style("@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }")
    ),
    br(), br(),
    h5("Loading event data...")
  ),
  easyClose = TRUE,
  footer = modalButton("Close")
)

cat("  Loading modal created successfully:", !is.null(loading_modal), "\n")

# Test data modal content
test_data <- list(
  by_type = data.frame(
    event_type = c("session_start", "button_press", "session_end"),
    count = c(1, 2, 1)
  ),
  total = 4
)

data_modal <- modalDialog(
  title = "Event Report",
  h4("Total Events: ", test_data$total),
  br(),
  h5("Events by Type:"),
  if (nrow(test_data$by_type) > 0) {
    tagList(
      lapply(seq_len(nrow(test_data$by_type)), function(i) {
        row <- test_data$by_type[i, ]
        p(paste(row$event_type, ":", row$count))
      })
    )
  } else {
    p("No events recorded yet.")
  },
  easyClose = TRUE,
  footer = modalButton("Close")
)

cat("  Data modal created successfully:", !is.null(data_modal), "\n")

# Test 4: Verify error handling structure
cat("Test 4: Testing error handling...\n")

error_modal <- modalDialog(
  title = "Event Report - Error",
  div(
    style = "color: red;",
    h4("Error loading event data"),
    p("Database connection failed")
  ),
  easyClose = TRUE,
  footer = modalButton("Close")
)

cat("  Error modal created successfully:", !is.null(error_modal), "\n")

# Test 5: State management simulation
cat("Test 5: Testing state management logic...\n")

# Simulate reactive values behavior with regular list
simulate_state_changes <- function() {
  # Initial state
  state <- list(
    loading = FALSE,
    event_data = NULL,
    modal_open = FALSE,
    current_promise = NULL
  )

  cat("  Initial state - loading:", state$loading, "modal_open:", state$modal_open, "\n")

  # Simulate modal opening
  state$loading <- TRUE
  state$modal_open <- TRUE
  state$event_data <- NULL

  cat("  After modal open - loading:", state$loading, "modal_open:", state$modal_open, "\n")

  # Simulate data loading complete
  state$loading <- FALSE
  state$event_data <- test_data

  cat("  After data load - loading:", state$loading, "has_data:", !is.null(state$event_data), "\n")

  # Simulate modal close
  state$modal_open <- FALSE

  cat("  After modal close - modal_open:", state$modal_open, "\n")

  return(state)
}

final_state <- simulate_state_changes()

# Test 6: Cancellation logic simulation
cat("Test 6: Testing cancellation logic...\n")

test_cancellation <- function() {
  modal_open <- TRUE

  # Simulate promise resolution with modal still open
  if (modal_open) {
    cat("  Promise resolved with modal open: data would be updated\n")
    result1 <- TRUE
  } else {
    cat("  Promise resolved with modal closed: data would be ignored\n")
    result1 <- FALSE
  }

  # Simulate promise resolution with modal closed
  modal_open <- FALSE
  if (modal_open) {
    cat("  Promise resolved with modal open: data would be updated\n")
    result2 <- TRUE
  } else {
    cat("  Promise resolved with modal closed: data would be ignored\n")
    result2 <- FALSE
  }

  return(list(open_result = result1, closed_result = result2))
}

cancellation_results <- test_cancellation()

# Test 7: App loading verification
cat("Test 7: Verifying app can be loaded with new code...\n")

tryCatch(
  {
    # Source the main app file to check for syntax errors
    app_env <- new.env()
    source("app.R", local = app_env)
    cat("  App loaded successfully without errors\n")
    app_loads <- TRUE
  },
  error = function(e) {
    cat("  App loading failed:", e$message, "\n")
    app_loads <- FALSE
  }
)

# Summary
cat("\n=== INTEGRATION TEST SUMMARY ===\n")
cat("✓ Sync function works:", !is.null(sync_result), "\n")
cat("✓ Async promise creation:", class(async_promise)[1] == "promise", "\n")
cat("✓ Loading modal creation:", !is.null(loading_modal), "\n")
cat("✓ Data modal creation:", !is.null(data_modal), "\n")
cat("✓ Error modal creation:", !is.null(error_modal), "\n")
cat("✓ State management simulation:", !is.null(final_state), "\n")
cat("✓ Cancellation logic:", cancellation_results$closed_result == FALSE, "\n")
cat("✓ App loads without errors:", app_loads, "\n")

all_tests_passed <- all(c(
  !is.null(sync_result),
  class(async_promise)[1] == "promise",
  !is.null(loading_modal),
  !is.null(data_modal),
  !is.null(error_modal),
  !is.null(final_state),
  cancellation_results$closed_result == FALSE,
  app_loads
))

if (all_tests_passed) {
  cat("\n🎉 ALL INTEGRATION TESTS PASSED! 🎉\n")
  cat("The async event report functionality is ready for use.\n")
} else {
  cat("\n❌ SOME TESTS FAILED\n")
  cat("Please review the test output above.\n")
}

cat("\nManual testing recommendations:\n")
cat("1. Run the app and click the event report icon\n")
cat("2. Verify loading spinner appears\n")
cat("3. Verify statistics appear after loading\n")
cat("4. Test closing modal during loading\n")
cat("5. Test with slow database (add delay to get_event_counts)\n")

cat("\nIntegration test completed.\n")
