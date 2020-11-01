# WEEK 3- POLLING

# Read in libraries
library(tidyverse)
library(ggthemes)
library(gganimate)
library(transformr)
library(gifski)
library(lubridate)
library(scales)
library(huxtable)
library(gt)
# Read in the csvs and assigned variable names
poll_df <- read_csv("data/pollavg_1968-2016.csv")
popvotebystate_df <- read_csv("data/popvote_bystate_1948-2016.csv")
popvote_df <- read.csv("data/popvote_1948-2016.csv")
economy_df <- read_csv("data/econ.csv")
pollbystate_df <- read_csv("data/pollavg_bystate_1968-2016.csv")
poll2016 <- read_csv("data/polls_2016.csv") %>%
  # Lengthened data to format a single polling column with the candidates' names
  # in a separate column
  pivot_longer(cols = starts_with("rawpoll"),
               names_to = "candidate",
               values_to = "rawpoll") %>%
  # Removed third party and independent candidates
  filter(candidate %in% c("rawpoll_clinton", "rawpoll_trump")) %>%
  # Formatted dates through lubridate to make manipulation easier
  mutate(startdate = as.Date(startdate, format = "%m/%d/%Y")) %>%
  mutate(enddate = as.Date(enddate, format = "%m/%d/%Y")) %>%
  # Created month column
  mutate(month = month(startdate)) %>%
  # Created year column
  mutate(year = year(startdate)) %>%
  # Created day column
  mutate(day = mday(enddate)) %>%
  # Created column where months were actually named
  mutate(named_month = case_when(month == 6 ~ "June",
                                 month == 7 ~ "July",
                                 month == 8 ~ "August",
                                 month == 9 ~ "September",
                                 month == 10 ~ "October",
                                 month == 11 ~ "November")) %>%
  mutate(popvote = ifelse(candidate == "rawpoll_clinton", 48.2, 46.1)) %>%
  # Filtered for national polls
  filter(state == "U.S.") %>%
  # Filtered for only polls from 2016
  filter(year == 2016) %>%
  # Selected only necessary columns
  select(state, startdate, enddate, pollster, grade, samplesize, candidate, rawpoll, month, year, day, named_month, popvote)
poll2020 <- read_csv("data/polls_2020.csv") %>%
  # Formatted dates through lubridate to make manipulation easier
  mutate(start_date = as.Date(start_date, format = "%m/%d/%y")) %>%
  mutate(end_date = as.Date(end_date, format = "%m/%d/%y")) %>%
  mutate(month = month(end_date))%>%
  mutate(year = year(end_date)) %>%
  # Filtered only for 2020 polls
  filter(year == 2020) %>%
  # Filtered only for polls predicting Biden or Trump
  filter(answer %in% c("Biden", "Trump")) %>%
  # Selected only necessary columns
  select(year, state, start_date, end_date, answer, pct, month)

# 2016 POLLING OVER TIME ANIMATION

anim2016 <- poll2016 %>%
  # Filtered only for months past May 2016
  filter(month > 5) %>%
  # Formatted raw polls as decimals
  mutate(rawpoll = rawpoll / 100) %>%
  # Renamed candidates
  mutate(candidate = ifelse(candidate == "rawpoll_clinton", 
                            "Clinton", "Trump")) %>%
  # Created ggplot, colored points based on candidate
  ggplot(aes(x = day, y = rawpoll, 
             color = fct_relevel(candidate, "Trump", "Clinton"), 
             label = grade)) +
  # Created scatterplot and set point sizes  
  geom_point(size = 0.8) +
  # Set theme
    theme_bw() +
  # Added regression line and shrunk size
    geom_smooth(method = "lm", size = 0.5) +
  # Set red and blue colors
    scale_color_manual(breaks = c("Trump", "Clinton"),
                     values=c("red", "blue")) +
  # Set titles
    labs(title = "Tracking 2016 Presidential Polls",
         subtitle = "Month: {current_frame}",
         caption = "Polls selected from June onwards since only\nby June was it clear that Donald Trump and \nHillary Clinton would be the nominees.     ",
         x = "Day of the Month",
         y = "Poll Approval",
         color = "") +
  # Set font sizes
  theme(plot.title = element_text(size = 7), 
        plot.subtitle = element_text(size = 6), 
        axis.title = element_text(size = 6), 
        axis.text = element_text(size = 6), 
        plot.caption = element_text(size = 6),
        legend.text = element_text(size = 6)) +
  # Formatted y axis values as percentages
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
  # Manually set transitions since initial animation had months going backwards
  transition_manual(factor(named_month, levels = c('June', 
                                                   'July', 
                                                   'August', 
                                                   'September', 
                                                   'October', 
                                                   'November')))
# Animated graphic and manually set height, width, and resolution
animate(anim2016, duration = 15, fps = 20, width = 3, height = 2, units="in", res= 175, renderer = gifski_renderer())
# Saved animation
anim_save("figures/anim2016.gif")

# 2016 POLLING GRADES BOXPLOT

# Created data frame needed to add lines for popular vote
dummy <- data.frame(candidate = c("Clinton", "Trump"), 
                    popvote = c(.482, .461))
dummy$candidate <- factor(dummy$candidate)
# Changed grade to factor variable for boxplot
poll2016$grade <- as.factor(poll2016$grade)
# Vector needed to reorder x axis ticks
order <- c('A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-')
boxplotpoll <- poll2016 %>%
  # Filtered only for months past May 2016
  filter(month > 5) %>%
  # Filtered out polls with no grade
  drop_na(grade) %>%
  # Formatted raw polls as decimals
  mutate(rawpoll = rawpoll / 100) %>%
  # Renamed candidates
  mutate(candidate = ifelse(candidate == "rawpoll_clinton", 
                            "Clinton", "Trump")) %>%
  # Created ggplot, with x axis reordered to make grades go from best to worst
  # and different colors for different candidates
  ggplot(aes(x = factor(grade, level = order), y = rawpoll, 
             fill = candidate)) +
  # Faceted based on candidate
  facet_grid(.~candidate) +
  # Set theme
  theme_bw() +
  # Created boxplot
  geom_boxplot() +
  # Created horizontal lines for popular vote shares
  geom_hline(data = dummy, aes(yintercept = popvote), 
             linetype = "dashed") +
 # Removed legend
  theme(legend.position = "none",
 # Set font size for subtitle text
        plot.subtitle = element_text(size = 9)) +
  # Set red and blue colors for Trump and Clinton
  scale_fill_manual(breaks = c("Trump", "Clinton"),
                     values=c("red", "blue")) +
  # Formatted y axis values as percentages
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  # Set titles
  labs(title = "2016 Presidential Polls by FiveThirtyEight Grades",
       subtitle = "Dotted lines represent the actual shares of the popular vote gained by Trump and \nClinton in the 2016 election.",
       caption = "There is a flat line for C-graded polls because there was only one poll that received that grade.",
       x = "FiveThirtyEight Grade",
       y = "Poll Approval")
# Saved image
ggsave("figures/boxplotpoll.png", height = 6, width = 12)

# USING POLLING AND UNEMPLOYMENT AS PREDICTORS

# Created new joined dataset with popular vote and economy csvs
econ_and_polls_df <- poll_df %>%
  left_join(popvote_df, by = c("year", "party")) %>% 
  # Filtered specifically for quarter 2 data
  left_join(economy_df %>% filter(quarter == 2), 
            by = "year") %>% 
  # Mutated to properly format quarter 1 and 2 data from the join
  mutate(id = row_number()) %>%
  select(year, weeks_left, avg_support, pv2p, incumbent_party, unemployment)

# Data for first model- followed same process for all models below
model1data <- econ_and_polls_df %>%
  # Filtered for under 3 weeks
  filter(weeks_left <= 2) %>%
  # Filtered for only incumbent party
  filter(incumbent_party == TRUE)

# Created model with average poll support and unemployment explaining popular
# vote share
model1 <- lm(data = model1data, formula = pv2p ~ avg_support + unemployment)

model2data <- econ_and_polls_df %>%
  filter(weeks_left %in% c(3, 4, 5)) %>%
  filter(incumbent_party == TRUE)

model2 <- lm(data = model2data, formula = pv2p ~ avg_support + unemployment)

model3data <- econ_and_polls_df %>%
  filter(weeks_left %in% c(6, 7, 8, 9, 10)) %>%
  filter(incumbent_party == TRUE)

model3 <- lm(data = model3data, formula = pv2p ~ avg_support + unemployment)

model4data <- econ_and_polls_df %>%
  filter(weeks_left %in% c(11, 12, 13, 14, 15, 16, 17, 18, 19, 20)) %>%
  filter(incumbent_party == TRUE)

model4 <- lm(data = model4data, formula = pv2p ~ avg_support + unemployment)

model5data <- econ_and_polls_df %>%
  filter(weeks_left > 21) %>%
  filter(incumbent_party == TRUE)

model5 <- lm(data = model5data, formula = pv2p ~ avg_support + unemployment)

# Placed all models in a huxtable object
huxreg("Under 3 Weeks" = model1, 
       "3-5 Weeks" = model2,
       "6-10 Weeks" = model3,
       "11-20 Weeks" = model4, 
       "Over 20 Weeks" = model5,
       # Set new row titles
       coefs = c('Intercept'='(Intercept)',
                 'Average Poll Support'='avg_support',
                 'Unemployment' = 'unemployment'),
       # Renamed statistics
       statistics = c("Number of Observations" = "nobs",
                      "R-Squared Values" = "r.squared"),
       # Set confidence intervals
       ci_level = .95,
       # Set confidence interval format
       error_format = '({conf.low} to {conf.high})') %>%
  # Set title
  set_caption('Incumbent Vote Share Explained by Average Poll Support and Unemployment')

# CREATING 2020 PREDICTIONS

# Joined 2020 poll dataset with the economy dataset
econ_and_polls_2020_df <- poll2020 %>%
  # Mutated to create incumbent party column within 2020 dataset, necessary for
  # later predictions
  mutate(incumbent_party = ifelse(answer == "Trump", 
                           TRUE, FALSE)) %>%
  # Filtered for polls from only June onwards
  filter(month > 6) %>%
  # Averaged poll results and created avg_support column needed to 
  # join datasets
  mutate(avg_support = mean(pct)) %>%
  # Filtered specifically for quarter 2 data
  left_join(economy_df %>% filter(quarter == 2), 
            by = "year") %>%
  # Filtered for only 2020 polls
  filter(year == 2020) %>%
  # Selected desired variables
  select(year, incumbent_party, avg_support, unemployment, month) %>%
  # Joined with previous dataset
  full_join(econ_and_polls_df, 
            by = c("year", "avg_support", "unemployment", 
                   "incumbent_party")) %>%
  # Filtered for only incumbent party vote share
  filter(incumbent_party == TRUE) %>%
  # Grouped by year
  group_by(year) %>%
  # Averaged poll results
  mutate(avg_support = mean(avg_support)) %>%
  # Selected desired variables
  select(year, avg_support, unemployment, pv2p, incumbent_party) %>%
  # Removed identical columns
  distinct()

# Filtered out 2020 data for initial model
non2020data <- econ_and_polls_2020_df %>%
  filter(year != 2020)

# Created model
model2020 <-lm(data = non2020data, 
   formula = pv2p ~ avg_support + unemployment)
# Called summary to examine model
summary(model2020)

# Created predictions
pred2020 <- predict(model2020, econ_and_polls_2020_df, interval = 'confidence')
# Made prediction dataframe
pred_df <- as.data.frame(pred2020)
# Moved prediction values into original dataset
econ_and_polls_2020_df$pred <- pred_df$fit
econ_and_polls_2020_df$lower <- pred_df$lwr
econ_and_polls_2020_df$upper <- pred_df$upr
# Filtering for 2020 predictions
modelpred <- econ_and_polls_2020_df %>%
  filter(year == 2020) %>%
  select(year, pred, lower, upper)

# Created gt table
pollunemploymentgt <- gt(modelpred) %>%
  # Renamed columns
  cols_label(year = "Year",
             pred = "Incumbent Vote Share",
             lower = "2.5 % CI",
             upper = "95% CI") %>%
  # Set title
  tab_header(title = "Prediction of Republican Vote Share Based on Polling and Unemployment") %>%
  # Set decimal point limit
  fmt_number(columns = 2:4, decimals = 2)

gtsave(pollunemploymentgt, "figures/pollgt.png")
