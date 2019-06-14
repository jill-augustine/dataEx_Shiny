# dataEx_Shiny

This web application was made by [Jillian Augustine](https://jill-augustine.github.io/) using [Shiny](https://shiny.rstudio.com/) and several other packages.

This app can be used as a template for data exploration from parquet files. Parquet files to be explored should be located in the ja_dataEx_data folder. 

The setup of this data pipeline allows you to query hive tables and store the query results using the file ja_dates2parquet_v2.py. This file also automatically generates an email once the data has been successfully compiled and cleans up the folder removing any unnecessary files. 

More information can be found [here](https://jill-augustine.github.io/data-exploration-with-shiny.html)