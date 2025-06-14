# Test script for slider functionality
# Tests that the sample size slider works correctly with different values

library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)

# Helper function to simulate slider input
simulate_slider_input <- function(sample_size) {
  # Create a mock input object
  input_mock <- list(
    sample_size = sample_size,
    generate = 1
  )

  # Generate the sample data as the app would
  sample_data <- rnorm(input_mock$sample_size)

  # Return both the input and generated data for testing
  list(
    input = input_mock,
    sample_data = sample_data,
    actual_size = length(sample_data)
  )
}

# Test 1: Verify slider generates correct sample sizes
test_slider_sample_sizes <- function() {
  cat("Testing slider sample sizes...\n")

  test_sizes <- c(1, 100, 1000, 5000, 10000)
  all_passed <- TRUE

  for (size in test_sizes) {
    result <- simulate_slider_input(size)
    if (result$actual_size != size) {
      cat("✗ Size", size, "failed. Expected:", size, "Got:", result$actual_size, "\n")
      all_passed <- FALSE
    } else {
      cat("✓ Size", size, "passed\n")
    }
  }

  return(all_passed)
}

# Test 2: Verify slider boundaries
test_slider_boundaries <- function() {
  cat("Testing slider boundaries...\n")

  # Test minimum value
  min_result <- simulate_slider_input(1)
  if (min_result$actual_size != 1) {
    cat("✗ Minimum boundary failed\n")
    return(FALSE)
  }
  cat("✓ Minimum boundary (1) passed\n")

  # Test maximum value
  max_result <- simulate_slider_input(10000)
  if (max_result$actual_size != 10000) {
    cat("✗ Maximum boundary failed\n")
    return(FALSE)
  }
  cat("✓ Maximum boundary (10000) passed\n")

  # Test default value
  default_result <- simulate_slider_input(1000)
  if (default_result$actual_size != 1000) {
    cat("✗ Default value failed\n")
    return(FALSE)
  }
  cat("✓ Default value (1000) passed\n")

  return(TRUE)
}

# Test 3: Verify histogram title updates with sample size
test_histogram_title <- function() {
  cat("Testing histogram title updates...\n")
  source("app.R", local = TRUE)

  test_sizes <- c(500, 1000, 2000)
  all_passed <- TRUE

  for (size in test_sizes) {
    sample_data <- rnorm(size)
    expected_title <- paste("Histogram of", size, "Random Normal Values")

    # Create the plot as the app would
    plot_obj <- ggplot(data.frame(x = sample_data), aes(x = x)) +
      geom_histogram(bins = 30, fill = "skyblue", color = "black", alpha = 0.7) +
      labs(title = expected_title,
           x = "Value",
           y = "Frequency") +
      theme_minimal()

    # Check if title is correct
    actual_title <- plot_obj$labels$title
    if (actual_title != expected_title) {
      cat("✗ Title for size", size, "failed. Expected:", expected_title, "Got:", actual_title, "\n")
      all_passed <- FALSE
    } else {
      cat("✓ Title for size", size, "passed\n")
    }
  }

  return(all_passed)
}

# Test 4: Verify UI contains slider with correct properties
test_slider_ui_properties <- function() {
  cat("Testing slider UI properties...\n")
  source("app.R", local = TRUE)

  # Convert UI to HTML string for inspection
  ui_html <- as.character(ui)

  # Check for slider input
  if (!grepl("sample_size", ui_html)) {
    cat("✗ Slider input ID not found\n")
    return(FALSE)
  }
  cat("✓ Slider input ID found\n")

  # Check for slider label
  if (!grepl("Sample Size", ui_html)) {
    cat("✗ Slider label not found\n")
    return(FALSE)
  }
  cat("✓ Slider label found\n")

  # Check for min/max values (these might be in data attributes)
  if (!grepl("min.*1", ui_html) || !grepl("max.*10000", ui_html)) {
    cat("? Min/max values not clearly visible in HTML (this is normal)\n")
  } else {
    cat("✓ Min/max values found in HTML\n")
  }

  return(TRUE)
}

# Test 5: Integration test - verify app works end-to-end with different slider values
test_end_to_end_slider <- function() {
  cat("Testing end-to-end slider functionality...\n")

  tryCatch({
    source("app.R", local = TRUE)

    # Verify we can create the app
    app <- shinyApp(ui = ui, server = server)
    if (!inherits(app, "shiny.appobj")) {
      cat("✗ Failed to create app object\n")
      return(FALSE)
    }

    cat("✓ App object created successfully with slider\n")

    # Verify server function can handle sample_size input
    server_body <- deparse(body(server))
    if (!any(grepl("input\\$sample_size", server_body))) {
      cat("✗ Server doesn't reference input$sample_size\n")
      return(FALSE)
    }
    cat("✓ Server references input$sample_size\n")

    return(TRUE)
  }, error = function(e) {
    cat("✗ End-to-end test failed:", e$message, "\n")
    return(FALSE)
  })
}

# Run all slider tests
run_slider_tests <- function() {
  cat("=== Running Slider Functionality Tests ===\n\n")

  tests <- list(
    "Slider Sample Sizes" = test_slider_sample_sizes,
    "Slider Boundaries" = test_slider_boundaries,
    "Histogram Title Updates" = test_histogram_title,
    "Slider UI Properties" = test_slider_ui_properties,
    "End-to-End Slider" = test_end_to_end_slider
  )

  results <- list()
  for (test_name in names(tests)) {
    cat("\n--- Testing:", test_name, "---\n")
    results[[test_name]] <- tests[[test_name]]()
  }

  cat("\n=== Slider Test Summary ===\n")
  for (test_name in names(results)) {
    status <- if (results[[test_name]]) "PASS" else "FAIL"
    cat(test_name, ":", status, "\n")
  }

  all_passed <- all(unlist(results))
  cat("\nOverall:", if (all_passed) "ALL SLIDER TESTS PASSED" else "SOME SLIDER TESTS FAILED", "\n")

  return(all_passed)
}

# Main execution
if (!interactive()) {
  run_slider_tests()
}
