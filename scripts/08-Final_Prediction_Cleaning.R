# WEEK 8- FINAL PREDICTION DATA CLEANING

# DATA CLEANING

# Read in libraries
library(tidyverse)
library(janitor)
library(lubridate)
library(scales)

# Read in csvs for national prediction
polls <- read_csv("data/pollavg_1968-2016.csv")
poll_2020 <- read_csv("data/president_polls.csv")
popvote <- read_csv("data/popvote_1948-2016.csv")
economy <- read_csv("data/econ.csv")
gallup <- read_csv("data/approval_gallup_1941-2020.csv")

# Read in csvs for state predictions
polls_state <- read_csv("data/pollavg_bystate_1968-2016.csv")
popvote_state <- read_csv("data/popvote_bystate_1948-2016.csv")
local <- read_csv("data/local.csv")
electors <- read_csv("data/ec_1952-2020.csv")

# NATIONAL DATA CLEANING

# Cleaning for 2020 National Polls:
polls_2020_clean <- poll_2020 %>% 
  # Filtered out state polls
  filter(is.na(state)) %>% 
  # Used lubridate to format dates
  mutate(start_date = as.Date(end_date, "%m/%d/%y")) %>% 
  mutate(end_date = as.Date(end_date, "%m/%d/%y")) %>% 
  # Filtered out polls from before June 2020
  filter(start_date >= "2020-06-01") %>%
  group_by(candidate_party) %>% 
  # Took average of polls for each year and party in every state
  mutate(avg_support = mean(pct)) %>% 
  # Ungrouped
  ungroup() %>%
  # Filtered for only Democrat and Republican candidates
  filter(candidate_party %in% c("DEM", "REP")) %>% 
  # Renamed Democrat and Republican parties
  mutate(candidate_party = case_when(
    candidate_party == "DEM" ~ "democrat",
    candidate_party == "REP" ~ "republican"
  )) %>% 
  # Renamed party column
  rename(party = candidate_party) %>%
  # Renamed cycle as year
  rename(year = cycle) %>%
  # Selected desired columns
  select(year, party, avg_support) %>%
  # Removed repetitive rows
  distinct()
# Added to clean data folder
# write_csv(polls_2020_clean, "clean-data/president_polls_clean.csv")

# Cleaning for Past Elections:
popvote_clean <- popvote %>% 
  # Grouped by party
  group_by(party) %>% 
  # Adding in previous year's popular vote
  mutate(last_pv2p = lag(pv2p, order_by = year)) %>% 
  # Ungrouped
  ungroup() %>% 
  # Dropped NAs
  drop_na(last_pv2p) %>% 
  # Selected desired columns
  select(year, party, winner, pv2p, last_pv2p, incumbent, incumbent_party)
# Added to clean data folder
# write_csv(popvote_clean, "clean-data/popvote_1948-2016_clean.csv")  

# Cleaning for Economic Data:
economy_clean <- economy %>% 
  # Selecting desired columns
  select(year, quarter, GDP_growth_qt, unemployment) %>% 
  # Dropped NAs
  drop_na() %>% 
  # Filtered for the year before election years
  filter((year + 1) %% 4 == 0) %>% 
  # Grouped by year
  group_by(year) %>% 
  # Found average GDP growth and unemployment per year before election year
  mutate(prev_avg_gdp_growth = mean(GDP_growth_qt)) %>%
  mutate(prev_avg_unemployment = mean(unemployment)) %>%
  # Ungrouped
  ungroup() %>%
  # Mutated year to equal the year following for easier joining
  mutate(year = (year + 1)) %>%
  # Selected desired variables
  select(year, prev_avg_gdp_growth, prev_avg_unemployment) %>%
  # Removed identical rows
  distinct()
# Added to clean data folder
# write_csv(economy_clean, "clean-data/econ_clean.csv")  

# Cleaning Job Approval Data:
gallup_clean <- gallup %>% 
  # Formatted dates using lubridate to make them easier to manipulate
  mutate(year = as.numeric(format(as.Date(poll_startdate, format = "%Y-%m-%d"), "%Y")),
         month = as.numeric(format(as.Date(poll_startdate, format = "%Y-%m-%d"), "%m"))) %>% 
  # Filtered only for polls in election years and between the months of January
  # through October
  filter(year %% 4 == 0,
         month %in% 1:10) %>% 
  # Grouped by year
  group_by(year) %>% 
  # Found average job approval level
  summarize(job_approval = mean(approve), .groups = "drop")
# Added to clean data folder
# write_csv(gallup_clean, "clean-data/approval_gallup_1941-2020_clean.csv")

# STATE DATA CLEANING

# Cleaning for Past Polls:
polls_clean <- polls %>% 
  # Filtered for only polls from 25 weeks before Election Day or later
  filter(weeks_left < 25) %>% 
  # Grouped by year and party
  group_by(year, party) %>% 
  # Took average of polls for each year and party
  summarize(avg_support = mean(avg_support), .groups = "drop")
# Added to clean data folder
#write_csv(polls_clean, "clean-data/pollavg_1968-2016_clean.csv")

# Cleaning for Past State Polls:
polls_state_clean <- polls_state %>% 
  # Filtered for only polls from 25 weeks before Election Day or later
  filter(weeks_left < 25,
         # Removed Maine and Nebraska (states that allocate electors based on
         # popular vote)
         !state %in% c("ME-1", "ME-2", "NE-1", "NE-2", "NE-3")) %>%
  # Grouped by year, state, and party
  group_by(year, state, party) %>% 
  # Took average of polls for each year and party in every state
  summarize(avg_support = mean(avg_poll), .groups = "drop") %>% 
  # Removed polls in years where state polls were less consistent
  filter(year >= 1988)
# Added to clean data folder
# write_csv(polls_state_clean, "clean-data/pollavg_bystate_1968-2016_clean.csv")

# Cleaning for 2020 State Polls:
polls_2020_state_clean <- poll_2020 %>% 
  # Filtered out NA values
  filter(!is.na(state),
         # Removed Maine and Nebraska (states that allocate electors based on
         # popular vote)
         !state %in% c("Maine CD-1", "Maine CD-2", "Nebraska CD-1", "Nebraska CD-2")) %>% 
  # Used lubridate to format dates
  mutate(start_date = as.Date(end_date, "%m/%d/%y")) %>% 
  mutate(end_date = as.Date(end_date, "%m/%d/%y")) %>% 
  # Filtered out polls from before June 2020
  filter(start_date >= "2020-06-01") %>% 
  # Grouped by party and state
  group_by(candidate_party, state) %>% 
  # Took the mean of polls for each candidate in each state
  summarize(avg_support = mean(pct), .groups = "drop") %>% 
  # Filtered for only major 2 parties
  filter(candidate_party %in% c("DEM", "REP")) %>% 
  # Renamed parties
  mutate(candidate_party = case_when(
    candidate_party == "DEM" ~ "democrat",
    candidate_party == "REP" ~ "republican"
  )) %>% 
  # Renamed party column
  rename(party = candidate_party)
# Added to clean data folder
 #write_csv(polls_2020_state_clean, "clean-data/president_polls_state_clean.csv")

# Cleaning for Past Elections:
popvote_state_clean <- popvote_state %>% 
  # Pivoted data to create party column and separate D and R vote columns
  pivot_longer(R_pv2p:D_pv2p, names_to = "party", values_to = "pv2p") %>% 
  # Renamed Democrat and Republican columns
  mutate(party = case_when(
    party == "D_pv2p" ~ "democrat",
    party == "R_pv2p" ~ "republican"
  )) %>% 
  # Grouped by state and party
  group_by(state, party) %>% 
  # Created previous year popular vote column
  mutate(last_pv2p = lag(pv2p, order_by = year)) %>% 
  # Ungrouped
  ungroup() %>% 
  # Dropped NAs
  drop_na(last_pv2p) %>% 
  # Joined with national popular vote dataset
  left_join(popvote %>% 
              select(year, party, winner, incumbent, incumbent_party), by = c("year", "party")) %>% 
  # Filtered out years where state polls were sparser
  filter(year >= 1988)
# Added to clean data folder
# write_csv(popvote_state_clean, "clean-data/popvote_bystate_1948-2016_clean.csv")  

# Cleaning Electoral College data:
electors_clean <- electors %>% 
  # Filtered for 2020
  filter(year == 2020,
         # Removed total
         state != "Total") %>% 
  # Mutated for DC
  mutate(electors = case_when(
    state == "D.C." ~ 3,
    TRUE ~ electors
  ))
# Added to clean data folder
# write_csv(electors_clean, "clean-data/ec_2020_clean.csv")

# Cleaning local economic data
local_clean <- read_csv("data/local.csv") %>%
  # Cleaned column names
  clean_names() %>%
  # Filtered for only years prior to election years
  filter((year + 1) %% 4 == 0) %>%
  # For easier data manipulation later, added 1 year
  mutate(year = (year + 1)) %>%
  # Renamed state column
  rename(state = state_and_area) %>%
  # Removed counties or cities
  filter(!state %in% c("Los Angeles County", "New York city")) %>%
  # Grouped by year and state
  group_by(year, state) %>%
  # Took mean unemployment per state in the years before an election year
  summarize(prev_avg_unemployment = mean(unemployed_prce), .groups = "drop")

# Added to clean data folder
# write_csv(local_clean, "clean-data/local.csv")

# Much of this data cleaning was done in collaboration with other students in
# Gov 1347 and on the Harvard Political Review's Data Journalism team. Thanks to
# Miro Bergam, Kodi Obika, Dominic Skinnion, and Yao Yu for help on this portion
# of the project.