# Load required libraries
library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)
library(bslib)
library(promises)
library(future)
library(shinyjs)

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
    # Initialize shinyjs within the panel
    useShinyjs(),
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

  # Render event report text output
  output$event_report_text <- renderText({
    if (!is.null(values$event_data) && is.null(values$event_data$error)) {
      # Format the event data as text
      total_text <- paste("Total Events:", values$event_data$total)

      if (nrow(values$event_data$by_type) > 0) {
        type_text <- paste(
          "Events by Type:",
          paste(
            sapply(seq_len(nrow(values$event_data$by_type)), function(i) {
              row <- values$event_data$by_type[i, ]
              paste(row$event_type, ":", row$count)
            }),
            collapse = "\n"
          ),
          sep = "\n"
        )
        paste(total_text, type_text, sep = "\n\n")
      } else {
        paste(total_text, "No events recorded yet.", sep = "\n\n")
      }
    } else if (!is.null(values$event_data) && !is.null(values$event_data$error)) {
      paste("Error loading event data:", values$event_data$message)
    } else {
      ""
    }
  })

  # Show event report modal when Usage menu is clicked (async version)
  observeEvent(input$event_report, {
    # Set loading state and show modal with both elements
    values$loading <- TRUE
    values$event_data <- NULL
    values$modal_open <- TRUE

    # Show modal with both loading indicator and hidden text output
    showModal(modalDialog(
      title = "Event Report",

      # Loading indicator (initially visible)
      div(
        id = "loading_spinner",
        style = "text-align: center; padding: 40px;",
        tags$div(
          style = "display: inline-block; width: 40px; height: 40px; border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; animation: spin 1s linear infinite;",
          tags$style("@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }")
        ),
        br(), br(),
        h5("Loading event data...")
      ),

      # Event data output (initially hidden)
      div(
        id = "event_data_output",
        style = "display: none;",
        verbatimTextOutput("event_report_text")
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

        # Hide loading spinner and show event data
        hide("loading_spinner")
        show("event_data_output")
      }
    }) %...!% (function(error) {
      # Handle errors
      if (values$modal_open) {
        values$event_data <- list(error = TRUE, message = as.character(error))
        values$loading <- FALSE

        # Hide loading spinner and show error data
        hide("loading_spinner")
        show("event_data_output")
      }
    })
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

        # Reset UI elements for next time
        show("loading_spinner")
        hide("event_data_output")
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
