# Load required libraries
library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)
library(bslib)
library(promises)
library(future)

# Database setup function
setup_database <- function() {
  con <- dbConnect(SQLite(), "events.db")

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
  con <- dbConnect(SQLite(), "events.db")
  dbExecute(con, "INSERT INTO events (event_type) VALUES (?)", list(event_type))
  dbDisconnect(con)
}

# Function to get event counts (synchronous version)
get_event_counts <- function() {
  con <- dbConnect(SQLite(), "events.db")
  result <- dbGetQuery(con, "
    SELECT event_type, COUNT(*) as count
    FROM events
    GROUP BY event_type
  ")
  total <- dbGetQuery(con, "SELECT COUNT(*) as total FROM events")
  dbDisconnect(con)

  list(by_type = result, total = total$total)
}

# Function to get event counts asynchronously
get_event_counts_async <- function() {
  future_promise({
    get_event_counts()
  })
}

# Initialize database and future plan
setup_database()
plan(multisession(workers = 2))

# Define UI
ui <- page_navbar(
  title = "tool",

  # Main panel
  nav_panel(
    "main",
    fluidRow(
      column(
        12,
        plotOutput("histogram")
      )
    ),
    br(),
    fluidRow(
      column(
        6,
        sliderInput("sample_size",
          "Sample Size:",
          min = 1,
          max = 10000,
          value = 1000,
          step = 1
        )
      ),
      column(
        6,
        actionButton("generate", "Generate Histogram", class = "btn-primary")
      )
    )
  ),
  nav_spacer(),
  nav_item(actionLink("event_report", label = "", icon = icon("chart-simple")))
)

# Define server logic
server <- function(input, output, session) {
  # Log session start
  isolate({
    log_event("session_start")
  })

  # Reactive values for managing async event report
  values <- reactiveValues(
    loading = FALSE,
    event_data = NULL,
    modal_open = FALSE,
    current_promise = NULL
  )

  # Generate histogram when button is clicked
  observeEvent(input$generate, {
    # Log button press event
    log_event("button_press")

    # Generate random sample using slider value
    sample_data <- rnorm(input$sample_size)

    output$histogram <- renderPlot({
      ggplot(data.frame(x = sample_data), aes(x = .data$x)) +
        geom_histogram(bins = 30, fill = "skyblue", color = "black", alpha = 0.7) +
        labs(
          title = paste("Histogram of", input$sample_size, "Random Normal Values"),
          x = "Value",
          y = "Frequency"
        ) +
        theme_minimal()
    })
  })

  # Show event report modal when Usage menu is clicked (async version)
  observeEvent(input$event_report, {
    # Set loading state and show modal with spinner
    values$loading <- TRUE
    values$event_data <- NULL
    values$modal_open <- TRUE

    # Show modal with loading indicator
    showModal(modalDialog(
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
    ))

    # Start async data loading
    values$current_promise <- get_event_counts_async() %...>% (function(event_data) {
      # Only update if modal is still open
      if (values$modal_open) {
        values$event_data <- event_data
        values$loading <- FALSE
      }
    }) %...!% (function(error) {
      # Handle errors
      if (values$modal_open) {
        values$event_data <- list(error = TRUE, message = as.character(error))
        values$loading <- FALSE
      }
    })
  })

  # Update modal content when data loads
  observe({
    if (values$modal_open && !values$loading && !is.null(values$event_data)) {
      if (!is.null(values$event_data$error)) {
        # Show error message
        showModal(modalDialog(
          title = "Event Report - Error",
          div(
            style = "color: red;",
            h4("Error loading event data"),
            p(values$event_data$message)
          ),
          easyClose = TRUE,
          footer = modalButton("Close")
        ))
      } else {
        # Show data
        showModal(modalDialog(
          title = "Event Report",
          h4("Total Events: ", values$event_data$total),
          br(),
          h5("Events by Type:"),
          if (nrow(values$event_data$by_type) > 0) {
            tagList(
              lapply(seq_len(nrow(values$event_data$by_type)), function(i) {
                row <- values$event_data$by_type[i, ]
                p(paste(row$event_type, ":", row$count))
              })
            )
          } else {
            p("No events recorded yet.")
          },
          easyClose = TRUE,
          footer = modalButton("Close")
        ))
      }
    }
  })

  # Handle modal close to cancel async operation
  # Use a more reliable method to detect modal close
  observe({
    # Check if modal is closed by monitoring if no modal is currently displayed
    if (!is.null(input$`shiny-modal`) && input$`shiny-modal` == FALSE) {
      if (values$modal_open) {
        values$modal_open <- FALSE
        # Clear any pending data
        values$event_data <- NULL
        values$loading <- FALSE
      }
    }
  })

  # Log session end when session ends
  session$onSessionEnded(function() {
    log_event("session_end")
  })
}

# Run the application
shinyApp(ui = ui, server = server)
