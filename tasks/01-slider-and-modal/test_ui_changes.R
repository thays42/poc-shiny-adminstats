# Test script for UI changes
# Run this before and after making changes to verify functionality

library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)

# Test 1: Verify app loads without errors
test_app_loads <- function() {
  cat("Testing app loads without errors...\n")
  tryCatch({
    source("app.R", local = TRUE)
    cat("✓ App source loaded successfully\n")
    return(TRUE)
  }, error = function(e) {
    cat("✗ App failed to load:", e$message, "\n")
    return(FALSE)
  })
}

# Test 2: Verify UI structure contains expected elements
test_ui_structure <- function() {
  cat("Testing UI structure...\n")
  source("app.R", local = TRUE)

  # Check if UI is defined
  if (!exists("ui")) {
    cat("✗ UI object not found\n")
    return(FALSE)
  }

  # Convert UI to HTML to inspect structure
  ui_html <- as.character(ui)

  # Expected elements in new UI
  expected_elements <- list(
    navbar = "navbar",
    title = "tool",
    main_panel = "main",
    usage_menu = "Usage",
    sample_slider = "sample_size",
    generate_button = "Generate Histogram"
  )

  results <- list()
  for (element_name in names(expected_elements)) {
    pattern <- expected_elements[[element_name]]
    found <- grepl(pattern, ui_html, ignore.case = TRUE)
    results[[element_name]] <- found

    if (found) {
      cat("✓", element_name, "found\n")
    } else {
      cat("✗", element_name, "not found\n")
    }
  }

  all_found <- all(unlist(results))
  return(all_found)
}

# Test 3: Verify server function handles expected inputs
test_server_inputs <- function() {
  cat("Testing server function...\n")
  source("app.R", local = TRUE)

  if (!exists("server")) {
    cat("✗ Server function not found\n")
    return(FALSE)
  }

  # Check if server function accepts input, output, session parameters
  server_args <- names(formals(server))
  expected_args <- c("input", "output", "session")

  missing_args <- setdiff(expected_args, server_args)
  if (length(missing_args) > 0) {
    cat("✗ Server missing arguments:", paste(missing_args, collapse = ", "), "\n")
    return(FALSE)
  }

  cat("✓ Server function has correct parameters\n")
  return(TRUE)
}

# Test 4: Verify database functions still work
test_database_functions <- function() {
  cat("Testing database functions...\n")
  source("app.R", local = TRUE)

  # Test database setup
  tryCatch({
    setup_database()
    cat("✓ Database setup works\n")
  }, error = function(e) {
    cat("✗ Database setup failed:", e$message, "\n")
    return(FALSE)
  })

  # Test event logging
  tryCatch({
    log_event("test_event")
    cat("✓ Event logging works\n")
  }, error = function(e) {
    cat("✗ Event logging failed:", e$message, "\n")
    return(FALSE)
  })

  # Test event counting
  tryCatch({
    counts <- get_event_counts()
    if (is.list(counts) && "total" %in% names(counts) && "by_type" %in% names(counts)) {
      cat("✓ Event counting works\n")
    } else {
      cat("✗ Event counting returned unexpected format\n")
      return(FALSE)
    }
  }, error = function(e) {
    cat("✗ Event counting failed:", e$message, "\n")
    return(FALSE)
  })

  return(TRUE)
}

# Test 5: Verify app can run (syntax check)
test_app_syntax <- function() {
  cat("Testing app syntax...\n")
  tryCatch({
    source("app.R", local = TRUE)
    # Try to create the app object
    app <- shinyApp(ui = ui, server = server)
    if (inherits(app, "shiny.appobj")) {
      cat("✓ App object created successfully\n")
      return(TRUE)
    } else {
      cat("✗ App object creation failed\n")
      return(FALSE)
    }
  }, error = function(e) {
    cat("✗ App syntax error:", e$message, "\n")
    return(FALSE)
  })
}

# Run all tests
run_all_tests <- function() {
  cat("=== Running UI Change Tests ===\n\n")

  tests <- list(
    "App Loads" = test_app_loads,
    "UI Structure" = test_ui_structure,
    "Server Inputs" = test_server_inputs,
    "Database Functions" = test_database_functions,
    "App Syntax" = test_app_syntax
  )

  results <- list()
  for (test_name in names(tests)) {
    cat("\n--- Testing:", test_name, "---\n")
    results[[test_name]] <- tests[[test_name]]()
  }

  cat("\n=== Test Summary ===\n")
  for (test_name in names(results)) {
    status <- if (results[[test_name]]) "PASS" else "FAIL"
    cat(test_name, ":", status, "\n")
  }

  all_passed <- all(unlist(results))
  cat("\nOverall:", if (all_passed) "ALL TESTS PASSED" else "SOME TESTS FAILED", "\n")

  return(all_passed)
}

# Cleanup function for test database
cleanup_test_files <- function() {
  test_files <- c("events.db", "test_events.db")
  for (file in test_files) {
    if (file.exists(file)) {
      file.remove(file)
      cat("Removed test file:", file, "\n")
    }
  }
}

# Main execution
if (!interactive()) {
  run_all_tests()
}
