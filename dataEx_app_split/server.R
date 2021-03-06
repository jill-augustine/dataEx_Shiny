library(conflicted)
#library(SparkR)
library(shiny)
#conflict_prefer("column","shiny") #already defined in ui.R
conflict_prefer("group_by","dplyr")
conflict_prefer("filter", "dplyr")
library(sparklyr)
library(readr)
library(dplyr)
library(ggplot2)
library(shinythemes)
library(DT)
library(lubridate)
#library(shinyTime)
library(hms)
# library(stringr) # added prefixes to the two functions instead
library(shinycssloaders)

################# SERVER FUNCTION #####################
server <- function(input, output, session) {
  
  #takes up to 10 secs
  config <- spark_config()
  config$spark.sql.hive.convertMetastoreParquet <- 'false'
  config$spark.driver.memory <- '20g'
  sc <- spark_connect(master = "local[3]", app_name = "dataEx", config = spark_config())
  
 
  #####################################################################   
  ### ASSIGNING OBJECTS, FUNCTIONS ETC. ###  
  
  ls_output <- system2(command = "ls",
        args = c("../ja_dataEx_data"), 
        stdout = TRUE)

  filenames <- ls_output %>% stringr::str_extract("[^/]*$")
    
  customerID <- reactive({req(sparkDF())
    sparkDF() %>% 
       select(customerID) %>%
      head(1) %>%
      collect() %>% as.character()
      
  })
  
  
  themedataEx <- theme(text = element_text(face="bold"),
                    plot.title = element_text(colour = "grey20", hjust = 0.5, size = 16),
                    axis.title = element_text(size=14, colour = "grey20"),
                    axis.text = element_text(size=11, colour = "grey30"),
                    legend.title = element_text(size=14),
                    legend.text = element_text(size=12)
  )
  
  ja_theme_greylines <-     theme(text = element_text(face="bold", color = "grey40"),
                                  plot.title = element_text(hjust = 0, size = 16),
                                  axis.title = element_text(size=14),
                                  axis.text = element_text(size=11),
                                  legend.title = element_text(size=12),
                                  legend.text = element_text(size=10),
                                  panel.background = element_rect(fill = "grey93"),
                                  panel.grid.major.x = element_blank(),
                                  panel.grid.minor.x = element_blank(),
                                  panel.border = element_blank(),
                                  axis.line.x = element_line(colour = "grey50"),
                                  axis.line.y = element_line(colour = "grey50"))
  ##################################################################### 
  ### ERROR MESSAGES ###
  
  datanotfound <- eventReactive(input$loaddataset, 
                                if (input$datasetID != "" & !input$datasetID %in% filenames)
                                {"Error: Dataset not found, check ID again. \n If the dataset was requested over 4 weeks ago, it has been deleted and must be requested again."})
  
  importdateserror <- eventReactive(input$loaddataset, 
                              if (input$importdates[2] < input$importdates[1])
                              {"Error: The end date must be the same as or after the start date"})
  
  visdateserror <- eventReactive(input$applyselection, 
                                 if (input$visdates[2] < input$visdates[1])
                                 {"Error: The end date must be the same as or after the start date"})
  
  exportrangeerror <- eventReactive(input$collectdata,
                                    {if (
                                        (!is.na(input$colldates[1]) & !is.na(input$colldates[2]) & !is.na(input$collstarttime) & !is.na(input$collendtime))
                                        &
                                        (as_date(input$colldates[2]) %>%
                                        paste(input$collendtime) %>%
                                        ymd_hm())
                                        - (as_date(input$colldates[1]) %>%
                                           paste(input$collstarttime) %>%
                                           ymd_hm())
                                          > dhours(6))
                                      {"Error: Selected range must be 6 hours or less"}
                                    })
  
  exporttimeerror1 <- eventReactive(input$collectdata,
                             {if (is.na(
                               as_date(input$colldates[1]) %>%
                                       paste(input$collstarttime) %>%
                                       ymd_hm()
                                       ))
                             {"Error: Start time is not valid"}
})

                                      
  exporttimeerror2 <- eventReactive(input$collectdata,
                                    {if (is.na(
                                      as_date(input$colldates[2]) %>%
                                      paste(input$collendtime) %>%
                                      ymd_hm()
                                    ))
                                    {"Error: End time is not valid"} else {""}
})

  
  ### UI for error messages ###
  output$message1 <- renderUI({
    fluidRow(
      fluidRow(column(12,datanotfound())),
      fluidRow(column(12,importdateserror()))
    )
  })
  
    output$message2 <- renderUI({
        fluidRow(
          fluidRow(column(12,visdateserror())),
          br()
        )
  })
  
    output$message3 <- renderUI({
      fluidRow(
        fluidRow(column(11,offset = 1, exportrangeerror())),
        fluidRow(column(11,offset = 1, exporttimeerror1())),
        br()
      )
    })
  ##################################################################### 
    
    
  ########### REQUEST DATA ##############
    logs_req <- observeEvent(eventExpr = input$requestdata,
                             handlerExpr = {
                               user <- system2("whoami", stdout = TRUE) 
                               email <- input$email # input$email
                               customerID <- input$customerID # input$customerID
                               from <- as.character(input$requestdates[1]) # as.character(input$requestdates[1])
                               to <- as.character(input$requestdates[2])
                               
                               log <- paste(as.character(Sys.time()), user, email, customerID, from, to, sep = ";")
                               
                               write_lines(log, "../logs_req.txt", append = TRUE)
                             })
    
    reqmsg <- eventReactive(eventExpr = input$requestdata,
                          valueExpr = {paste("The data request was successfully submitted. You will get an email as soon as the data are available. You can now close this window.")
                          })

  output$datarequested <- renderText({
    reqmsg()
  })
  reqdata <- observeEvent(eventExpr = input$requestdata,
                          handlerExpr = {
    # extracting username
    user <- system2("whoami", stdout = TRUE)
    # extracting time of request for datasetID
    req_time <- Sys.time() %>% str_sub(6,19) %>% str_extract_all('[:digit:]') %>% unlist() %>% str_c(collapse = "")


    cmd <- "ssh"
    # defining command arguments from input
    args <- c(paste0(user,"@machineA"),
       paste0("'bash ja_dataEx_request.sh --user ",
             user, #will not use input$user but take it from the Rstudio environment instead
             " --email ",
             input$email, # input$email
             " --customerID ",
             input$customerID, # input$customerID
             " --start ",
             as.character(input$requestdates[1]), # as.character(input$requestdates[1])
             " --end ",
             as.character(input$requestdates[2]), # as.character(input$requestdates[2])
             " --dataset ",
             user,
             req_time,
             "'"))
  # running the command which launches ja_dataEx_dates2parquet_v2.py through a spark2-submit job
  system2(cmd, args)
  #user
  #req_time
  print(paste("Running Command: ", cmd, args[1], args[2]))
   })    
  
  ########### LOAD DATA ##############  
  ## logging the load request
  logs_read <- observeEvent(eventExpr = input$loaddataset,
                            handlerExpr = {
                              req(input$datasetID,
                                  (input$datasetID %in% filenames),
                                  (input$importdates[1] <= input$importdates[2]))
                              datasetID <- input$datasetID
                              user <- system2("whoami", stdout = TRUE) 
                              in_ID <- input$datasetID
                              from <- as.character(input$importdates[1])
                              to <- as.character(input$importdates[2])
                              
                              log <- paste(as.character(Sys.time()), user, datasetID, from, to, sep = ";")
                              write_lines(log, "../logs_read.txt", append = TRUE)
                            })
  
  ########  ############

  sparkDF <- eventReactive(
    eventExpr = input$loaddataset,
    valueExpr = {
      ### start ###
      req(input$datasetID,
          (input$datasetID %in% filenames),
          (input$importdates[1] <= input$importdates[2]))
        in_ID <- input$datasetID
        imp1 <- input$importdates[1]
        imp2 <- input$importdates[2]
        
        name <- getwd()
        endname <- name %>% stringr::str_extract("[^/]*$")
        restname <- name %>% str_sub(end = -(nchar(endname)+1))
        
        spark_read_parquet(sc, name="df",
        path=paste0(restname,"ja_dataEx_data/", in_ID))

     ### end ###
    })
  
  ########### Loading Message ############# 
    
  output$dataloaded <- renderText({
    req(sparkDF())
    paste("Data was successfully loaded!")
  })
    

  #####################################################################
  ### CREATING TEMP MINSPLAYED DATATABLE
  
  minsplayeddatatemp <- eventReactive(
    eventExpr = input$applyselection,
    valueExpr = {
      req(sparkDF(),(input$visdates[1] <= input$visdates[2]))
      # filtering on dates
      from <- input$visdates[1]
      to <- input$visdates[2]
      visfilt <- sparkDF() %>%
          filter(ymd >= as.character(from), 
                 ymd <= as.character(to))
                 
      if(to - from == 0) {
        ###data per hour###
          visfilt %>%
          group_by(ymdhm, genre) %>%
          summarise(minsplayed = sum(minsplayed, na.rm = TRUE)) %>%
          arrange(ymdhm) %>%
          collect() %>%
          ###
          mutate(Time = floor_date(ymd_hm(ymdhm), unit="1 hour")) %>%
          group_by(Time, genre) %>%
          summarise(minsplayed = sum(minsplayed, na.rm = TRUE)) %>% ungroup() %>%
          arrange(desc(minsplayed))
        ### end of expression###
        
      }else if (to - from <= 30) { 
        ###data per day###
          visfilt %>%
          group_by(ymd, genre) %>%
          summarise(minsplayed = sum(minsplayed, na.rm = TRUE)) %>%
          arrange(ymd) %>%
          collect() %>%
          ###
          mutate(Date = floor_date(ymd(ymd))) %>%
          group_by(Date, genre) %>%
          summarise(minsplayed = sum(minsplayed, na.rm = TRUE)) %>% ungroup() %>%
          arrange(desc(minsplayed))
        ### end of expression###
        
      } else if (to - from > 30) {
        ###data per month###
        visfilt %>%
          group_by(ymd, genre) %>%
          summarise(minsplayed = sum(minsplayed, na.rm = TRUE)) %>% ungroup() %>%
          arrange(ymd) %>%
          collect() %>%
          ###
          mutate(Month = floor_date(ymd(ymd), unit = "1 month")) %>%
          select(Month, genre, minsplayed) %>%
          arrange(desc(minsplayed))
        ### end of expression###
      }
    })
  
  ### CREATING NON-TEMP MINSPLAYED DATA TABLE
  # where the genre is factored
  minsplayeddata <- reactive({
    req(minsplayeddatatemp())
  
    
    gen_levels <- minsplayeddatatemp() %>% pull(genre) %>% unique()
    gen_labels <- gen_levels
  
    minsplayeddatatemp()  %>%
      dplyr::mutate(genre = factor(genre, levels = gen_levels, labels = gen_labels))  %>%
      # removing the minsplayed column and readding it add the end
      select(-minsplayed, minsplayed)
  })

#  minsplayeddata <- reactive({
#    req(minsplayeddatatemp())
#    minsplayeddatatemp()
#  })

  
  #################################################################
  ### UPDATING VISUALISATION DATES SELECTION RANGE TO MATCH IMPORT DATES SELECTION RANGE  
  observeEvent(input$importdates,{
    req(input$importdates)
    updateDateRangeInput(session, inputId = "visdates", 
                         start = input$importdates[1],
                         end = input$importdates[2],
                         min = input$importdates[1],
                         max = input$importdates[2])  
  })
  
  #################################################################
  ### VISUALISATION ONE
  
  ## Creating Plot Over Time   
  PlotOverTime <- eventReactive(
    eventExpr = input$applyselection,
    valueExpr = {
      req(minsplayeddata())
      

      if(input$visdates[2] - input$visdates[1] == 0) {
        ###graph per hour###
        hourbreaks <- as.hms(seq(0,84600,3600))
        hourbreaklabs <- substring(hourbreaks,1,5)
        
        minsplayeddata() %>% 
          dplyr::mutate(Time = as.hms(substring(Time,12,19))) %>%
          ggplot(aes(x=Time, y=minsplayed, fill=genre)) +
          geom_col() +
          labs(title = paste("Minutes Played per Hour for CustomerID:", customerID()), y = "Minutes Played")  +
          scale_x_time(name = "Time", 
                       breaks = hourbreaks[seq(1,length(hourbreaks),2)], 
                       labels = hourbreaklabs[seq(1,length(hourbreaklabs),2)]) + 
          #scale_fill_discrete(labels = gen_labels) +
          scale_fill_brewer(palette = "Greens", direction = -1) +
          ja_theme_greylines +
          theme(axis.text.x = element_text(angle = 45, hjust = 1),
                panel.grid.major.x = element_blank(),
                panel.grid.minor.x = element_blank(),
                legend.position = "left") 
        ### end of expression###
        
      }else if (input$visdates[2] - input$visdates[1] <= 30) { #time difference of 30days includes 31days total
        ### graph per day###
        daybreaks <- minsplayeddata() %>% pull(Date)
        daybreaklabs <- paste(substr(daybreaks,9,10), lubridate::month(daybreaks, label=TRUE))
        
        minsplayeddata() %>%
          ggplot(aes(x=Date, y=minsplayed, fill = genre)) +
          geom_col() +
          labs(title = paste("Minutes Played per Day for CustomerID:", customerID()), y = "Minutes Played")  +
          scale_x_time(name = "Date", breaks = daybreaks[seq(1,length(daybreaks),2)], 
                       labels = daybreaklabs[seq(1,length(daybreaklabs),2)]) + 
          #scale_fill_discrete(labels = gen_labels) +
          scale_fill_brewer(palette = "Greens", direction = -1) +
          ja_theme_greylines +
          theme(axis.text.x = element_text(angle = 45, hjust = 1),
                panel.grid.major.x = element_blank(),
                panel.grid.minor.x = element_blank(),
                legend.position = "left")
        ### end of expression###
        
      } else if (input$visdates[2] - input$visdates[1] > 30) {
        ### graph per month###
        monthbreaks <- minsplayeddata() %>% pull(Month)
        monthbreaklabs <- lubridate::month(monthbreaks, label=TRUE)
        
        minsplayeddata() %>%
          group_by(Month, genre) %>%
          summarise(minsplayed = sum(minsplayed, na.rm = TRUE)) %>%
          ggplot(aes(x=Month, y=minsplayed, fill = genre, colour = "1")) +
          geom_col() +
          labs(title = paste("Minutes Played per Month for CustomerID:", customerID()), y = "Minutes Played")  +
          scale_x_time(name = "Month", breaks = monthbreaks, 
                       labels = monthbreaklabs) + 
          #scale_fill_discrete(labels = gen_labels) +
          scale_color_manual(values = c("1"= "grey50"), guide = FALSE ) +
          scale_fill_brewer(palette = "Greens", direction = -1) +
          ja_theme_greylines +
          theme(axis.text.x = element_text(angle = 45, hjust = 1),
                panel.grid.major.x = element_blank(),
                panel.grid.minor.x = element_blank(),
                legend.position = "left")
        ### end of expression###
      }
    })
  
  ### renderPlot for plotOutput
  output$plotovertime <- renderPlot({
    PlotOverTime()
  })
  
  ### downloadHandler to download PlotOverTime
  output$gen_img1 <- downloadHandler(
    filename = function() {paste("vis-", Sys.Date(), ".png", sep="")},
    content = function(con) {
      ggplot2::ggsave(filename = con, plot = PlotOverTime(), device = "png", width = 12, height = 6)
    }
  )
  ### Download button to appear after plot has been created
  output$downloadvis1 <- renderUI({
    req(PlotOverTime())
    fluidRow(column(12,downloadButton(outputId = "gen_img1",
                                      label = "Download Graph",
                                      class = "btn-primary")))
  })
  
  #################################################################
  ### DATATABLE ONE
  
  datatable1 <- eventReactive(input$applyselection,
                              {if(input$visdates[2] - input$visdates[1] == 0) {
                                  minsplayeddata() %>%
                                  dplyr::mutate(Time = paste(lubridate::hour(Time), '00', sep = ":"))  
                                } else if (input$visdates[2] - input$visdates[1] <= 30) {
                                  minsplayeddata() %>%
                                    dplyr::mutate(Date = paste(stringr::str_pad(lubridate::day(Date), 2, "left", "0"), lubridate::month(Date), lubridate::year(Date), sep = "/"))  
                                } else if (input$visdates[2] - input$visdates[1] > 30) {
                                  minsplayeddata() %>%
                                    dplyr::mutate(Month = paste(lubridate::month(Month), lubridate::year(Month), sep = "/")) 
                                }  
                              })

  ### renderDataTable for dataTableOutput
  output$minsplayeddatatable <- DT::renderDataTable({ 
    req(datatable1(),(nrow(datatable1()) >0 )) # there should be at least one row of data to show
    
        DT::datatable(
      data = datatable1(),
      options = list(pageLength = 10),
      rownames = FALSE)
  })
  
  ### downloadHandler to download gen_agg1
  output$gen_agg1 <- downloadHandler(
    filename = function() {paste("data-", Sys.Date(), ".csv", sep="")},
    content = function(con) {
      readr::write_delim(minsplayeddata(), con, delim=";")
    }
  )
  
  ### Download button to appear after data has been created
  output$downloadagg1 <- renderUI({
    fluidRow(column(12,downloadButton(outputId = "gen_agg1",
                                      label = "Download Data",
                                      class = "btn-primary")))
  })
  
  #################################################################
  ### VISUALISATION 2
  
  ### rearranging data per genre
  pref_gendatatemp <- reactive({
    minsplayeddata() %>% 
      group_by(genre) %>% 
      summarise(minsplayed = sum(minsplayed, na.rm = TRUE)) %>%
      dplyr::arrange(minsplayed)
  })
  
  pref_gendata <- reactive({
    req(pref_gendatatemp())
    gen_levels <- pref_gendatatemp() %>% pull(genre) %>% unique()
    pref_gendatatemp() %>%
      dplyr::mutate(genre = factor(genre,
                                        levels = gen_levels))
  })
  
  ### plot per genre  
  PlotPerGen <- eventReactive(
    eventExpr = input$applyselection,
    valueExpr = {
      req(pref_gendata())
      
      pref_gendata() %>%
        ggplot(aes(x = genre, y=minsplayed, fill = genre, colour = "1")) + 
        geom_col() +
        labs(title = paste("Minutes Played per Genre for CustomerID:", customerID()),
             y = "Minutes Played")  +
        scale_fill_discrete(direction = -1) + #changing direction so colours correspond to first graph       
        scale_color_manual(values = c("1"= "grey50"), guide = FALSE ) +
        scale_fill_brewer(palette = "Greens", direction = -1) +
        ja_theme_greylines +
        coord_flip() +
        theme(axis.text = element_text(size=12),
              axis.title.y = element_blank(), 
              legend.position = "none",
              panel.grid.major.y = element_blank(),
              panel.grid.minor.y = element_blank(),
              panel.grid.major.x = element_line(colour = "white"),
              panel.grid.minor.x = element_line(colour = "white"))
    })
  
  ### renderPlot for plotOutput
  output$plotpergenre <- renderPlot({
    PlotPerGen()
  })
  
  ### downloadHandler to download PlotPerGen
  output$gen_img2 <- downloadHandler(
    filename = function() {
      paste("vis-", Sys.Date(), ".png", sep="")
    },
    content = function(con) {
      ggplot2::ggsave(filename = con, plot = PlotPerGen(), device = "png", width = 12, height = 6)
    }
  )
  
  ### Download button to appear after plot has been created
  output$downloadvis2 <- renderUI({
    req(PlotPerGen())    
    fluidRow(column(12, downloadButton(outputId = "gen_img2",
                                       label = "Download Graph",
                                       class = "btn-primary")))
  })
  
  #################################################################
  ### DATATABLE TWO
  
  ### renderDataTable for dataTableOutput
  output$perGendatatable <- DT::renderDataTable({ 
    req(pref_gendata(),(nrow(pref_gendata()) >0 )) # there should be at least one row of data to show
    
    DT::datatable(
      data = pref_gendata(),
      options = list(pageLength = 10),
      rownames = FALSE)
  })
  
  ### Download button to appear after data has been created
  output$gen_agg2 <- downloadHandler(
    filename = function() {paste("data-", Sys.Date(), ".csv", sep="")},
    content = function(con) {
      readr::write_delim(pref_gendata(), con, delim=";")
    })
  
  ### Download button to appear after data has been created
  output$downloadagg2 <- renderUI({
    req(pref_gendata(),(nrow(pref_gendata()) >0 )) # there should be at least one row of data to show
    fluidRow(column(12,downloadButton(outputId = "gen_agg2",
                                      label = "Download Data",
                                      class = "btn-primary")))
  })
  
  #################################################################
  ### UPDATING COLLECT DATES SELECTION RANGE TO MATCH IMPORT DATES SELECTION RANGE  
  observeEvent(input$importdates,{
    req(input$importdates)
    updateDateRangeInput(session, inputId = "colldates", 
                         start = input$importdates[1],
                         end = input$importdates[2],
                         min = input$importdates[1],
                         max = input$importdates[2])  
  })
  
  #######################################################
  ### DATATABLE RAW 
  
  #raw data for a time period of 6 hrs or less
  
  RawData <- eventReactive(input$collectdata,{
    req(sparkDF(), input$colldates, 
        (is.POSIXt(strptime(input$collstarttime,"%R"))),
        (is.POSIXt(strptime(input$collendtime,"%R"))),
        
        ( # this checks that the all the date and time inputs are present
          (!is.na(input$colldates[1]) & !is.na(input$colldates[2]) & !is.na(input$collstarttime) & !is.na(input$collendtime))
          &
          # this checks that the selected time is 6 hours or less
            (as_date(input$colldates[2]) %>%
               paste(input$collendtime) %>%
               ymd_hm())
          - (as_date(input$colldates[1]) %>%
               paste(input$collstarttime) %>%
               ymd_hm())
          <= dhours(6))
        
        )
        
    from <- input$colldates[1] %>%
              paste(input$collstarttime, sep = ' ') 

    to <- input$colldates[2] %>%
               paste(input$collendtime, sep = ' ')

    # this is the raw data which will be available for download
    collected <- sparkDF() %>% 
      # filtering the timeframe 
        filter(ymdhm >= from,
               ymdhm <= to) %>%
      # selecting input variables
        select(input$selectedvars) %>%
        collect()
    
    collected
  })
  
  ### renderDataTable for dataTableOutput
  output$rawdata <- DT::renderDataTable({ # there should be at least one row of data to show, the data should not be from more than 1 day
    req(RawData())
    
    DT::datatable(
      data = RawData(),
      #data = minsplayeddatatemp(),
      options = list(pageLength = 10),
      rownames = FALSE)
  })
  
  ### Download button to appear after data has been created
  output$downloadData <- downloadHandler(
    filename = function() {paste("data-", Sys.Date(), ".csv", sep="")},
    content = function(con) {
      readr::write_delim(RawData(), con, delim=";")
    }
  )
  
  ### download button and data to appear after data has been created
  output$dataAndButton <- renderUI({
    req(RawData())
    if (nrow(RawData()) == 0) {
      fluidRow(h5("No data found for this time period."))
    } else {
    fluidRow(fluidRow(column(12, h4(strong("Data Preview")))),
             ### rawdata
             fluidRow(column(12, DT::dataTableOutput(outputId = "rawdata"))),
             ## download button
             fluidRow(column(12,  
                    downloadButton(outputId = "downloadData",
                                   label = "Download Raw Data",
                                   class = "btn-primary"))))
    }
  })
  #######################################################
}

#######################################################
# Run the application 
#shinyApp(ui = ui, server = server)
