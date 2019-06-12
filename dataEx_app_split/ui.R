################################################
################################################
library(conflicted)
#library(SparkR)
library(shiny)
conflict_prefer("column","shiny")
conflict_prefer("filter", "dplyr")
library(sparklyr)
#library(readr)
library(dplyr)
library(ggplot2)
library(shinythemes)
library(DT)
library(lubridate)
#library(shinyTime)
library(hms)
library(stringr)
library(shinycssloaders)


# Define UI for application that draws a histogram
ui <- fluidPage(theme = shinytheme("flatly"),
                
                navbarPage(title = "Jillian Augustine - Data Exploration", id = "tabs", selected = strong("1) Request Dataset"),
                           tabPanel(title = strong("1) Request Dataset"),
                                    wellPanel(
                                      fluidRow(
                                               column(3, textInput(inputId = "email",
                                                                   label = "Enter E-Mail Address",
                                                                   placeholder = "hello@example.com")),
                                               column(3,textInput(inputId = "customerID",
                                                                  label = "Enter Customer ID Number")),
                                               column(3, dateRangeInput(inputId = "requestdates",
                                                                        label = "Enter start and end dates",
                                                                        weekstart = 1,
                                                                        language = "en",
                                                                        format = "dd/mm/yyyy")),
                                               column(3,br(),
                                                      actionButton(inputId = "requestdata",
                                                                     label = "Request Dataset",
                                                                     class = "btn-primary"))),
                                      fluidRow(column(12,textOutput(outputId = "datarequested") %>% 
                                                 withSpinner(type = 1, color = "#2C3E50")))
                                    )
                           ),
                           tabPanel(title = strong("2) Load Dataset"),
                                    fluidRow(column(12, h4(strong("Select data to import")))),
                                    wellPanel(
                                      fluidRow(column(4, textInput(inputId = "datasetID", 
                                                                   label = "Enter Dataset ID", 
                                                                   placeholder = "userplustimestamp"
                                                                   )), 
                                               column(3, dateRangeInput(inputId = "importdates",
                                                                        label = "Enter start and end dates (dd/mm/yyyy)",
                                                                        weekstart = 1,
                                                                        language = "en",
                                                                        format = "dd/mm/yyyy",
                                                                        start = Sys.Date(), 
                                                                        end = Sys.Date())), 
                                               column(2,br(),
                                                      actionButton(inputId = "loaddataset",
                                                                   label = "Load Dataset",
                                                                   class = "btn-primary"))),
                                      uiOutput(outputId = "message1"),
                                      textOutput(outputId = "dataloaded") %>% withSpinner(type = 1, color = "#2C3E50")
                                    )),
                           
                           
                           tabPanel(title = strong("3) Visualise Data"),
                                    fluidRow(column(12, h4(strong("Select a date range to visualise")))),
                                    wellPanel(
                                      fluidRow(column(3,dateRangeInput(inputId = "visdates",
                                                                       label = "Enter start and end dates",
                                                                       weekstart = 1,
                                                                       language = "en",
                                                                       format = "dd/mm/yyyy",
                                                                       start = Sys.Date(),
                                                                       end = Sys.Date())),
                                               column(2,br(), actionButton(inputId = "applyselection",
                                                                           label = "Apply Selection",
                                                                           class = "btn-primary"))),
                                      uiOutput(outputId = "message2"),
                                      fluidRow(column(12, p("Select ", strong("1 day"), " to view data ", strong("per hour")), 
                                                      p("Select ",strong("2-31 days"), " to view data ", strong("per day")),
                                                      p("Select ", strong("32+ days"), " to view data ", strong("per month "))))
                                      
                                    ),
                                    fluidRow(column(6,
                                                    fluidRow(column(12,plotOutput(outputId = "plotovertime") %>%
                                                                      withSpinner(type = 1, color = "#2C3E50"))),
                                                    fluidRow(column(12, uiOutput(outputId = "downloadvis1")))
                                    ),
                                    column(6, fluidRow(column(12, h5("Made using the data below:"),
                                                              DT::dataTableOutput(outputId = "minsplayeddatatable") %>%
                                                                withSpinner(type = 1, color = "#2C3E50"))),
                                           fluidRow(column(12, uiOutput(outputId = "downloadagg1")))) # agg = aggregated data
                                    )
                                    ,
                                    
                                    br(),hr(), br(),
                                    fluidRow(column(6,
                                                    fluidRow(column(12, plotOutput(outputId = "plotpergenre") %>% 
                                                                      withSpinner(type = 1, color = "#2C3E50"))),
                                                    fluidRow(column(12, uiOutput(outputId = "downloadvis2")))
                                    ),
                                    column(6, fluidRow(column(12, h5("Made using the data below:"), 
                                                              DT::dataTableOutput(outputId = "perGendatatable") %>%
                                                                withSpinner(type = 1, color = "#2C3E50"))),
                                           fluidRow(column(12, uiOutput(outputId = "downloadagg2"))) # agg = aggregated data
                                    )
                                    ))
                           
                           ,
                           tabPanel(title = strong("4) Raw Data/Export"),
                                    #### selecting data
                                    fluidRow(column(12, h4(strong("Select the data you want to export"),
                                                           p("(Max 6 hours)")))),
                                    splitLayout(cellWidths = c("25%","75%"),
                                    
                                    wellPanel(                     
                                      fluidRow(
                                        fluidRow(column(12,
                                                        fluidRow(column(12,
                                                          dateRangeInput(inputId = "colldates",
                                                                                label = "Enter start and end dates",
                                                                                weekstart = 1,
                                                                                language = "de",
                                                                                format = "dd/mm/yyyy"))),
                                                        fluidRow(column(6, textInput(inputId = "collstarttime",
                                                                                     label = "Enter start time (hh:mm)",
                                                                                     placeholder = "hh:mm",
                                                                                     value = substr(Sys.time(), 12, 16))),
                                                                 column(6, textInput(inputId = "collendtime",
                                                                                     label = "Enter end time (hh:mm)",
                                                                                     placeholder = "hh:mm",
                                                                                     value = substr(Sys.time()+21540, 12, 16)))),
                                                        fluidRow(column(12,uiOutput(outputId = "message3"))),
                                                        fluidRow(column(6,checkboxGroupInput(inputId = 'selectedvars',
                                                                                             label = strong('Select columns to load'),
                                                                                             # added start_time, end_time because this will show the local time not the UTC time e.g. 2018-12-12T12:12:25Z
                                                                                             choices = c("customerID","genre", "minsplayed", "ym", "ymd", "ymdh", "ymdhm"),
                                                                                             selected = c("customerID", "genre", "minsplayed"))),
                                                                 column(6, br(),actionButton(inputId = "collectdata",
                                                                                             label = "Collect Data",
                                                                                             class = "btn-primary")))
                                                        )
                                                        )
                                        )),
                                    
                                    fluidRow(column(10,offset = 1, uiOutput(outputId = "dataAndButton") %>%
                                                      withSpinner(type = 1, color = "#2C3E50")))
                                    )
                           )))

