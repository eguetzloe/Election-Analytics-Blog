# WEEK 4- INCUMBENCY

# Read in libraries
library(tidyverse)
library(readxl)
library(usmap)
library(ggthemes)
library(gganimate)
library(transformr)
library(gifski)
library(lubridate)
library(scales)
library(huxtable)
library(janitor)
library(ggrepel)
library(gt)
# Read in csvs
gallup <- read_csv('data/approval_gallup_1941-2020.csv')
popvotestate <- read_csv('data/popvote_bystate_1948-2016.csv')
popvote <- read_csv('data/popvote_1948-2016.csv')
pollbystate <- read_csv('data/pollavg_bystate_1968-2016.csv')
poll <- read_csv('data/pollavg_1968-2016.csv')
poll2020 <- read_csv('data/polls_2020.csv')
economy <- read_csv('data/econ.csv') %>%
  clean_names()
state_abbs <- read_csv('data/state_abb.csv')

# CREATING TIME FOR CHANGE VARIABLES

# First variable is net approval, so I started there
net_app <- gallup %>%
  # Mutated to find net approval rating
  mutate(netapp = approve - disapprove) %>%
  # Created a month variable
  mutate(month = month(poll_enddate)) %>%
  # Filtered for June since the TFC model only examines the last Gallup poll in
  # June
  filter(month == 6) %>%
  # Filtered for only election years
  filter(year %in% c(1948, 1952, 1956, 1960, 1964, 1968, 1972, 1976, 
                     1980, 1984, 1988, 1992, 1996, 2000, 2004, 2008, 
                     2012, 2016, 2020)) %>%
  # Grouped by year
  group_by(year) %>%
  # Ordered years from earliest to latest
  arrange(desc(poll_enddate)) %>%
  # Selected desired columns and rows
  slice(1) %>%
  select(year, netapp)

# Next variable is Quarter 2 GDP Growth
g2gdp <- economy %>%
  # Filtered for quarter 2 GDP growth
  filter(quarter == 2) %>%
  # Filtered for election years
  filter(year %in% c(1948, 1952, 1956, 1960, 1964, 1968, 1972, 1976, 
                     1980, 1984, 1988, 1992, 1996, 2000, 2004, 2008, 
                     2012, 2016, 2020)) %>%
  # Selected desired rows
  select(year, gdp_growth_qt)

# Final variable in model is presence or absence of incumbency
term1inc <- tibble(
  # Created election year variable
  "year" = c(1948, 1952, 1956, 1960, 1964, 1968, 1972, 1976, 1980,
             1984, 1988, 1992, 1996, 2000, 2004, 2008, 2012, 2016, 2020),
  # Created incumbency variable (attempted to use filters from popvote data but
  # couldn't find a super easy way of doing that)
  "incumbent" = c(1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1))

# Created incumbent popular vote variable
popvote_tfc <- popvote %>%
  # Filtered for only incumbent party
  filter(incumbent_party == TRUE) %>%
  # Renamed pv2p
  rename(inc_pv2p = pv2p) %>%
  # Selected desired columns
  select(year, inc_pv2p)

# Joined all the datasets!
tfc_df <- net_app %>%
  inner_join(g2gdp, by = 'year') %>%
  inner_join(term1inc, by = 'year') %>%
  full_join(popvote_tfc, by = 'year')

# EXPLORING PREDICTORS SEPARATELY

# Piped in economy data  
predictordata <- economy %>%
  # Joined popvote and economy datasets
  full_join(popvote, by = "year") %>%
  # Filtered for only election years
  filter(year %in% c(1976, 1980, 1984, 1988, 1992, 1996, 2000, 2004, 
                     2008, 2012, 2016, 2020)) %>%
  # Filtered for quarter 2 economic data
  filter(quarter == 2) %>%
  # Selected needed variables
  select(year, gdp_growth_qt, pv2p, incumbent, incumbent_party, party) %>%
  # Joined Gallup data
  inner_join(net_app, by = 'year') %>%
  # Mutated to change facet titles for graphics
  mutate(incumbent_party = ifelse(incumbent_party == "TRUE", 
                            "Incumbent Party", "Challenger")) %>%
  # Set pv2p as decimals
  mutate(pv2p = pv2p / 100) %>%
  # Dropped NAs
  drop_na(incumbent_party)

# Created ggplot of GDP model
gdpfx <-
  # Made years labels
  ggplot(predictordata, aes(x = gdp_growth_qt, y = pv2p,
                            label = year)) + 
  # Faceted based on incumbency
  facet_wrap(~incumbent_party) +
  # Plotted points via text
  geom_text_repel() +
  # Created regression line
  geom_smooth(method="lm", se = FALSE) +
  # Set labels
  labs(x = "Quarter 2 GDP Growth", 
       y = "Popular Vote Share",
       title = "2 Party Vote Share Explained by Quarter 2 GDP Growth") +
  # Set theme
  theme_bw() +
  # Changed font sizes
  theme(plot.title = element_text(size = 13), 
        plot.subtitle = element_text(size = 9)) +
  # Set percent format
  scale_y_continuous(labels = percent_format(accuracy = 1))

# Saved image
ggsave("figures/gdpfx.png", height = 6, width = 12)

netappfx <-
  # Made ggplot of approval model, with years as labels
  ggplot(predictordata, aes(x = netapp, y = pv2p,
                            label = year)) + 
  # Faceted by incumbent party
  facet_wrap(~incumbent_party) +
  # Plotted points via text
  geom_text_repel() +
  # Created regression line
  geom_smooth(method="lm", se = FALSE) +
  # Set labels
  labs(x = "Net Approval Rating of Incumbent President", 
       y = "Popular Vote Share",
       title = "2 Party Vote Share Explained by Net Approval Rating",
       subtitle = "Net approval rating of incumbent president is calculated from the June Gallup poll \nof each election year.") +
  # Set theme
  theme_bw() +
  # Changed font sizes
  theme(plot.title = element_text(size = 13), 
        plot.subtitle = element_text(size = 9)) +
  # Set percent format
  scale_y_continuous(labels = percent_format(accuracy = 1))

# Saved image
ggsave("figures/netappfx.png", height = 6, width = 12)

# MAKING THE TIME FOR CHANGE MODEL

tfcdata <- tfc_df %>%
  filter(year != 2020)

tfcmodel <- lm(data = tfcdata, inc_pv2p ~ netapp + gdp_growth_qt + incumbent)

huxtable <- huxreg("Time For Change Model" = tfcmodel,
       # Set new row titles
       coefs = c('Intercept'='(Intercept)',
                 'Net Approval Rating'='netapp',
                 '2nd Quarter GDP Growth' = 'gdp_growth_qt',
                 'Incumbency' = 'incumbent'),
       # Renamed statistics
       statistics = c("Number of Observations" = "nobs",
                      "R-Squared Values" = "r.squared"),
       # Set confidence intervals
       ci_level = .95,
       # Set confidence interval format
       error_format = '({conf.low} to {conf.high})') %>%
  # Set title
  set_caption('Incumbent Vote Share Explained by Average Poll Support and 2nd Quarter GDP Growth')

# TFC PREDICTIONS FOR 2020

# Creating predictions from model
pred2020 <- predict(tfcmodel, tfc_df, interval = 'confidence')
# Making predictions into dataframe
pred_df <- as.data.frame(pred2020)
# Creating confidence intervals
tfc_df$pred <- pred_df$fit
tfc_df$lower <- pred_df$lwr
tfc_df$upper <- pred_df$upr
# Creating 2020 prediction
tfcpred <- tfc_df %>%
  filter(year == 2020) %>%
  select(year, pred, lower, upper)

gtdata <- gt(tfcpred)

tfcgt <- gtdata %>%
  # Renamed columns
  cols_label(pred = "Incumbent Vote Share",
             lower = "2.5 % CI",
             upper = "95% CI") %>%
  # Set title
  tab_header(title = "Prediction of 2020 Republican Vote Share Based on Time For Change Model") %>%
  # Set decimal point limit
  fmt_number(columns = 2:4, decimals = 2)

gtsave(tfcgt, "figures/tfcgt.png")
