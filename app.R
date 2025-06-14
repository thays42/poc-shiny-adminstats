# Load required libraries
library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)
library(bslib)

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

# Function to get event counts
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

# Initialize database
setup_database()

# Define UI
ui <- page_navbar(
  title = "tool",

  # Main panel
  nav_panel("main",
    fluidRow(
      column(12,
        plotOutput("histogram")
      )
    ),
    br(),
    fluidRow(
      column(6,
        sliderInput("sample_size",
                   "Sample Size:",
                   min = 1,
                   max = 10000,
                   value = 1000,
                   step = 1)
      ),
      column(6,
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

  # Generate histogram when button is clicked
  observeEvent(input$generate, {
    # Log button press event
    log_event("button_press")

    # Generate random sample using slider value
    sample_data <- rnorm(input$sample_size)

    output$histogram <- renderPlot({
      ggplot(data.frame(x = sample_data), aes(x = x)) +
        geom_histogram(bins = 30, fill = "skyblue", color = "black", alpha = 0.7) +
        labs(title = paste("Histogram of", input$sample_size, "Random Normal Values"),
             x = "Value",
             y = "Frequency") +
        theme_minimal()
    })
  })

  # Show event report modal when Usage menu is clicked
  observeEvent(input$event_report, {
    event_data <- get_event_counts()

    showModal(modalDialog(
      title = "Event Report",

      h4("Total Events: ", event_data$total),
      br(),

      h5("Events by Type:"),
      if (nrow(event_data$by_type) > 0) {
        tagList(
          lapply(1:nrow(event_data$by_type), function(i) {
            row <- event_data$by_type[i, ]
            p(paste(row$event_type, ":", row$count))
          })
        )
      } else {
        p("No events recorded yet.")
      },

      easyClose = TRUE,
      footer = modalButton("Close")
    ))
  })

  # Log session end when session ends
  session$onSessionEnded(function() {
    log_event("session_end")
  })
}

# Run the application
shinyApp(ui = ui, server = server)
