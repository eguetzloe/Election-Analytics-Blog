# WEEK 5- ADVERTISING

# Read in libraries
library(tidyverse)
library(readxl)
library(ggthemes)
library(lubridate)
library(scales)
library(huxtable)
library(janitor)
library(geofacet)
# Read in csvs
popvotestate <- read_csv('data/popvote_bystate_1948-2016.csv')
pollbystate <- read_csv('data/pollavg_bystate_1968-2016.csv')
poll2020 <- read_csv('data/polls_2020.csv')
pollavgs2020 <- read_csv('data/presidential_poll_averages_2020.csv')
ad_campaigns <- read.csv('data/ad_campaigns_2000-2012.csv')
ad_creative <- read.csv('data/ad_creative_2000-2012.csv')
ads_2020 <- read.csv('data/ads_2020.csv')
vep <- read.csv('data/vep_1980-2016.csv')
poll_pvstate_vep <- popvotestate %>% 
  mutate(D_pv = D/total) %>% 
  mutate(R_pv = R/total) %>%
  inner_join(pollbystate %>%  filter(weeks_left == 5)) %>% 
  left_join(vep)

# Setting seed for replication
set.seed(1347)

# TOP AD ISSUES BY PARTY IN 2012

# Cleaning Democrat data for plot
demadissues2012 <- party_issues2012 <- ad_campaigns %>%
  # Filtered for 2012
  filter(cycle == 2012) %>%
  # Joined creative data
  left_join(ad_creative) %>%
  # Grouped by year, ad issue, and party
  group_by(cycle, ad_issue, party) %>% 
  # Mutated to find the total number of ads run by each party on various issues
  mutate(total_ads = n()) %>%
  # Filtered out NAs
  drop_na(ad_issue) %>%
  # Filtered out other ads
  filter(ad_issue != "Other") %>%
  # Ungrouped
  ungroup() %>%
  # Pivoted wider to specifically get Dem column
  pivot_wider(names_from = party, values_from = total_ads) %>%
  # Selected needed columns
  select(cycle, ad_issue, democrat) %>%
  # Got rid of identical rows
  distinct() %>%
  # Arranged by greatest to least
  arrange(desc(democrat)) %>%
  # Selected top 10 rows
  head(10)

# Cleaning Republican data for plot
repadissues2012 <- party_issues2012 <- ad_campaigns %>%
  # Filtered for 2012
  filter(cycle == 2012) %>%
  # Joined creative data
  left_join(ad_creative) %>%
  # Grouped by year, ad issue, and party
  group_by(cycle, ad_issue, party) %>% 
  # Mutated to find the total number of ads run by each party on various issues
  mutate(total_ads = n()) %>%
  # Filtered out NAs
  drop_na(ad_issue) %>%
  # Filtered out other ads
  filter(ad_issue != "Other") %>%
  # Ungrouped
  ungroup() %>%
  # Pivoted wider to specifically get Republican column
  pivot_wider(names_from = party, values_from = total_ads) %>%
  # Selected only needed columns
  select(cycle, ad_issue, republican) %>%
  # Got rid of identical rows
  distinct() %>%
  # Arranged by greatest to least
  arrange(desc(republican)) %>%
  # Selected top 10 rows
  head(10)

# Joined Dem and Rep dfs
adissues2012 <- demadissues2012 %>%
  # Joined by cycle and issue
  full_join(repadissues2012, by =  c("cycle", "ad_issue")) %>%
  # Renamed party columns to capitalizefor graph
  rename("Democrat" = "democrat") %>%
  rename("Republican" = "republican") %>%
  # Pivoted longer to recreate party and total ads columns
  pivot_longer(cols = c("Republican", "Democrat"), names_to = "party", values_to = "total_ads") %>%
  # Pivoted wider to ad issue columns to fix weird formatting of a variable name
  pivot_wider(names_from = ad_issue, values_from = total_ads) %>%
  # Renamed women's health column to be properly formatted for plot legend
  rename("Women's Health" = "Womenâ€™s Health") %>%
  # Pivoted back to original format
  pivot_longer(cols = "Employment/Jobs":"China", names_to = "ad_issue", values_to = "total_ads") %>%
  # Dropped NA values
  drop_na(total_ads) %>%
  # Mutated to order ad issues to simulate ROYGBIV descending order in ggplot
  mutate(ad_issue = fct_reorder(ad_issue, total_ads, .desc = TRUE))

# Made ggplot
adissues2012plot <- ggplot(adissues2012, aes(x = factor(-total_ads), y = total_ads, fill = ad_issue)) +
  # Faceted by party, removed x axis labels, and dropped factors needed earlier
  # for properly formatting issues from the most to the least per party
  facet_wrap(~party, scales = "free_x", drop = TRUE) +
  # Created bar plot
  geom_col() +
  # Changed x and y axis titles and plot title
  labs(x = "Ad Issue",
       y = "Number of Ads",
       title = "Top Ten Issues in 2012 Ads by Party") +
  # Set theme
  theme_bw() +
  # Removed x axis text and ticks
  theme(axis.text.x = element_blank(), 
        axis.ticks.x = element_blank(),
        # Removed legend title
        legend.title = element_blank(),
        # Changed title font face
        plot.title = element_text(face = "bold", size = 20))

# Saving plot
# ggsave("figures/adissues2012plot.png", height = 6, width = 12)

# GA MODEL BASED ON FTE POLLS ONLY

# Get VEP in GA for 2016
vepga <- as.integer(vep$VEP[vep$state == "Georgia" & vep$year == 2016])

# Create polling and pv2p data for relevant years
ga_r <- poll_pvstate_vep %>% 
  filter(state=="Georgia", party=="republican")
ga_d <- poll_pvstate_vep %>% 
  filter(state=="Georgia", party=="democrat")

# Fit Republican and Democrat models
ga_r_glm <- glm(cbind(R, VEP-R) ~ avg_poll, ga_r, family = binomial)
ga_d_glm <- glm(cbind(D, VEP-D) ~ avg_poll, ga_d, family = binomial)

# Find latest avg poll for each candidate
gapoll <- pollavgs2020 %>%
  # Filter for ga
  filter(state == "Georgia") %>%
  # Filter for Biden and Trump
  filter(candidate_name %in% c("Joseph R. Biden Jr.", "Donald Trump")) %>%
  # Rename percent column
  rename(pct = pct_estimate) %>%
  # Filtered for most recent poll
  filter(modeldate == "10/10/2020")

# Get predicted draw probabilities for D and R
prob_rvote_ga_2020 <- predict(ga_r_glm, newdata = data.frame(avg_poll = 46.9), type="response")[[1]]
prob_dvote_ga_2020 <- predict(ga_d_glm, newdata = data.frame(avg_poll= 47.1), type="response")[[1]]

# Get predicted distribution of draws from the population
sim_rvotes_ga_2020 <- rbinom(n = 10000, size = vepga, prob = prob_rvote_ga_2020)
sim_dvotes_ga_2020 <- rbinom(n = 10000, size = vepga, prob = prob_dvote_ga_2020)

# Building tibble with 10,000 simulations for Reps and Dems
sim_results_ga <- tibble(r_sims = sim_rvotes_ga_2020, 
                         d_sims = sim_dvotes_ga_2020,
                         # Calculating win margin for Dems
                         d_win_margin = ((sim_dvotes_ga_2020-sim_rvotes_ga_2020)/(sim_rvotes_ga_2020+sim_dvotes_ga_2020)*100),
                         # Calculating median win margin for Dems
                         median_win_margin = median((sim_dvotes_ga_2020-sim_rvotes_ga_2020)/(sim_rvotes_ga_2020+sim_dvotes_ga_2020)*100))

# Creating ggplot   
bidengapredplot <- sim_results_ga %>% 
  ggplot(aes(x = d_win_margin)) +
  # Creating histogram
  geom_histogram(bins = 75,
                 # Setting colors
                 color = 'white',
                 fill = '#528bfa') +
  # Setting titles
  labs(title = "Predicted Biden Win Margin in Georgia",
       subtitle = "Model based solely on FiveThirtyEight Polls from 10/10/2020",
       x = "Predicted Biden Win Margin (in %)",
       y = "Number of Simulations") +
  # Setting median line
  geom_vline(xintercept = 5.15,
            color = "black") +
  # Setting theme
  theme_bw() +
  # Setting font face for title
  theme(plot.title = element_text(face = "bold", size = 20))

# Saving plot
# ggsave("figures/bidengapredplot.png", height = 6, width = 12)

# HYPOTHETICAL GA AD WAR

# How much 1000 GRP buys in % votes + how much it costs
GRP1000.buy_fx.huber     <- 7.5
GRP1000.buy_fx.huber_se  <- 2.5
GRP1000.buy_fx.gerber    <- 5
GRP1000.buy_fx.gerber_se <- 1.5
GRP1000.price            <- 300

# Simulations from earlier
sims_results_ga_2020 <- (sim_dvotes_ga_2020-sim_rvotes_ga_2020)/(sim_dvotes_ga_2020+sim_rvotes_ga_2020)*100

# How much $ for Trump to get ~2% win margin?
# Based on earlier calculations, Trump needs to gain ~7.15% to win GA by ~2%
((7.15/GRP1000.buy_fx.huber) * GRP1000.price * 1000)  # $286,000 according to Huber et al
((7.15/GRP1000.buy_fx.gerber) * GRP1000.price * 1000) # $429,000 according to Gerber et al

# shift from that buy according to Gerber et al
sim_results_ga_2020_shift.a <- sims_results_ga_2020 - rnorm(10000, 7.15, GRP1000.buy_fx.gerber_se)
# shift from that buy according to Huber et al
sim_results_ga_2020_shift.b <- sims_results_ga_2020 - rnorm(10000, 7.15, GRP1000.buy_fx.huber_se)

# Creating tibble with Gerber and Huber simulations
joined_sims <- tibble("Gerber Estimate" = sim_results_ga_2020_shift.a,
                      "Huber Estimate" = sim_results_ga_2020_shift.b,
                      # Finding medians for both estimates
                      gerber_med = median(sim_results_ga_2020_shift.a),
                      huber_med = median(sim_results_ga_2020_shift.b))

# Pivoting simulations to allow for faceting by researcher in ggplot
pivoted_sims <- joined_sims %>%
  pivot_longer(cols = "Gerber Estimate":"Huber Estimate", 
               names_to = "researcher", 
               values_to = "fx_of_grp")

# Creating ggplot
trumpgrpsfxplot <- ggplot(pivoted_sims, aes(x = fx_of_grp, 
                          # Color by researcher
                          fill = as.factor(researcher))) +
  # Facet by researcher
  facet_wrap(~researcher) +
  # Changing bin size and creating breaks
  geom_histogram(bins = 50, color = "white") +
  # Creating labels for median values
  geom_text(data = filter(pivoted_sims, 
                          researcher == "Gerber Estimate"), 
            x = -8.3,
            y = 750, 
            label = "Median Predicted\nWin Margin:\n-2.02",
            size = 4) +
  geom_text(data = filter(pivoted_sims, 
                          researcher == "Huber Estimate"), 
            x = -7.5,
            y = 750, 
            label = " Median Predicted\nWin Margin:\n-1.95",
            size = 4) +
  # Creating lines for median values
  geom_vline(data = filter(pivoted_sims, 
                           researcher == "Gerber Estimate"), 
             aes(xintercept = -2.02), color="black") + 
  geom_vline(data = filter(pivoted_sims, 
                           researcher == "Huber Estimate"), 
             aes(xintercept = -1.95), color="black") +
  # Setting colors
  scale_fill_manual(values = c("#528bfa", "#ff5757")) +
  # Setting titles
  labs(x = "Biden Win Margin (in %)",
       y = "Number of Simulations",
       title = "Estimated Effect of Trump Air War on Biden's Win Margin in Georgia") +
  theme_bw() +
  # Setting font face for title
  theme(plot.title = element_text(face = "bold", size = 20),
        # Removing legend
        legend.position = "none")

# ggsave("figures/trumpgrpsfxplot.png", height = 6, width = 12)
