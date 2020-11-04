# WEEK 8- FINAL PREDICTION

# Read in libraries
library(caret)
library(ggthemes)
library(huxtable)
library(janitor)
library(jtools)
library(kableExtra)
library(lubridate)
library(rgdal)
library(scales)
library(stargazer)
library(statebins)
library(tidyverse)
library(usmap)

# Read in csvs for national popular vote model:
popvote <- read_csv("clean-data/popvote_1948-2016_clean.csv")
polls2020 <- read_csv("clean-data/president_polls_clean.csv")
economy <- read_csv("clean-data/econ_clean.csv")
gallup <- read_csv("clean-data/approval_gallup_1941-2020_clean.csv")
# Read in csvs for state Electoral College model:
pastpolls <- read_csv("clean-data/pollavg_1968-2016_clean.csv")
paststatepolls <- read_csv("clean-data/pollavg_bystate_1968-2016_clean.csv")
statepolls2020 <- read_csv("clean-data/president_polls_state_clean.csv")
popvotestate <- read_csv("clean-data/popvote_bystate_1948-2016_clean.csv")
electors <- read_csv("clean-data/ec_2020_clean.csv")
local <- read_csv("clean-data/local.csv")
vep <- read_csv("data/vep_1980-2016.csv")

# Setting seed for replication
set.seed(1000)

# Joining data needed for national model
modeldata <- pastpolls %>% 
  inner_join(popvote, by = c("year", "party")) %>% 
  inner_join(gallup, by = "year") %>%
  inner_join(economy, by = "year")

# NATIONAL POPULAR VOTE MODEL

# Created five different models for comparison

# Model 1 includes average poll support and the previous year's average
# unemployment
model1 <- train(pv2p ~ avg_support + prev_avg_unemployment, 
                 data = modeldata, method = "lm", trControl = trainControl(method = "LOOCV"))

# Model 2 includes both the previous predictors plus last election's 2 party
# popular vote share
model2 <- train(pv2p ~ avg_support + prev_avg_unemployment + last_pv2p, 
                 data = modeldata, method = "lm", trControl = trainControl(method = "LOOCV"))

# Model 3 includes all of the Model 2's predictors plus average GDP growth from
# the prior year and average incumbent job approval from election year Gallup
# polls
model3 <- train(pv2p ~ avg_support + prev_avg_unemployment + prev_avg_gdp_growth + last_pv2p + job_approval, 
                 data = modeldata, method = "lm", trControl = trainControl(method = "LOOCV"))

# Model 4 includes all of Model 3's predictors but interacts average incumbent
# job approval with incumbent party
model4 <- train(pv2p ~ avg_support + prev_avg_unemployment + prev_avg_gdp_growth + last_pv2p + incumbent_party*job_approval, 
                 data = modeldata, method = "lm", trControl = trainControl(method = "LOOCV"))

# Model 5 includes all the previous predictors and interactions plus
# interactions between incumbent party and the previous year's unemployment
# rates, and incumbent party and the previous year's average GDP growth
model5 <- train(pv2p ~ avg_support + prev_avg_unemployment + prev_avg_gdp_growth + last_pv2p + incumbent_party*job_approval + incumbent_party*prev_avg_unemployment + incumbent_party*prev_avg_gdp_growth,
                 data = modeldata, method = "lm", trControl = trainControl(method = "LOOCV"))

model6 <- train(pv2p ~ avg_support*party + prev_avg_gdp_growth + last_pv2p + job_approval*party,
                data = modeldata, method = "lm", trControl = trainControl(method = "LOOCV"))


# Joined models and model results in tibble
all_models <- tibble(model = c("Model 1", "Model 2", "Model 3", "Model 4", "Model 5", "Model 6"))
loocv <- rbind(model1$results, model2$results, model3$results, model4$results, model5$results, model6$results)
loocv_table <- all_models %>% 
  cbind(loocv) %>% 
  tibble()
# Placed model results in a table
modeltable <- export_summs(model1$finalModel, model2$finalModel, model3$finalModel, 
                              model4$finalModel, model5$finalModel, model6$finalModel,
                           # Renamed coefficients
                              coefs = c("Intercept" = "(Intercept)",
                                        "Average Polling" = "avg_support",
                                        "Previous Year's Unemployment" = "prev_avg_unemployment",
                                        "Last percentage of 2-party vote share" = "last_pv2p",
                                        "Average Gallup Job Approval" = "job_approval",
                                        "Incumbent Party" = "incumbent_partyTRUE",
                                        "Incumbent Party:Average Gallup Job Approval" = "`incumbent_partyTRUE:job_approval`",
                                        "Previous Year's GDP Growth" = "prev_avg_gdp_growth"),
                             # Renamed statistics   
                             statistics = c("Observations" = "nobs",
                                             "R-squared Values" = "r.squared",
                                             "Adjusted R-squared" = "adj.r.squared",
                                             "Sigma" = "sigma"),
                              # Set confidence intervals
                              ci_level = .95,
                              # Set confidence interval format
                              error_format = '({conf.low} to {conf.high})')

# Exported table to an html to screenshot
 quick_html(modeltable, file = "modeltable.html")

# 2020 NATIONAL POPULAR VOTE PREDICTION

# Joining and cleaning 2020 data
npv2020 <- polls2020 %>%
  # Joined polls and economy dataset and filtered for 2020
  left_join(economy %>% filter(year == 2020), by = "year") %>%
  # Joined Gallup dataset and filtered for 2020
  left_join(gallup %>% filter(year == 2020), by = "year") %>%
  # Created a column for last popular vote
  mutate(last_pv2p = popvote %>% filter(year == 2016) %>% pull(pv2p),
         # Created incumbent column
         incumbent = case_when(
           party == "republican" ~ TRUE,
           party == "democrat" ~ FALSE),
         # Created incumbent party column
          incumbent_party = incumbent)
  
# Predicting 2020 
model2020 <- lm(pv2p ~ avg_support + prev_avg_unemployment + prev_avg_gdp_growth + last_pv2p + incumbent_party*job_approval, 
                 data = modeldata)
pred2020 <- predict.lm(object = model2020, newdata = npv2020, se.fit=TRUE, interval="confidence", level=0.95)
# Creating 10,000 simulations
npvsims <- tibble(id = as.numeric(1:20000),
                  # Adding in candidate column
                   candidate = rep(c("Biden", "Trump"), 10000),
                  # Adding in predicted popular vote share
                   pred_pv = rep(pred2020$fit[,1], 10000),
                  # Adding in standard errors
                   pred_se = rep(pred2020$se.fit, 10000)) %>% 
  # Made predicted probabilities follow a logistic scale so predicted values for both candidates add up to 100
  mutate(pred_prob = map_dbl(.x = pred_pv, .y = pred_se, ~rnorm(n = 1, mean = .x, sd = .y))) %>% 
  # Mutated to keep IDs the same between simulated scenarios
  mutate(id = case_when(
    id %% 2 == 1 ~ id,
    id %% 2 == 0 ~ id - 1))

formattedsims <- npvsims %>%
  # Removing unnecessary columns
  select(-c(pred_pv, pred_se)) %>% 
  # Grouping by simulation ID
  group_by(id) %>% 
  # Pivoted to allow manipulation with candidates' predicted vote shares
  pivot_wider(names_from = "candidate", values_from = "pred_prob") %>% 
  # Ungrouped
  ungroup() %>% 
  # Mutated to place predictions on a 100-point scale
  mutate(total = Biden + Trump,
         Biden = (Biden / total) * 100,
         Trump = (Trump / total) * 100) %>% 
  # Selected desired columns
  select(-total) %>% 
  # Pivoted data back to candidate column
  pivot_longer(Biden:Trump, names_to = "candidate", values_to = "pred_prob")
# Creating averages
bidenpred <- pred2020$fit[1,1]
trumppred <- pred2020$fit[2,1]
# Creating total
totalpred <- bidenpred + trumppred
# Scaling averages
bidenscaled <- (bidenpred / totalpred) * 100
trumpscaled <- (trumppred / totalpred) * 100

# GRAPHING NATIONAL POPULAR VOTE MODEL

npvpredgraph <- formattedsims %>%
  # Placed predictions on the x axis
  ggplot(aes(x = pred_prob, 
             # Filled color based on candidate
             fill = fct_relevel(candidate, "Trump", "Biden")))+
  # Created histogram and set binwidth
  geom_histogram(bins = 100) +
  # Set new colors for plot
  scale_fill_manual(breaks = c("Trump", "Biden"),
                    values=c("firebrick2", "darkblue")) +
  # Set theme
  theme_minimal() +
  # Set font sizes and faces
  theme(plot.title = element_text(face = "bold", size = 20)) +
  theme(plot.subtitle = element_text(size = 13)) +
  # Removed legend title
  theme(legend.title = element_blank()) +
  # Renamed x axis and y axis
  labs(x = "Predicted Two-Party Popular Vote Share", 
       y = " ", 
       # Gave plot a title and subtitle
       title = "Predictive Interval for 2020 Two-Party Popular Vote Share",
       subtitle = "Based on 10,000 simulations of the model")

# Saving plot
#ggsave("figures/npvpredgraph.png", height = 6, width = 12)

# STATE ELECTORAL COLLEGE MODEL

#Joining data needed for state model
statedata <- popvotestate %>% 
  # Joined popular vote and past state polls
  left_join(paststatepolls, by = c("state", "year", "party")) %>% 
  # Dropped NAs
  drop_na() %>% 
  # Joined approval ratings
  left_join(gallup, by = "year") %>% 
  # Joined VEP and VAP population data
  left_join(vep, by = c("year", "state")) %>%
  # Joined national economy dataset
  left_join(economy, by = "year") %>%
  # Removed national unemployment
  select(-prev_avg_unemployment) %>%
  # Added state unemployment
  left_join(local, by = c("year", "state")) %>%
  # Cleaned data names
  clean_names() %>%
  # Grouped by state
  group_by(state) %>% 
  # Nested by state
  group_nest() %>% 
  # Created list columns by state
  mutate(data = map(data, ~unnest(., cols = c())))

# Created different models for comparison and placed their resulting summary
# statistics in tables

#statemodel1 <- statedata %>%
  #mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_unemployment + party,
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>%
  #select(-data)

#statemodel1_results <- statemodel1 %>%
  #mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
  #mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
  #mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
  #mutate(avg_r2 = mean(r_squared)) %>%
  #mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
  #mutate(avg_rmse = mean(rmse))
# Avg RMSE 4.29, Avg LOOCV R2 .618, Avg R2 .759- pretty good RMSE but LOOCV R2
# and R2 could probably be better

#statemodel2 <- statedata %>%
  #mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_unemployment + party + last_pv2p,
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>%
  #select(-data)

#statemodel2_results <- statemodel2 %>%
  #mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
  #mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
  #mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
  #mutate(avg_r2 = mean(r_squared)) %>%
  #mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
  #mutate(avg_rmse = mean(rmse))
# Avg RMSE 4.19, Avg LOOCV R2 .634, Avg R2 .805- better in all ways than model 1

#statemodel3 <- statedata %>%
  #mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_gdp_growth + party + last_pv2p,
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>%
  #select(-data)

#statemodel3_results <- statemodel3 %>%
  #mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
  #mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
  #mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
  #mutate(avg_r2 = mean(r_squared)) %>%
  #mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
  #mutate(avg_rmse = mean(rmse))
# Avg RMSE 4.23, Avg LOOCV R2 .629, Avg R2 .807- slightly worse RMSE and Avg
# LOOCV, essentially equal R2

#statemodel4 <- statedata %>%
  #mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_gdp_growth + party + last_pv2p + job_approval,
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>%
  #select(-data)

# statemodel4_results <- statemodel4 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 4.72, Avg LOOCV R2 .576, Avg R2 .810- worse RMSE and Avg LOOCV,
# slightly better R2

#statemodel5 <- statedata %>%
  #mutate(model = map(data, ~train(pv2p ~ avg_support*party + prev_avg_gdp_growth + last_pv2p + job_approval,
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>%
  #select(-data)

# statemodel5_results <- statemodel5 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 5.63, Avg LOOCV R2 .514, Avg R2 .830- worse RMSE and Avg LOOCV,
# slightly better R2

statemodel6 <- statedata %>% 
  mutate(model = map(data, ~train(pv2p ~ avg_support*party + prev_avg_gdp_growth + last_pv2p + job_approval*party, 
                                  data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
  select(-data)

statemodel6_results <- statemodel6 %>% 
  mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
  mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
  mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
  mutate(avg_r2 = mean(r_squared)) %>%
  mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
  mutate(avg_rmse = mean(rmse))
# Avg RMSE 5.01, Avg LOOCV R2 .667, Avg R2 .912- not great but not bad RMSE,
# actually pretty good Avg LOOCV, high R2


#statemodel7 <- statedata %>% 
  #mutate(model = map(data, ~train(pv2p ~ avg_support*party + prev_avg_unemployment + last_pv2p + job_approval*party, 
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
  #select(-data)

# statemodel7_results <- statemodel7 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 5.38, Avg LOOCV R2 .631, Avg R2 .906- worse RMSE, LOOCV R2, and R2
# from model 6

#statemodel8 <- statedata %>% 
  #mutate(model = map(data, ~train(pv2p ~ avg_support*party + prev_avg_gdp_growth*party + last_pv2p + job_approval*party, 
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
  #select(-data)

# statemodel8_results <- statemodel8 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 5.98, Avg LOOCV R2 .632, Avg R2 .922- worse RMSE, roughly equal LOOCV
# R2 from 7, slightly better Avg R2

#statemodel9 <- statedata %>% 
  #mutate(model = map(data, ~train(pv2p ~ avg_support*party + prev_avg_gdp_growth + party + job_approval*party, 
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
  #select(-data)

# statemodel9_results <- statemodel9 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 5.75, Avg LOOCV R2 .528, Avg R2 .833- worse RMSE, Avg LOOCV, and R2

#statemodel10 <- statedata %>% 
  #mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_unemployment + party + last_pv2p + prev_avg_gdp_growth, 
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
  #select(-data)

# statemodel10_results <- statemodel10 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 5.63, Avg LOOCV R2 .514, Avg R2 .830- slightly better RMSE but
# slightly worse Avg LOOCV R2 and R2 than model 9

#statemodel11 <- statedata %>% 
  #mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_unemployment + party + incumbent_party*job_approval, 
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
  #select(-data)

# statemodel11_results <- statemodel11 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 5.28, Avg LOOCV R2 .557, Avg R2 .834- better RMSE than model 10,
# better Avg LOOCV, slightly better Avg R2

#statemodel12 <- statedata %>% 
  #mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_unemployment + incumbent_party*job_approval, 
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
  #select(-data)

# statemodel12_results <- statemodel12 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 6.69, Avg LOOCV R2 .440, Avg R2 .735- much worse RMSE, Avg LOOCV R2,
# and Avg R2 than model 11

#statemodel13 <- statedata %>% 
  #mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_unemployment + party + last_pv2p + prev_avg_gdp_growth + incumbent_party*job_approval, 
                                  #data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
  #select(-data)

# statemodel13_results <- statemodel13 %>%
# mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
# mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
# mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
# mutate(avg_r2 = mean(r_squared)) %>%
# mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
# mutate(avg_rmse = mean(rmse))
# Avg RMSE 7.00, Avg LOOCV R2 .566, Avg R2 .894- worse RMSE, slightly better
# LOOCV R2 than model 12, better R2 than previous model

# statemodel14 <- statedata %>% 
#   mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_unemployment + party + last_pv2p + prev_avg_gdp_growth + incumbent_party*job_approval + incumbent_party*prev_avg_unemployment, 
#                                   data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
#   select(-data)

# statemodel14_results <- statemodel14 %>% 
#   mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
#   mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
#   mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
#   mutate(avg_r2 = mean(r_squared)) %>%
#   mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
#   mutate(avg_rmse = mean(rmse))
# Avg RMSE 8.38, Avg LOOCV R2 .512, Avg R2 .910- again worse RMSE, worse LOOCV
# R2, slightly better R2 than model 13

# statemodel15 <- statedata %>% 
#   mutate(model = map(data, ~train(pv2p ~ avg_support + prev_avg_unemployment + party + last_pv2p + incumbent_party*prev_avg_gdp_growth + incumbent_party*job_approval + incumbent_party*prev_avg_unemployment, 
#                                   data = .x, method = "lm", trControl = trainControl(method = "LOOCV")))) %>% 
#   select(-data)

# statemodel15_results <- statemodel15 %>% 
#   mutate(r_squared = map_dbl(model, ~summary(.x)$r.squared)) %>%
#   mutate(r_squared_loocv = map_dbl(model, ~.x$results[,3])) %>%
#   mutate(rmse = map_dbl(model, ~.x$results[,2])) %>%
#   mutate(avg_r2 = mean(r_squared)) %>%
#   mutate(avg_loocv_r2 = mean(r_squared_loocv)) %>%
#   mutate(avg_rmse = mean(rmse))
# Avg RMSE 8.29, Avg LOOCV R2 .487, Avg R2 .919- slightly better RMSE than model
# 14 but still bad, worse LOOCV R2, slightly better R2

# In my view Model 6 provides the best balance of high R2 and decent LOOCV R2
# combined with lower RMSE, so that's the model I'll continue working with.

# 2020 STATE ELECTORAL COLLEGE PREDICTION

# Adding in 2020 data to make predictions
statepreddata <- statepolls2020 %>% 
  # Joining data on last state popular vote
  left_join(popvotestate %>% 
              filter(year == 2016) %>% 
              select(state, party, pv2p), 
            by = c("state", "party")) %>% 
  # Renaming last pv2p column
  rename(last_pv2p = pv2p) %>% 
  # Mutating to rename variables in incumbent column
  mutate(incumbent = case_when(
    party == "republican" ~ TRUE,
    party == "democrat" ~ FALSE
  ),
  incumbent_party = incumbent,
  # Adding in economic variables
  prev_avg_gdp_growth = economy %>% 
    # Filtering for 2019 economic data
    filter(year == 2020) %>% 
    pull(prev_avg_gdp_growth),
  year = 2020) %>% 
  # Joining job approval data
  left_join(gallup, by = "year")

# Predicting electoral college votes for states
statepredmodel <- statedata %>% 
  mutate(model = map(data, ~lm(pv2p ~ avg_support*party + prev_avg_gdp_growth + last_pv2p, data = .x))) %>% 
  select(-data) 

# Placing predictions in data frame
statepred2020 <- statepreddata %>%
  # Mutating to leave party column
  mutate(party_temp = party) %>% 
  # Grouping by state and party
  group_by(state, party_temp) %>% 
  # Nesting data
  nest() %>% 
  # Mapping and joining predictions
  mutate(data = map(data, ~unnest(., cols = c()))) %>% 
  left_join(statepredmodel, by = "state") %>% 
  # Creating prediction column
  mutate(pred = map_dbl(.x = model, .y = data, ~predict(object = .x, newdata = as.data.frame(.y)))) %>% 
  # Selecting desired columns
  select(state, party_temp, pred)

# Scaling predictions
statepredscaled <- statepred2020 %>% 
  # Creating Democrat and Republican columns
  pivot_wider(names_from = party_temp, values_from = pred) %>% 
  # Creating total column
  mutate(total = democrat + republican) %>% 
  # Mutating to create Dem total
  mutate(democrat = (democrat / total) * 100,
         # Mutating to create Rep total
         republican = (republican / total) * 100,
         # Mutating to call winner
         winner = ifelse(republican > democrat, "Trump", "Biden"),
         # Mutating to create win margin
         win_margin = republican - democrat,
         # Mutating to create win margin groups
         win_margin_group = case_when(
           win_margin >= 8 ~ "Strong Trump",
           win_margin >= 5 ~ "Likely Trump",
           win_margin >= 3 ~ "Lean Trump",
           win_margin <= -8 ~ "Strong Biden",
           win_margin <= -5 ~ "Likely Biden",
           win_margin <= -3 ~ "Lean Biden",
           TRUE ~ "Toss-Up"
         )) %>% 
  # Selecting desired columns
  select(state, winner, win_margin, win_margin_group)

# GRAPHING ELECTORAL MAP PREDICTION WITH LEAN

# Creating Electoral Graphic
ecmapgradient <- statepredscaled %>% 
  # Creating map
  ggplot(aes(state = state, 
             fill = win_margin_group)) +
  # Adding statebins format
  geom_statebins() + 
  theme_statebins() +
  # Customizing colors for leans
  scale_fill_manual(values = c("#528bfa", "#99bdff", "#d6e6ff", "#CCCCFF", "#ffdcd9", "#FC9A98", "#ff5757"),
                    breaks = c("Strong Biden","Likely Biden", "Lean Biden", "Toss-Up", "Lean Trump", "Likely Trump", "Strong Trump")) +
  # Adding title
  labs(title = "2020 Presidential Election Prediction Map",
       fill = "") +
  theme(plot.title = element_text(face = "bold", size = 20))

# Saving plot
# ggsave("figures/ecmapgradient.png", height = 6, width = 12)

# GRAPHING ELECTOR BAR PLOT

# Creating Electors Bar Data
ecbardata <- statepredscaled %>% 
  # Formatting DC
  mutate(state = ifelse(state == "District of Columbia", "D.C.", state)) %>%
  # Joining electors data
  left_join(electors, by = "state") %>% 
  # Grouping by win margin
  group_by(win_margin_group) %>% 
  # Creating total electors column
  summarize(total = sum(electors), .groups = "drop")

# Creating plot
electorbar <- ecbardata %>% 
  # Created levels for leans
  ggplot(aes(x = "2020", y = total, fill = fct_relevel(win_margin_group, "Strong Trump", "Likely Trump", "Lean Trump", "Toss-Up", "Lean Biden", "Likely Biden", "Strong Biden"), label = total)) +
  # Created bar plot
  geom_col(show.legend = FALSE, width = 0.25) + 
  # Created text
  geom_text(position = position_stack(vjust = 0.5)) +
  # Flipped plot on side and created intercept at 270
  coord_flip() + geom_hline(yintercept = 270) +
  # Placed text on plot
  annotate(geom = 'text', x = 0.7, y = 300, label = '270') +
  # Customized theme
  theme_void() +
  # Customized colors
  scale_fill_manual(values = c("#528bfa", "#99bdff", "#d6e6ff", "#CCCCFF", "#ffdcd9", "#FC9A98", "#ff5757"),
                    breaks = c("Strong Biden","Likely Biden", "Lean Biden", "Toss-Up", "Lean Trump", "Likely Trump", "Strong Trump"))
# Saving plot
#png("electorbar1.png", units="in", width=6, height=1.5, res=100)
#print(electorbar)
# dev.off()
 
# And finally, some more simulations
statesims <- statepreddata %>%
  # Creating party temp column
  mutate(party_temp = party) %>%
  # Grouping by state and party
  group_by(state, party_temp) %>% 
  # Nesting data
  nest() %>% 
  # Mapping and predicting models
  mutate(data = map(data, ~unnest(., cols = c()))) %>% 
  left_join(statepredmodel, by = "state") %>% 
  mutate(pred = map(.x = model, .y = data, ~predict.lm(object = .x, newdata = as.data.frame(.y), se.fit=TRUE, interval="confidence", level=0.95))) %>% 
  # Selecting desired columns
  select(state, party_temp, pred) %>% 
  # Creating prediction measurements
  mutate(pred_fit = map_dbl(pred, ~.x$fit[,1]),
         pred_se = map_dbl(pred, ~.x$se.fit))

# Simulating 10000 draws
statesims2020 <- tibble(key = rep(seq(1, 10000), 102)) %>%
  arrange(key) %>% 
  # Creating party, state, and prediction measurement columns
  mutate(party = rep(statesims$party_temp, 10000),
         state = rep(statesims$state, 10000),
         pred_fit = rep(statesims$pred_fit, 10000),
         pred_se = rep(statesims$pred_se, 10000)) %>% 
  # Creating prediction probabilities
  mutate(pred_prob = map_dbl(.x = pred_fit, .y = pred_se, ~rnorm(n = 1, mean = .x, sd = .y))) %>% 
  # Formatting for DC
  mutate(state = ifelse(state == "District of Columbia", "D.C.", state))

# Formatting simulation data
democratstatesimdata <- statesims2020 %>% 
  # Filter for Dems
  filter(party == "democrat") %>% 
  # Selecting desired columns
  select(key, state, pred_prob) %>% 
  # Renamed Dem prediction column
  rename(democrat = pred_prob)

republicanstatesimdata <- statesims2020 %>% 
  # Filtering for Reps
  filter(party == "republican") %>% 
  # Selecting desired columns
  select(key, state, pred_prob) %>% 
  # Renaming Rep prediction column
  rename(republican = pred_prob)

# Joined datasets
statesims2020data <- democratstatesimdata %>% 
  inner_join(republicanstatesimdata, by = c("key", "state")) %>% 
  inner_join(electors %>% select(-year), by = "state") %>% 
  # Mutated to create possibilities of Trump and Biden wins
  mutate(biden_win = ifelse(democrat > republican, electors, 0)) %>% 
  mutate(trump_win = ifelse(democrat < republican, electors, 0)) %>% 
  # Selected desired columns
  select(key, state, biden_win, trump_win) %>% 
  # Grouped by key
  group_by(key) %>% 
  # Created Biden and Trump win columns
  summarize(Biden = sum(biden_win),
            Trump = sum(trump_win),
            .groups = "drop") %>% 
  # Pivoted to manipulate data more easily
  pivot_longer(Biden:Trump, names_to = "candidate", values_to = "ec") 

# GRAPHING ELECTORAL COLLEGE SIMULATIONS

statesims2020data %>% 
  # Setting fill and color for candidates
  ggplot(aes(x = ec, color = fct_relevel(candidate, "Trump", "Biden"), 
             fill = fct_relevel(candidate, "Trump", "Biden"))) +
  # Creating some transparency
  geom_density(alpha = 0.8) +
  # Customizing theme
  theme_minimal() +
  # Setting titles, subtitles, and x and y axis titles
  labs(title = "Predictive Interval for 2020 Electoral College Vote Share",
    subtitle = "Based on 10,000 simulations of the model",
    x = "Electoral College Vote",
    y = " " ) +
  # Customizing colors
  scale_color_manual(values=c("darkblue", "firebrick2"), breaks = c("Biden", "Trump")) +
  scale_fill_manual(values=c("darkblue", "firebrick2"), breaks = c("Biden", "Trump")) +
  # Setting font sizes and faces
  theme(plot.title = element_text(face = "bold", size = 20)) +
  theme(plot.subtitle = element_text(size = 13)) +
  # Removing legend title
  theme(legend.title = element_blank())

# Saving plot
#ggsave("figures/npvpredgraph.png", height = 6, width = 12)

# CREATING FINAL US MAP PREDICTION WITHOUT TOSSUPS

stateprednolean <- statepred2020 %>% 
  # Creating Democrat and Republican columns
  pivot_wider(names_from = party_temp, values_from = pred) %>% 
  # Creating total column
  mutate(total = democrat + republican) %>% 
  # Mutating to create Dem total
  mutate(democrat = (democrat / total) * 100,
         # Mutating to create Rep total
         republican = (republican / total) * 100,
         # Mutating to call winner
         winner = ifelse(republican > democrat, "Trump", "Biden"),
         # Mutating to create win margin
         win_margin = republican - democrat,
         # Mutating to create win margin groups
         win_margin_group = case_when(
           win_margin >= .1 ~ "Trump",
           win_margin <= -.1 ~ "Biden",
           TRUE ~ "Toss-Up"
         )) %>% 
  # Selecting desired columns
  select(state, winner, win_margin, win_margin_group)

# Plotting onto map
noleanmap <- plot_usmap(data = stateprednolean, regions = "states", values = "win_margin_group", color = "black") +
  # Customizing color scheme
  scale_fill_manual(values = c("#3d82ff", "#ff4242")) +
  # Setting titles and subtitles
  labs(title = "2020 Presidential Election Prediction",
       subtitle = "Without leans or toss-ups") +
  # Customizing theme
  theme_void() +
  # Setting font sizes and faces
  theme(plot.title = element_text(face = "bold", size = 20)) +
  theme(plot.subtitle = element_text(size = 13)) +
  # Removing legend title
  theme(legend.title = element_blank())

# Saving plot
# ggsave("figures/noleanmap.png", height = 6, width = 12)
