cutDataModuleUI <- function(id){
  
  ns <- NS(id)
  
  fluidPage(
    fluidRow(
      shinydashboard::box(width = 12, title = tagList(icon("cut"), "Data cutter"),
                          
                          tags$div(style = "width: 100%; height: 30px;",
                                   tags$div(style = "float: right;",
                                            helpButtonUI(ns("help"))
                                   )
                          ),
                          
                          
                          fluidRow(
                            column(6, 
                                   
                                   tags$p("Cut the data into separate ZIP files, for example 5min in each file."),
                                   
                                   tags$p("Select start and end time of the desired section on the right."),
                                   
                                   numericInput(ns("num_interval_length"), "Select interval length (minutes)",
                                                value = 5, min = 1, step = 1),
                                   
                                   side_by_side(
                                     actionButton(ns("btn_select_folder_output"), "Select output folder", 
                                                  icon = icon("folder-open"), class = "btn-light"),
                                     uiOutput(ns("ui_folder_out"), inline = TRUE)
                                   ),
                                   
                                   
                                   uiOutput(ns("ui_can_do_cut"), style = "padding-top: 24px;"),
                                   actionButton(ns("btn_do_cut"), "Perform cut", class = "btn-success btn-lg", 
                                                icon = icon("play"))       
                                   
                            ),
                            column(6,
                                   tags$h4("Select begin date / time"),
                                   
                                   side_by_side(
                                     dateInput(ns("date_analysis_start"), label = "Date",
                                               value = NULL, min = NULL, max = NULL,
                                               width = 200),
                                     numericInput(ns("time_hour_start"), "Hour", value = 0, width = 100, max = 24),
                                     numericInput(ns("time_minute_start"), "Minutes", value = 0, width = 100, max = 60),
                                     numericInput(ns("time_second_start"), "Seconds", value = 0, width = 100, max = 60)
                                   ),
                                   tags$br(),
                                   
                                   tags$h4("Select end date / time"),
                                   side_by_side(
                                     dateInput(ns("date_analysis_end"), label = "Date",
                                               value = NULL, min = NULL, max = NULL,
                                               width = 200),
                                     numericInput(ns("time_hour_end"), "Hour", value = 0, width = 100, max = 24),
                                     numericInput(ns("time_minute_end"), "Minutes", value = 0, width = 100, max = 60),
                                     numericInput(ns("time_second_end"), "Seconds", value = 0, width = 100, max = 60)
                                   )
                                   
                            )
                          )
                          
      )
    )
  )
  
}



cutDataModule <- function(input, output, session, data = reactive(NULL)){
  
  callModule(helpButton, "help", helptext = .help$cut)
  
  
  # Fill analysis times
  observe({
    
    data <- data()$data
    
    req(nrow(data$EDA) > 0)
    
    tms <- range(data$EDA$DateTime)
    updateDateInput(session, "date_analysis_start",
                    value = min(as.Date(tms)),
                    min = min(as.Date(tms)),
                    max = max(as.Date(tms))
    )
    updateDateInput(session, "date_analysis_end",
                    value = max(as.Date(tms)),
                    min = min(as.Date(tms)),
                    max = max(as.Date(tms))
    )
    
    updateNumericInput(session, "time_hour_start",
                       value = hour(min(tms)), min = 0, max = 23)
    updateNumericInput(session, "time_hour_end",
                       value = hour(max(tms)), min = 0, max = 23)
    
    updateNumericInput(session, "time_minute_start",
                       value = minute(min(tms)), min = 0, max = 59)
    updateNumericInput(session, "time_minute_end",
                       value = minute(max(tms)), min = 0, max = 59)
    
    updateNumericInput(session, "time_second_start",
                       value = second(min(tms)), min = 0, max = 59)
    updateNumericInput(session, "time_second_end",
                       value = second(max(tms)), min = 0, max = 59)
    
    
  })
  
  start_time <- reactive({
    
    ISOdatetime(
      year = year(input$date_analysis_start),
      month = month(input$date_analysis_start),
      day = day(input$date_analysis_start),
      hour = input$time_hour_start,
      min = input$time_minute_start,
      sec = input$time_second_start,
      tz = "UTC"
    )
    
  })
  
  end_time <- reactive({
    
    ISOdatetime(
      year = year(input$date_analysis_end),
      month = month(input$date_analysis_end),
      day = day(input$date_analysis_end),
      hour = input$time_hour_end,
      min = input$time_minute_end,
      sec = input$time_second_end,
      tz = "UTC"
    ) 
    
  })
  
  
  interval_can_be_cut <- reactive({
    
    if(is.na(start_time()) || is.na(end_time())){
      return(FALSE)
    } else {
      m <- as.numeric(difftime(start_time(), end_time(), units= "mins"))
      m %% input$num_interval_length == 0  
    }
    
  })
  
  observe({
    shinyjs::toggleState("btn_do_cut", condition = interval_can_be_cut() & !is.null(folder_out()))
  })
  
  output$ui_can_do_cut <- renderUI({
  
    if(isTRUE(interval_can_be_cut())){
      NULL
    } else {
      
      if(is.null(folder_out())){
        tags$p("Please select an output folder.",
               style = "font-size: 0.9em; font-style: italic;")        
      } else {
        tags$p("Please select start and end times that can be exactly cut by the interval.",
               style = "font-size: 0.9em; font-style: italic;")
      }
      
    }
      
  })
  
  folder_out <- reactiveVal()
  
  observeEvent(input$btn_select_folder_output, {
    
    chc <- choose_directory()
    
    if(!is.na(chc)){
      folder_out(chc)
    }
    
  })
  
  output$ui_folder_out <- renderUI({
    
    req(folder_out())
    tags$p(folder_out(), style = "font-size: 0.9em; font-style: italic; padding-top: 8px;")
    
  })
  
  observeEvent(input$btn_do_cut, {
    
    toastr_info("ZIP file cutting started....")
    shinyjs::disable("btn_do_cut")
    
    wearables::filter_createdir_zip(data = data()$data,
                                    time_start = start_time(),
                                    time_end = end_time(),
                                    interval = input$num_interval_length, 
                                    out_path = folder_out(),
                                    fn_name = data()$fn_names[1]
                                    )
                                    
    toastr_success("ZIP file cut into pieces")
    shinyjs::enable("btn_do_cut")
    
  })
  
  
}






