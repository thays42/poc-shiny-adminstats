# Test script for nav_item functionality
# Tests that the Event Report nav_item works correctly without affecting tab navigation

library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)

# Test 1: Verify nav_item exists in UI
test_nav_item_exists <- function() {
  cat("Testing nav_item exists...\n")
  source("app.R", local = TRUE)

  # Convert UI to HTML to inspect structure
  ui_html <- as.character(ui)

  # Check for nav_item or action link
  if (grepl("Event Report", ui_html) && !grepl("tabPanel.*Event Report", ui_html)) {
    cat("✓ Event Report appears to be nav_item (not tabPanel)\n")
    return(TRUE)
  } else if (grepl("tabPanel.*Event Report", ui_html)) {
    cat("✗ Event Report is still a tabPanel\n")
    return(FALSE)
  } else {
    cat("✗ Event Report not found\n")
    return(FALSE)
  }
}

# Test 2: Verify nav_item doesn't create a tab
test_no_tab_creation <- function() {
  cat("Testing nav_item doesn't create tab...\n")
  source("app.R", local = TRUE)

  ui_html <- as.character(ui)

  # Check that there's no tab content for Event Report
  if (!grepl("tab-pane.*usage_report", ui_html) && !grepl("data-value.*usage_report", ui_html)) {
    cat("✓ No tab content created for Event Report\n")
    return(TRUE)
  } else {
    cat("✗ Tab content still exists for Event Report\n")
    return(FALSE)
  }
}

# Test 3: Verify modal trigger still works
test_modal_trigger <- function() {
  cat("Testing modal trigger functionality...\n")
  source("app.R", local = TRUE)

  # Check server function has modal trigger logic
  server_body <- deparse(body(server))
  if (any(grepl("show_report_nav", server_body)) || any(grepl("observeEvent.*input\\$show_report", server_body))) {
    cat("✓ Modal trigger logic found in server\n")
    return(TRUE)
  } else {
    cat("✗ Modal trigger logic not found\n")
    return(FALSE)
  }
}

# Test 4: Verify Event Report link structure
test_event_report_link_structure <- function() {
  cat("Testing Event Report link structure...\n")
  source("app.R", local = TRUE)

  ui_html <- as.character(ui)

  # Check for Event Report link
  if (!grepl("Event Report", ui_html)) {
    cat("✗ Event Report link not found\n")
    return(FALSE)
  }
  cat("✓ Event Report link found\n")

  # Check that it's not in a tabPanel
  if (grepl("tabPanel.*Event Report", ui_html)) {
    cat("✗ Event Report is still in a tabPanel\n")
    return(FALSE)
  }
  cat("✓ Event Report is not in tabPanel\n")

  # Check for onclick handler
  if (!grepl("onclick.*show_report_nav", ui_html)) {
    cat("✗ Event Report onclick handler not found\n")
    return(FALSE)
  }
  cat("✓ Event Report onclick handler found\n")

  return(TRUE)
}

# Test 5: Verify app still loads and works
test_app_functionality <- function() {
  cat("Testing overall app functionality...\n")

  tryCatch({
    source("app.R", local = TRUE)

    # Try to create the app object
    app <- shinyApp(ui = ui, server = server)
    if (!inherits(app, "shiny.appobj")) {
      cat("✗ App object creation failed\n")
      return(FALSE)
    }
    cat("✓ App object created successfully\n")

    # Check that main functionality is preserved
    ui_html <- as.character(ui)
    if (!grepl("sample_size", ui_html)) {
      cat("✗ Sample size slider missing\n")
      return(FALSE)
    }
    cat("✓ Sample size slider preserved\n")

    if (!grepl("Generate Histogram", ui_html)) {
      cat("✗ Generate button missing\n")
      return(FALSE)
    }
    cat("✓ Generate button preserved\n")

    return(TRUE)
  }, error = function(e) {
    cat("✗ App functionality test failed:", e$message, "\n")
    return(FALSE)
  })
}

# Test 6: Verify database functions still work
test_database_integration <- function() {
  cat("Testing database integration...\n")
  source("app.R", local = TRUE)

  # Test that get_event_counts function exists and works
  tryCatch({
    # Setup database first
    setup_database()
    log_event("test_nav_item")
    counts <- get_event_counts()

    if (is.list(counts) && "total" %in% names(counts)) {
      cat("✓ Database functions working\n")
      return(TRUE)
    } else {
      cat("✗ Database functions not working properly\n")
      return(FALSE)
    }
  }, error = function(e) {
    cat("✗ Database integration failed:", e$message, "\n")
    return(FALSE)
  })
}

# Test 7: Check for correct input handling in server
test_server_input_handling <- function() {
  cat("Testing server input handling...\n")
  source("app.R", local = TRUE)

  server_body <- deparse(body(server))

  # Check for event report trigger
  if (!any(grepl("show_report", server_body))) {
    cat("✗ No event report trigger found in server\n")
    return(FALSE)
  }
  cat("✓ Event report trigger found\n")

  # Check for modal dialog
  if (!any(grepl("showModal", server_body))) {
    cat("✗ Modal dialog logic not found\n")
    return(FALSE)
  }
  cat("✓ Modal dialog logic found\n")

  return(TRUE)
}

# Run all nav_item tests
run_nav_item_tests <- function() {
  cat("=== Testing Nav Item Functionality ===\n\n")

  tests <- list(
    "Nav Item Exists" = test_nav_item_exists,
    "No Tab Creation" = test_no_tab_creation,
    "Modal Trigger" = test_modal_trigger,
    "Event Report Link Structure" = test_event_report_link_structure,
    "App Functionality" = test_app_functionality,
    "Database Integration" = test_database_integration,
    "Server Input Handling" = test_server_input_handling
  )

  results <- list()
  for (test_name in names(tests)) {
    cat("\n--- Testing:", test_name, "---\n")
    results[[test_name]] <- tests[[test_name]]()
  }

  cat("\n=== Nav Item Test Summary ===\n")
  for (test_name in names(results)) {
    status <- if (results[[test_name]]) "PASS" else "FAIL"
    cat(test_name, ":", status, "\n")
  }

  all_passed <- all(unlist(results))
  cat("\nOverall:", if (all_passed) "ALL NAV ITEM TESTS PASSED" else "SOME NAV ITEM TESTS FAILED", "\n")

  return(all_passed)
}

# Cleanup function
cleanup_nav_test <- function() {
  if (file.exists("events.db")) {
    file.remove("events.db")
    cat("Cleaned up test database\n")
  }
}

# Main execution
if (!interactive()) {
  run_nav_item_tests()
}
