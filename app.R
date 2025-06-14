# Load required libraries
library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)

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
ui <- fluidPage(
  titlePanel("Random Histogram Generator with Event Logging"),

  sidebarLayout(
    sidebarPanel(
      actionButton("generate", "Generate Histogram", class = "btn-primary"),
      br(), br(),
      actionButton("show_report", "Show Event Report", class = "btn-info")
    ),

    mainPanel(
      plotOutput("histogram")
    )
  )
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

    # Generate random sample and create histogram
    sample_data <- rnorm(1000)

    output$histogram <- renderPlot({
      ggplot(data.frame(x = sample_data), aes(x = x)) +
        geom_histogram(bins = 30, fill = "skyblue", color = "black", alpha = 0.7) +
        labs(title = "Histogram of 1000 Random Normal Values",
             x = "Value",
             y = "Frequency") +
        theme_minimal()
    })
  })

  # Show event report modal
  observeEvent(input$show_report, {
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
