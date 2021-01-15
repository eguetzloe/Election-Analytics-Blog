# WEEK 6- GROUND GAME

# Read in libraries
library(tidyverse)
library(usmap)
library(maptools)
library(ggthemes)
library(lubridate)
library(scales)
library(huxtable)
library(gt)
library(stargazer)
library(rgdal)
library(readxl)
library(janitor)
library(caret)
library(kableExtra)
library(jtools)

# Read in csvs
fo_2012 <- read_csv("data/fieldoffice_2012_bycounty.csv")
fo_dem <- read_csv("data/fieldoffice_2004-2012_dems.csv")
fo_add <- read_csv("data/fieldoffice_2012-2016_byaddress.csv")
economy <- read_csv("data/local.csv")
popvotestate <- read_csv('data/popvote_bystate_1948-2016.csv')
pvcounty <- read_xls("data/US_elect_county.xls") %>%
  clean_names() %>%
  filter(fips != 0) %>%
  rename(percent_dem = percent_5) %>%
  rename(percent_rep = percent_7) %>%
  group_by(state_postal) %>%
  mutate(D_win_margin = percent_dem - percent_rep) %>%
  mutate(R_win_margin = percent_rep - percent_dem) %>%
  ungroup() %>%
  pivot_longer(cols = c("percent_dem", "percent_rep"), 
               names_to = "party", values_to = "percent")

#Set seed
set.seed(1347)

# MAPPING OBAMA AND ROMNEY'S FIELD OFFICES AND POPULAR VOTE

# Setting up Obama data for mapping
obama12 <- subset(fo_add, year == 2012 & candidate == "Obama") %>%
  select(longitude, latitude)

pv12_obama <- subset(pvcounty, party == "percent_dem")

# Setting up Romney data for mapping
romney12 <- subset(fo_add, year == 2012 & candidate == "Romney") %>%
  select(longitude, latitude)

pv12_romney <- subset(pvcounty, party == "percent_rep")

# Create longitude and latitude data
states_map <- us_map()
obama12_transformed <- usmap_transform(obama12)
romney12_transformed <- usmap_transform(romney12)

# Creating Obama map
ob12plot <- plot_usmap(regions = "states", data = pv12_obama, values = "D_win_margin")+
  # Plotting field offices
  geom_point(data = obama12_transformed, aes(x = longitude.1, 
                                             y = latitude.1), 
             # Set type of point
             color = "blue", pch = 3, alpha = 0.75, size = 1, stroke = 1)+
  # Set color gradient for legend
  scale_fill_gradient2(
    high = "blue", mid = "white", low = "red",
    name = "Dem\nwin margin"
  ) + 
  # Set title
  ggtitle("Obama Field Offices and Win Margin in 2012")+
  # Set theme
  theme(plot.title = element_text(size=16, face="bold")) + theme(legend.position = "right")

# Saving plot
# ggsave("figures/ob12plot.png", height = 6, width = 12)

# Creating Romney map
ro12plot <- plot_usmap(regions = "states", data = pv12_romney, values = "R_win_margin")+
  # Plotting field offices
  geom_point(data = obama12_transformed, aes(x = longitude.1, 
                                             y = latitude.1), 
             # Set type of point
             color = "red", pch = 3, alpha = 0.75, size = 1, stroke = 1)+
  # Set color gradient for legend
  scale_fill_gradient2(
    high = "red", mid = "white", low = "blue",
    name = "Rep\nwin margin"
  ) + 
  # Set title
  ggtitle("Romney Field Offices and Win Margin in 2012")+
  # Set theme
  theme(plot.title = element_text(size=16, face="bold")) + theme(legend.position = "right")

# Saving plot
# ggsave("figures/ro12plot.png", height = 6, width = 12)


#GRAPH 2: 2012 FIELD OFFICES IN BATTLEGROUND STATES

fo_battle_data <- fo_2012 %>%
  filter(battle == TRUE) %>%
  group_by(state) %>%
  mutate(Obama = sum(obama12fo)) %>%
  mutate(Romney = sum(romney12fo)) %>%
  ungroup() %>%
  pivot_longer(cols = c("Obama", "Romney"), 
               names_to = "candidate", values_to = "sum") %>%
  mutate(state = fct_reorder(state, sum, .desc = TRUE)) %>%
  select(state, candidate, sum) %>%
  distinct()

battlefoplot <- ggplot(fo_battle_data, aes(x = factor(state), y = sum, fill = state)) +
  facet_wrap(~candidate) +
  geom_col() +
  # Changed x and y axis titles and plot title
  labs(x = "State",
       y = "Number of Field Offices",
       title = "Number of Field Offices in 2012 Battleground States") +
  # Set theme
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.title = element_blank(),
        # Changed title font face
        plot.title = element_text(face = "bold", size = 20))

# Saving plot
# ggsave("figures/battlefoplot.png", height = 6, width = 12)

#GRAPH 3: Model Dem turnout based on field offices, discuss why it's challenging to include that this year due to COVID

fofxdata <- fo_dem %>%
  select(year, dempct_change, dummy_fo_change, battle, year, state) %>%
  drop_na()

fofxmodel1 <- train(dempct_change ~ dummy_fo_change, data = fofxdata, 
                    method = "lm", trControl = trainControl(method = "LOOCV"))

fofxmodel2 <- train(dempct_change ~ dummy_fo_change + battle + dummy_fo_change:battle, data = fofxdata, 
                    method = "lm", trControl = trainControl(method = "LOOCV"))

fofxmodel3 <- train(dempct_change ~ dummy_fo_change + battle + dummy_fo_change:battle +
                    as.factor(state) + as.factor(year), data = fofxdata, 
                    method = "lm", trControl = trainControl(method = "LOOCV"))

fofxmodels <- tibble(model = c("Model 1", "Model 2", "Model 3"))
loocv <- rbind(fofxmodel1$results, fofxmodel2$results, fofxmodel3$results)
loocv_table <- fofxmodels %>% 
  cbind(loocv) %>% 
  tibble()

# Placed model results in a table
fofxtable <- export_summs(fofxmodel1$finalModel, fofxmodel2$finalModel, fofxmodel3$finalModel,
                           # Renamed coefficients
                           coefs = c("Intercept" = "(Intercept)"),
                           # Renamed statistics   
                           statistics = c("Observations" = "nobs",
                                          "R-squared Values" = "r.squared",
                                          "Adjusted R-squared" = "adj.r.squared",
                                          "Sigma" = "sigma"),
                           # Set confidence intervals
                           ci_level = .95,
                           # Set confidence interval format
                           error_format = '({conf.low} to {conf.high})')
