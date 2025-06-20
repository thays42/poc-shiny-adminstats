# Shiny Reporting Page

A simple R Shiny application that generates random histograms with configurable sample sizes and logs events to a SQLite database.

## Features

- **Random Histogram Generation**: Click the "Generate Histogram" button to create a histogram of random samples from a normal distribution
- **Configurable Sample Size**: Use the slider to select sample sizes from 1 to 10,000 (default: 1,000)
- **Modern UI**: Clean navbar interface with the application title "tool" and main panel
- **Event Logging**: The application automatically logs events to a SQLite database:
  - Session start (when the app loads)
  - Button press (when the histogram generation button is clicked)
  - Session end (when the user closes the app)
- **Event Reporting**: Click "Event Report" in the navigation bar to view a modal with statistics about logged events

## Prerequisites

- R (version 4.5.0 or later)
- RStudio (recommended but not required)

## Installation

1. Clone or download this project
2. Open R or RStudio and navigate to the project directory
3. Install renv if you haven't already:
   ```r
   install.packages("renv")
   ```
4. Restore the project dependencies:
   ```r
   renv::restore()
   ```

## Required Packages

The application uses the following R packages (automatically managed by renv):

- `shiny` - Web application framework
- `DBI` - Database interface
- `RSQLite` - SQLite database driver
- `ggplot2` - Data visualization

## Usage

### Running the Application

1. Open R or RStudio in the project directory
2. Run the following command:
   ```r
   shiny::runApp("app.R")
   ```
3. The application will open in your default web browser

### Application Interface

- **Navigation Bar**: Features the application title "tool" and an "Event Report" link for accessing reports
- **Sample Size Slider**: Controls the number of random samples (1 to 10,000, default 1,000)
- **Generate Histogram Button**: Creates a new histogram with the selected number of random normal values
- **Event Report Link**: Click to open a modal displaying event statistics from the database
- **Histogram Display**: Shows the generated histogram in the main panel with dynamic title showing sample size
- **Responsive Layout**: Controls are arranged below the plot for optimal viewing on different screen sizes

### Database

The application creates a SQLite database file named `events.db` in the project directory. This database contains:

- **events table** with columns:
  - `id`: Auto-incrementing primary key
  - `event_type`: Type of event (session_start, button_press, session_end)
  - `timestamp`: When the event occurred (automatically set)

## File Structure

```
shiny-reporting-page/
├── app.R                      # Main Shiny application file
├── events.db                  # SQLite database (created automatically)
├── task.md                    # Development task tracking
├── test_ui_changes.R          # UI functionality tests
├── test_slider_functionality.R # Slider-specific tests
├── test_db.R                  # Database functionality tests
├── run_app.R                  # Helper script to run the application
├── README.md                  # This file
├── .Rprofile                  # R environment configuration
├── renv.lock                  # Package dependency lockfile
└── renv/                      # renv package cache directory
```

## Development Environment

This project uses `renv` for package management to ensure reproducible environments. The `renv.lock` file contains all package versions used in development.

## Event Types

The application tracks three types of events:

1. **session_start**: Logged when a user starts a new session
2. **button_press**: Logged each time the "Generate Histogram" button is clicked
3. **session_end**: Logged when a user's session ends

## Database Schema

```sql
CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_type TEXT NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Troubleshooting

### Common Issues

1. **Package Installation Errors**: Make sure you have the latest version of R and try running `renv::restore()` again
2. **Database Permission Errors**: Ensure the application has write permissions in the project directory
3. **Port Already in Use**: If you get a port error, try specifying a different port:
   ```r
   shiny::runApp("app.R", port = 8080)
   ```

### Viewing Database Contents

To manually inspect the database, you can use:

```r
library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "events.db")
dbGetQuery(con, "SELECT * FROM events ORDER BY timestamp DESC")
dbDisconnect(con)
```

### Running Tests

The application includes comprehensive test suites:

```r
# Test overall UI functionality
source("test_ui_changes.R")
run_all_tests()

# Test slider-specific functionality
source("test_slider_functionality.R")
run_slider_tests()

# Test database functionality
source("test_db.R")
```

## License

This project is for educational purposes. Feel free to modify and use as needed.