#!/usr/bin/env Rscript

# Simple script to run the Shiny application
# Usage: Rscript run_app.R [port]
# Default port is 3838

# Load required libraries
cat("Loading Shiny application...\n")

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) > 0) as.numeric(args[1]) else 3838

# Check if port is valid
if (is.na(port) || port < 1024 || port > 65535) {
  cat("Invalid port number. Using default port 3838.\n")
  port <- 3838
}

cat(paste("Starting Shiny app on port", port, "...\n"))
cat("Press Ctrl+C to stop the application.\n")
cat("The app will open in your default web browser.\n\n")

# Load shiny and run the app
library(shiny)
runApp("app.R", host = "0.0.0.0", port = port, launch.browser = TRUE)
