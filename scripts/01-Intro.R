# read in libraries
library(tidyverse)
library(usmap)
library(ggthemes)
library(plotly)
library(gganimate)
library(transformr)
library(gifski)
# read in both the csvs and assigned variable names
popvote <- read_csv("data/popvote_1948-2016.csv")
popvotestate <- read_csv("data/popvote_bystate_1948-2016.csv")
# Thanks to Soubhik for finding this dataset
electors <- read_csv("data/ec_1952-2020.csv")
# Found this dataset on Kaggle which lists the populations of each state going
# back to the early 20th century:
# https://www.kaggle.com/hassenmorad/historical-state-populations-19002017
populationstate <- read_csv("data/datasets_42082_70699_state_pops.csv") %>%
  mutate (year = Year) %>% 
  filter(year %in% c(1952, 1956, 1960, 1964, 1968, 1972, 1976, 1980, 1984, 1988, 1992, 1996, 2000, 2004, 2008, 2012, 2016)) %>%
  pivot_longer(!year, names_to = "state", values_to = "population") %>%
  filter(state != "Year")
# joined electors dataset with popular vote by state dataset
fulldata <- popvotestate %>%
  left_join(electors, by = c("year", "state"))
# joined electors dataset with population
populationdata <- fulldata %>%
  left_join(populationstate, by = c("year", "state"))

electors2016 <- populationdata %>%
  filter(year == 2016) %>%
  filter(state %in% c("California", "Wyoming")) %>%
  ggplot(aes(x = state, y = electors, fill = state)) +
  scale_fill_manual(values=c("red", "blue")) +
  geom_bar(stat = "identity", width = 0.3) +
  labs(title= "Number of Electors Per State in 2016", y = "Number of Electors", x = " ", fill = "State") +
  coord_flip() +
  theme_bw()

ggsave("figures/electors2016.png")

population2016 <- populationdata %>%
  filter(year == 2016) %>%
  filter(state %in% c("California", "Wyoming")) %>%
  ggplot(aes(x = state, y = population, fill = state)) + 
  scale_fill_manual(values=c("red", "blue")) +
  geom_bar(stat = "identity", width = 0.3) +
  labs(title= "Population Per State in 2016", y = "Population (in millions)", x = " ", fill = "State") +
  coord_flip() +
  theme_bw()

ggsave("figures/population2016.png")

# Piped in data and dropped NA values
electordata <- fulldata %>%
  drop_na()
# Created ggplot
electoranim <- ggplot(electordata, aes(x = electors, y = D_pv2p)) +
  # Decreased scatterplot point size for cleaner look
  geom_point(size = 0.5) +
  # Created regression line and reduced line thickness
  geom_smooth(method = "lm", se = FALSE, size = 0.5) +
  # Set titles
  labs(x = "Number of State's Electors", y = "Percentage of State Vote Won by Democrat", title = "Democrat State Vote Share Explained by Number of Electors", subtitle = "Year: {current_frame}") +
  # Set theme
  theme_bw() +
  # Set font sizes
  theme(plot.title = element_text(size = 7), plot.subtitle = element_text(size = 6), axis.title = element_text(size = 6), axis.text = element_text(size = 6)) +
  # Set transition style
  transition_manual(year)
# Animated graphic and manually set height, width, and resolution
animate(electoranim, duration = 15, fps = 20, width = 3, height = 2, units="in", res= 175, renderer = gifski_renderer())
# Saved gif
anim_save("figures/electoranimation.gif")

pv_margins_map <- popvotestate %>%
  mutate(win_margin = (D_pv2p-R_pv2p)) %>%
  filter(year %in% c(1964, 1968, 1972, 1988, 1992, 2000))

map <- plot_usmap(data = pv_margins_map, regions = "states", values = "win_margin") +
  scale_fill_gradient2(
    high = "dodgerblue2", 
    mid = "white",
    low = "red2", 
    breaks = c(-50,-25,0,25,50), 
    limits = c(-50,50),
    name = "win margin"
  ) +
  labs(title = "Impact of the Southern Strategy", caption= "Some states are gray because of N/A values. In these cases, certain frontrunners were not included on some ballots and thus data is incomplete.", fill = "Win Margin by Percent") +
  facet_wrap(~year) +
  theme_void()

ggsave("figures/map.png")