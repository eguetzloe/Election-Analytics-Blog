# read in libraries
library(tidyverse)
library(usmap)
library(ggthemes)
library(plotly)
library(gganimate)
library(transformr)
library(gifski)
library(janitor)
library(huxtable)
library(gt)
# read in the csvs and assigned variable names
popvote <- read_csv("data/popvote_1948-2016.csv")
popvotestate <- read_csv("data/popvote_bystate_1948-2016.csv")
economy <- read_csv("data/econ.csv")%>%
  # Dropped NA values
  drop_na() %>%
  # Grouped by year and summarized to find mean national unemployment rates per
  # year
  group_by(year) %>%
  summarize(nationalunemployment = mean(unemployment))
local <- read.csv("data/local.csv") %>%
  # Cleaned names to make work with variables easier
  clean_names() %>%
  # Filtered out counties and cities
  filter(!state_and_area %in% c("Los Angeles County", "New York city")) %>%
  # Renamed for easier work
  rename(state = state_and_area)

# Piped in economy data  
incumbentdata <- economy %>%
  # Joined popvote and economy datasets
  full_join(popvote, by = "year") %>%
  # Filtered for only election years
  filter(year %in% c(1976, 1980, 1984, 1988, 1992, 1996, 2000, 2004, 2008, 2012, 2016, 2020)) %>%
  # Filtered for only incumbent vote share
  filter(incumbent_party == TRUE) %>%
  # Selected needed variables
  select(year, nationalunemployment, pv2p, incumbent, incumbent_party, party) 

# Made basic lm model
basicmodel <- lm(data = incumbentdata, pv2p ~ nationalunemployment)
# Created model summary
summary(basicmodel)
# Created ggplot of linear model
overallincumbencyfx <-
  ggplot(incumbentdata, aes(x=nationalunemployment, y=pv2p,
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
# Saved png
ggsave("figures/overallincumbencyfx.png", height = 6, width = 6)


lmdata <- incumbentdata %>%
  filter(incumbent == TRUE)
  incumbentlm <- lm(data = lmdata, pv2p ~ nationalunemployment)
lm2data <- incumbentdata %>%
    filter(incumbent == FALSE)
  nonincumbentlm <- lm(data = lm2data, pv2p ~ nationalunemployment)
# Took these steps to later change facet titles. I found this hack from this
# data blog:
# https://www.datanovia.com/en/blog/how-to-change-ggplot-facet-labels/#:~:text=(dose%20~%20supp)-,Change%20the%20text%20of%20facet%20labels,labeller%20function%20label_both%20is%20used.
truefalse <- c("Incumbent", "Non-Incumbent Successor")
names(truefalse) <- c("TRUE", "FALSE")

# Created ggplot
successorvsincumbent <- incumbentdata %>%
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
       title = "Effect of Unemployment Based on Incumbency",
       subtitle = "Both vote share and unemployment rate values are measured in percentages.") +
  # Changed theme
  theme_bw() +
  # Changed font sizes for subtitle
  theme(plot.subtitle = element_text(size = 9))
# Saved png
ggsave("figures/successorvsincumbent.png", height = 6, width = 6)


# Created state abbreviations tibble
states <- tibble(state = state.name, abb = state.abb)

# Piped in incumbent dataset used earlier
statedata <- incumbentdata %>%
  # Joined local economy dataset with state vote dataset
  right_join(popvotestate, by = "year") %>%
  # Created a variable 
  mutate(incumbentstatevote = case_when(
    party == "republican" ~ R_pv2p,
    party == "democrat" ~ D_pv2p)) %>%
  # Selected desired variables
  select(year, nationalunemployment, pv2p, incumbent, incumbent_party, state, R_pv2p, D_pv2p, incumbentstatevote) %>%
  # Joined with local economy dataset
  left_join(local, by = c("state", "year")) %>%
  # Grouped by state and year and mutated to create an unemployment by state
  # variable
  group_by(state, year) %>%
  mutate(unemploymentstatepct = mean(unemployed_prce)) %>%
  filter(year > 1975) %>%
  left_join(states, by = "state") %>%
  # Selected desired variables
  select(year, nationalunemployment, pv2p, incumbent, incumbent_party, state, R_pv2p, D_pv2p, unemploymentstatepct, incumbentstatevote, abb) %>%
  # Removed duplicate rows
  distinct()

unemploymentovertime <- statedata %>%
# Created ggplot
ggplot(aes(x = unemploymentstatepct, y = incumbentstatevote)) +
  # Decreased scatterplot point size for cleaner look
  geom_point(size = 0.5) +
  # Created regression line and reduced line thickness
  geom_smooth(method = "lm", size = 0.5) +
  # Set titles
  labs(x = "State unemployment rate", 
       y = "State vote share won by incumbent party", 
       title = "State Incumbent Vote Share Explained by Unemployment", 
       subtitle = "Year: {current_frame}",
       caption = "Both vote share and unemployment rate values are measured in percentages.") +
  # Set theme
  theme_bw() +
  # Set font sizes
  theme(plot.title = element_text(size = 7), plot.subtitle = element_text(size = 6), axis.title = element_text(size = 6), axis.text = element_text(size = 6), plot.caption = element_text(size = 6)) +
  # Set transition style
  transition_manual(year)
# Animated graphic and manually set height, width, and resolution
animate(unemploymentovertime, duration = 15, fps = 20, width = 3, height = 2, units="in", res= 175, renderer = gifski_renderer())
# Saved gif
anim_save("figures/unemploymentovertime.gif")


# Made multiple models for various election years since 1976
year1data <- statedata %>%
  filter(year == 1976)
model1 <- lm(data = year1data, incumbentstatevote ~ unemploymentstatepct)

year2data <- statedata %>%
  filter(year == 1988)
model2 <- lm(data = year2data, incumbentstatevote ~ unemploymentstatepct)

year3data <- statedata %>%
  filter(year == 1996)
model3 <- lm(data = year3data, incumbentstatevote ~ unemploymentstatepct)

year4data <- statedata %>%
  filter(year == 2008)
model4 <- lm(data = year4data, incumbentstatevote ~ unemploymentstatepct)

# Placed all models in a huxtable object
huxtable <- huxreg("1976" = model1, 
                   "1988" = model2, 
                   "1996" = model3, 
                   "2008" = model4,
                   # Set new row titles
                   coefs = c('Intercept'='(Intercept)',
                             'Slope'='unemploymentstatepct'),
                   statistics = c("R-Squared Values" = "r.squared"),
                   # Set confidence intervals
                   ci_level = .95,
                   # Set confidence interval format
                   error_format = '({conf.low} to {conf.high})') %>%
  # Set title
  set_caption('Incumbent Vote Share Explained by Unemployment')
# Print table
huxtable

# Filtering for unemployment data from 2020 only
unemployment2020 <- economy %>%
  filter(year == 2020)
# Created a tibble with unemployment data from 2020, predictions, and confidence
# interval measurements
tibble <- tibble(predictive_variable = "Unemployment",
       unemploymentdata = unemployment2020$nationalunemployment,
       pv2p = predict(basicmodel, unemployment2020),
       lower = predict(basicmodel, unemployment2020, interval = "prediction")[2],
       upper = predict(basicmodel, unemployment2020, interval = "prediction")[3])
# Created a table of predictions
gt(tibble) %>%
  # Removed variable column
  cols_hide(columns = "predictive_variable") %>%
  # Labeled columns
  cols_label(unemploymentdata = "Unemployment Rate", 
             pv2p = "Incumbent Vote Share",
             lower = "2.5 % CI",
             upper = "95% CI") %>%
  # Set decimal point limit
  fmt_number(columns = 2:5, decimals = 2) %>%
  # Set titles and subtitle
  tab_header(title = "Prediction of 2020 Republican Vote Share Based on Unemployment",
             subtitle = "Unemployment rate is the most recent as of September 20, 2020") %>%
  # Set source note
  tab_source_note(source_note = "Source: Bureau of Labor Statistics news release, published September 4, 2020") %>%
  # Set footnote
  tab_footnote(
    footnote = "Unemployment rate and incumbent vote share are measured in percentages",
    locations = cells_body(
      columns = vars(unemploymentdata, pv2p),
      rows = 1))
