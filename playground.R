shiny::runApp("/Users/jillianaugustine/Documents/GitHub/dataEx_Shiny/dataEx_app_split", launch.browser = TRUE)

name <- "/Users/jillianaugustine/Documents/GitHub/dataEx_Shiny/dataEx_app_split"
endname <- name %>% stringr::str_extract("[^/]*$")
restname <- name %>% stringr::str_sub(end = -(nchar(endname)+1))

sc <- spark_connect(master = "local[3]", app_name = "dataEx", config = spark_config())
loc <- spark_read_parquet(sc, name="dfloc",
                          path=paste0("ja_dataEx_data/", "eg01"))

themedataEx <- theme(text = element_text(face="bold"),
                     plot.title = element_text(colour = "grey20", hjust = 0.5, size = 16),
                     axis.title = element_text(size=14, colour = "grey20"),
                     axis.text = element_text(size=11, colour = "grey30"),
                     legend.title = element_text(size=14),
                     legend.text = element_text(size=12)
)

loc %>% filter(ymd == "2019-04-12")

library(stringr)
library(ggplot2)
library(dplyr)

names <- sample(fruit, 6)
numbers <- round(runif(1000, 0,100))

df <- tibble(name = sample(names,1000, replace = TRUE), nums = numbers)
fruit_levels <- df %>% arrange(desc(nums)) %>% pull(name) %>% unique()
df <- df %>% mutate(name = factor(name, levels = fruit_levels))

df %>%
  ggplot(aes(nums, fill = name)) +
  geom_bar()

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

df %>% group_by(name)%>%  summarise(tot = sum(nums)) %>%
  ggplot(aes(x = 1, y = tot, fill = name, colour = "1")) +
  geom_col() + 
    theme_grey() +
  labs(title = 'Here is the title', x = "Here is the x axis", y = 'Total Minutes Played') +
  scale_color_manual(values = c("1"= "grey50"), guide = FALSE ) +
  scale_fill_brewer(palette = "Greens", direction = -1) +
ja_theme_greylines
        
library(RColorBrewer)
display.brewer.all(n=6, type="all", select=NULL, exact.n=TRUE, colorblindFriendly=TRUE)
