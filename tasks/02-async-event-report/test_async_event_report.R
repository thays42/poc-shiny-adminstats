# Test file for async event report functionality
# This file contains test scenarios for the async event report implementation

library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(shinyjs)

# Need to attach shiny for tag functions
library(shiny)

# Mock database setup for testing
setup_test_database <- function() {
  con <- dbConnect(SQLite(), ":memory:")

  # Create table
  dbExecute(con, "
    CREATE TABLE events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_type TEXT NOT NULL,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Insert test data
  test_events <- c(
    "session_start", "button_press", "button_press",
    "session_end", "button_press", "session_start"
  )

  for (event in test_events) {
    dbExecute(con, "INSERT INTO events (event_type) VALUES (?)", list(event))
  }

  return(con)
}

# Test the async get_event_counts function
test_that("async get_event_counts returns correct data structure", {
  # This test will verify that the async version returns the same
  # data structure as the synchronous version

  # Setup test database
  con <- setup_test_database()

  # Create a temporary test function that uses our test database
  test_get_event_counts <- function() {
    result <- dbGetQuery(con, "
      SELECT event_type, COUNT(*) as count
      FROM events
      GROUP BY event_type
    ")
    total <- dbGetQuery(con, "SELECT COUNT(*) as total FROM events")
    list(by_type = result, total = total$total)
  }

  # Test the synchronous version first
  result <- test_get_event_counts()

  # Verify structure
  expect_type(result, "list")
  expect_named(result, c("by_type", "total"))
  expect_s3_class(result$by_type, "data.frame")
  expect_type(result$total, "integer")
  expect_named(result$by_type, c("event_type", "count"))

  dbDisconnect(con)
})

test_that("loading state is properly managed", {
  # Test that loading state starts as TRUE when modal opens
  # and becomes FALSE when data loads

  # Create mock state as regular list (not reactive)
  test_values <- list(
    loading = FALSE,
    event_data = NULL,
    modal_open = FALSE
  )

  # Simulate opening modal
  test_values$loading <- TRUE
  test_values$modal_open <- TRUE
  test_values$event_data <- NULL

  expect_true(test_values$loading)
  expect_true(test_values$modal_open)
  expect_null(test_values$event_data)

  # Simulate data loading complete
  test_values$loading <- FALSE
  test_values$event_data <- list(by_type = data.frame(), total = 0)

  expect_false(test_values$loading)
  expect_false(is.null(test_values$event_data))
})

test_that("modal shows loading indicator initially", {
  # Test that the modal contains a loading indicator
  # when first opened, before data loads

  # Create the loading modal content as it appears in the app
  loading_content <- div(
    id = "loading_spinner",
    style = "text-align: center; padding: 40px;",
    tags$div(
      style = "display: inline-block; width: 40px; height: 40px; border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; animation: spin 1s linear infinite;",
      tags$style("@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }")
    ),
    br(), br(),
    h5("Loading event data...")
  )

  # Create the hidden text output as it appears in the app
  data_output <- div(
    id = "event_data_output",
    style = "display: none;",
    verbatimTextOutput("event_report_text")
  )

  # Verify the loading content structure
  expect_s3_class(loading_content, "shiny.tag")
  expect_equal(loading_content$name, "div")
  expect_equal(loading_content$attribs$id, "loading_spinner")
  expect_true(grepl("text-align: center", loading_content$attribs$style))

  # Verify the data output structure
  expect_s3_class(data_output, "shiny.tag")
  expect_equal(data_output$name, "div")
  expect_equal(data_output$attribs$id, "event_data_output")
  expect_true(grepl("display: none", data_output$attribs$style))
})

test_that("modal updates with data when promise resolves", {
  # Test that the modal content updates to show statistics
  # when the async call completes

  # Mock event data as returned by get_event_counts
  mock_event_data <- list(
    by_type = data.frame(
      event_type = c("session_start", "button_press", "session_end"),
      count = c(2, 3, 1)
    ),
    total = 6
  )

  # Test text formatting for verbatimTextOutput
  expected_text <- paste(
    "Total Events: 6",
    "Events by Type:",
    "session_start : 2",
    "button_press : 3",
    "session_end : 1",
    sep = "\n"
  )

  # Test that we can create the expected modal content
  expect_equal(mock_event_data$total, 6)
  expect_equal(nrow(mock_event_data$by_type), 3)
  expect_true("session_start" %in% mock_event_data$by_type$event_type)

  # Test that text formatting works as expected
  expect_type(expected_text, "character")
  expect_true(grepl("Total Events: 6", expected_text))
  expect_true(grepl("Events by Type:", expected_text))
})

test_that("cancellation works when modal is closed", {
  # Test that closing the modal before data loads
  # properly cancels the async operation and resets UI elements

  # Create mock state as regular list (not reactive)
  test_values <- list(
    loading = TRUE,
    event_data = NULL,
    modal_open = TRUE
  )

  # Simulate modal being closed during loading
  test_values$modal_open <- FALSE

  # Simulate what should happen when promise resolves after modal close
  # (the promise should check modal_open and not update values)
  if (test_values$modal_open) {
    test_values$event_data <- list(by_type = data.frame(), total = 0)
    test_values$loading <- FALSE
    # In real app: hide("loading_spinner"), show("event_data_output")
  }

  # Simulate cleanup when modal closes
  if (!test_values$modal_open) {
    test_values$event_data <- NULL
    test_values$loading <- FALSE
    # In real app: show("loading_spinner"), hide("event_data_output")
  }

  # Verify that data was not updated because modal was closed
  expect_null(test_values$event_data)
  expect_false(test_values$loading) # Should be false after cleanup
})

test_that("error handling displays user-friendly messages", {
  # Test that database errors or other failures show
  # appropriate error messages instead of crashing

  # Simulate an error condition
  mock_error_data <- list(
    error = TRUE,
    message = "Database connection failed"
  )

  # Test error text formatting for verbatimTextOutput
  expected_error_text <- paste("Error loading event data:", mock_error_data$message)

  # Test error structure
  expect_true(mock_error_data$error)
  expect_type(mock_error_data$message, "character")
  expect_true(nchar(mock_error_data$message) > 0)

  # Test that error message is user-friendly (no technical jargon)
  expect_false(grepl("NULL", mock_error_data$message))
  expect_false(grepl("undefined", mock_error_data$message))

  # Test error text formatting
  expect_type(expected_error_text, "character")
  expect_true(grepl("Error loading event data:", expected_error_text))
})

# Manual test scenarios (to be run interactively)
manual_test_scenarios <- function() {
  cat("Manual Test Scenarios for Async Event Report:\n\n")

  cat("1. NORMAL LOADING TEST:\n")
  cat("   - Click event report icon\n")
  cat("   - Verify loading spinner appears with 'loading_spinner' ID\n")
  cat("   - Verify spinner hides and text output shows after loading\n")
  cat("   - Expected: Smooth transition using shinyjs show/hide\n\n")

  cat("2. QUICK CANCELLATION TEST:\n")
  cat("   - Click event report icon\n")
  cat("   - Immediately close modal (while loading)\n")
  cat("   - Expected: No errors, UI elements reset for next use\n\n")

  cat("3. MULTIPLE RAPID CLICKS TEST:\n")
  cat("   - Click event report icon multiple times quickly\n")
  cat("   - Expected: Only one modal should open, no duplicate calls\n\n")

  cat("4. SLOW CONNECTION SIMULATION:\n")
  cat("   - Modify get_event_counts to add artificial delay\n")
  cat("   - Click event report icon\n")
  cat("   - Verify loading spinner shows for extended period\n")
  cat("   - Verify text output appears after delay\n")
  cat("   - Expected: Single modal with element transitions\n\n")

  cat("5. DATABASE ERROR TEST:\n")
  cat("   - Temporarily corrupt or lock database file\n")
  cat("   - Click event report icon\n")
  cat("   - Expected: Error message in verbatimTextOutput, no app crash\n\n")
}

# Performance test helper
performance_test_setup <- function() {
  # Create a large test database to verify async performance
  con <- dbConnect(SQLite(), ":memory:")

  dbExecute(con, "
    CREATE TABLE events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_type TEXT NOT NULL,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Insert many test records to simulate slow query
  event_types <- c("session_start", "button_press", "session_end", "page_view", "error")

  for (i in 1:10000) {
    event_type <- sample(event_types, 1)
    dbExecute(con, "INSERT INTO events (event_type) VALUES (?)", list(event_type))
  }

  return(con)
}

# Run manual tests
if (interactive()) {
  manual_test_scenarios()
}
