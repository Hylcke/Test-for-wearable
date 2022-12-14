
dataUploadUI <- function(id){
  
  ns <- NS(id)
  
  fluidPage(
    fluidRow(
      
      
      shinydashboard::box(

        width = 6,
        title = tagList(icon("running"), "Start"),
        collapsible = TRUE,
        
        tags$br(),
        fluidRow(
          column(6, 
             tags$p("This Shiny application was designed to visualize and process Empatica E4 data."),
             tags$p("The Empatica E4 is a wearable wristband that can be used to record physiological signals such as heart rate, temperature, movement and skin conductance."),
             tags$p("The data will not be permanently stored on the server, no trackers or cookies are used.")
          ),
          
          column(6,
                 tags$img(src= "e4_hero_device-lg-hdpi.jpg", 
                          height="150px", 
                          width="150px", 
                          align="left",href="https://www.empatica.com/research/e4/",target = "_blank")
                          
          )
        ),
        fluidRow(style = "padding-top: 24px;",
                 
          column(3, logo_image_with_link("logos/logo_deborg.svg", "https://www.deborg.nl/", width = "100%")),
          column(3, logo_image_with_link("logos/mit_media_lab.png", "https://www.media.mit.edu/groups/affective-computing/overview/", width = "100%")),
          column(3, logo_image_with_link("logos/u_twente.png","https://www.utwente.nl/nl/bms/pgt/", width = "100%"))
        ),
        fluidRow(
          column(3, logo_image_with_link("logos/umcu.png", "https://www.umcutrecht.nl/nl/innovatie-in-de-psychiatrie", width = "100%")),
          column(3, logo_image_with_link("logos/radboud.png","https://www.ru.nl/bsi/", width = "100%"))
          
        )
        
      ),
      
      shinydashboard::box(
        width = 6,

        title = tagList(icon("table"), "Data input"),
        
        tags$div(style = "width: 100%;",
          tags$div(style = "float: right;",
                   helpButtonUI(ns("help"))
          )
        ),
        
        tags$div(id = ns("div_upload_file"),
          tags$p("Click Browse to select E4 zip files to use in the application."),
  
          fileInput(ns("select_zip_files"),
                    label = "Choose ZIP file(s)", 
                    multiple = TRUE, 
                    accept = ".zip",
                    buttonLabel = "Browse..."),
         
          tags$p("Or, use one of the built-in example datasets.",
                 style = "font-size: 0.95em; font-style: italic;"),
          actionButton(ns("btn_use_example_data_large"), "Use large example dataset", 
                         icon = icon("male"), class = "btn-info"),
          actionButton(ns("btn_use_example_data_small"), "Use small example dataset", 
                       icon = icon("child"), class = "btn-info"),
          
          uiOutput(ns("msg_files_selected")),
          tags$br(),
          htmlOutput(ns("msg_data_read"))
        ),
        
        shinyjs::hidden(
          tags$div(id = ns("div_restart_application"),
           
                   actionButton(ns("btn_restart_app"), "Reset and start over",
                                icon = icon("sync"), class = "btn-lg btn-success")
                   
          )
        )
      )
    )
    
  )
  
}


dataUploadModule <- function(input, output, session){
  
  rv <- reactiveValues(
    zip_files = NULL,
    data = NULL,
    timeseries = NULL,
    data_agg = NULL,
    newdata = NULL,
    fn_names = NULL
  )
  
  callModule(helpButton, "help", helptext = .help$dataupload)
  
  
  observeEvent(input$btn_use_example_data_large, {
    rv$zip_files <- data.frame(
      name = "1574839870_A00204.zip",
      size = NA,
      type = "application/x-zip-compressed",
      datapath = "www/example_data/1574839870_A00204.zip"
    )
  })
  
  observeEvent(input$btn_use_example_data_small, {
    rv$zip_files <- data.frame(
      name = "1635148245_A00204.zip",
      size = NA,
      type = "application/x-zip-compressed",
      datapath = "www/example_data/1635148245_A00204.zip"
    )
  })
  
  observeEvent(input$select_zip_files, {
    rv$zip_files <- input$select_zip_files
  })
  
  
  observeEvent(rv$zip_files, {
    
    # Read selected ZIP files
    fns <- rv$zip_files$datapath
    fn_names <- rv$zip_files$name
    rv$fn_names <- fn_names

    # Read data into a list (Each element of the list contents from 1 zip file)
    data <- list()
    n <- length(fns) + 1
    withProgress(message = "Reading data...", value = 0, {
      
      for(i in seq_along(fns)){
        
        incProgress(1/n, detail = fn_names[i])
        
        out <- wearables::read_e4(fns[i])
        if(is.null(out)){
          
          toastr_error("One or more data files empty - check data!")
          break
          
        } else {
          data[[i]] <- out  
        }
        
      }
      
      if(length(data) > 0){
        
        # If more than 1 zip file selected, row-bind them using our custom function
        incProgress(1/n, detail = "Row-binding")
        if(length(fns) > 1){
          rv$data <- wearables::rbind_e4(data)
        } else {
          rv$data <- data[[1]]
        }
        
        # Calculate aggregated version of the data for much quicker plotting
        rv$data_agg <- wearables::aggregate_e4_data(rv$data)
       
        rv$newdata <- runif(1)
        
        # Message: data read!
        toastr_success("Data read successfully.")
        
        enable_link("tabCalendar")
        enable_link("tabVisualization")
        enable_link("tabCut")
        
        shinyjs::hide("div_upload_file")
        shinyjs::show("div_restart_application")
        
      } else {
        
        disable_link("tabCalendar")
        disable_link("tabVisualization")
        disable_link("tabCut")
      }
      
    })

  })
  
  output$msg_data_read <- renderUI({
    
    req(rv$data)
    tagList(
      tags$p("Data was uploaded and read successfully. Go to the Calendar Tab.",
             style = "color: blue;"),
      tags$p("To read in a new dataset, upload a new Zip file.")
    )
    
  })
  
  
  output$msg_files_selected <- renderUI({
    
    req(rv$zip_files)
    n <- nrow(rv$zip_files)
    if(n > 0){
      tags$p(glue("You have selected {n} ZIP files."))
    }
    
  })
  
  observeEvent(input$btn_restart_app, {
    session$reload()
  })
  
  
  out <- reactive({
    
    list(
      data = rv$data,
      data_agg = rv$data_agg,
      timeseries = rv$timeseries,
      newdata = rv$newdata,
      fn_names = rv$fn_names
    )
    
  })


return(out)
}


if(FALSE){
  
  
  library(shiny)
  
  ui <- fluidPage(
    useShinyjs(),
    
    dataUploadUI("test"),
    tags$hr(),
    verbatimTextOutput("txt_out")
  )
  
  server <- function(input, output, session) {
    
    out <- callModule(dataUploadModule, "test")
    
    output$txt_out <- renderPrint({
      str(out())
    })
    
  }
  
  shinyApp(ui, server)
  
  
  
}

