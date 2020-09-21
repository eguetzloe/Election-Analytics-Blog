# read in libraries
library(tidyverse)
library(usmap)
library(ggthemes)
library(plotly)
library(gganimate)
library(transformr)
library(gifski)
library(janitor)
# read in the csvs and assigned variable names
popvote <- read_csv("data/popvote_1948-2016.csv")
popvotestate <- read_csv("data/popvote_bystate_1948-2016.csv")
economy <- read_csv("data/econ.csv")%>%
  # Dropped NA values
  drop_na() %>%
  # Grouped by year and summarized to find mean national unemployment rates per
  # year
  group_by(year) %>%
  summarize(nationalunemployment = mean(unemployment)) %>%
local <- read.csv("data/local.csv") %>%
  # Cleaned names to make work with variables easier
  clean_names() %>%
  # Filtered out counties and cities
  filter(!state_and_area %in% c("Los Angeles County", "New York city")) %>%
  # Renamed for easier work
  rename(state = state_and_area)
# Joined three datasets
localdata <- popvotestate %>% 
  left_join(popvote, by = "year") %>% 
  # Filtered because I am only interested in exploring incumbency impacts
  filter(incumbent == TRUE) %>% 
  left_join(local, by = c("state", "year")) %>%
  #mutate(pv2p = case_when(
    #party == "republican" ~ R_pv2p,
    #party == "democrat" ~ D_pv2p
 # ))

# Piped in local dataset  
incumbencydata <- local %>%
  # Grouped by state and year and then mutated to create an unemployment by
  # state variable
  group_by(state, year) %>%
  mutate(unemploymentstatepct = mean(unemployed_prce)) %>%
  # Joined economy dataset
  left_join(economy, by = "year") %>%
  # Joined popvote dataset
  left_join(popvote, by = "year") %>%
  # Selected relevant datasets
  select(state, year, unemploymentstatepct, nationalunemployment, pv2p, incumbent, incumbent_party) %>%
  # Filtered for only incumbent party vote share
  filter(incumbent_party == TRUE) %>%
  filter(year == 1976)

# Made basic lm model
lm(data = incumbencydata, pv2p ~ nationalunemployment)
# Created ggplot of linear model
ggplot(incumbencydata, aes(x=nationalunemployment, y=pv2p,
           label=year)) + 
  # Plotted points via text
  geom_text() +
  # Created regression line
  geom_smooth(method="lm", se = FALSE) +
  # Set labels
  labs(x = "National unemployment rate", 
  y = "Incumbent party popular vote share",
  title = "Incumbent Party Vote Share Explained by Unemployment",
  subtitle = "Both vote share and unemployment rate values are measured in percentages.") +
  # Set theme
  theme_bw() +
  # Changed font sizes
  theme(plot.title = element_text(size = 13), 
        plot.subtitle = element_text(size = 9))

# Took these steps to later change facet titles. I found this hack from this
# data blog:
# https://www.datanovia.com/en/blog/how-to-change-ggplot-facet-labels/#:~:text=(dose%20~%20supp)-,Change%20the%20text%20of%20facet%20labels,labeller%20function%20label_both%20is%20used.
truefalse <- c("Incumbent", "Non-Incumbent Successor")
names(truefalse) <- c("TRUE", "FALSE")

# Created ggplot
incumbencydata %>%
  ggplot(aes(x=nationalunemployment, y=pv2p,
                             label=year)) + 
  # Faceted by incumbent or party successor
  facet_wrap(~incumbent, labeller = labeller(incumbent = truefalse)) +
  # Changed size of year text
  geom_text(size = 2.5) +
  # Created regression line
  geom_smooth(method="lm", se = FALSE) +
  # Set labels
  labs(x = "National unemployment rate", 
       y = "Incumbent party popular vote share", 
       title = "Effect of the Economy Based on Incumbency",
       subtitle = "Both vote share and unemployment rate values are measured in percentages.") +
  # Changed theme
  theme_bw() +
  # Changed font sizes for subtitle
  theme(plot.subtitle = element_text(size = 9))