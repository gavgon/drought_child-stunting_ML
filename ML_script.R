library(tidyverse)
library(rdhs)
library(sf)
library(terra)
library(haven)
library(tidymodels)
library(vip)
library(parsnip)

kids_merged <- readRDS("data/analysis/kids_merged.rds")

set.seed(103)

split <- initial_split(
  kids_merged, 
  prop = 0.75,
  strata = stunted
) # Strata ensures that there is an even proportional share of stunted kids in training and testing data

kids_train <- training(x = split) 

kids_test <- testing(x = split)

nonsurvey_rec <-
  recipe(stunted ~ 
          LATNUM +
          LONGNUM +
          ALT_DEM +
          URBAN_RURA +
          spei_mean_utero +
          spei_mean_yr1 +
          spei_mean_yr2 +
          spei_mean_rec +
          drought_share_utero +
          drought_share_yr1 +
          drought_share_yr2 +
          drought_share_rec +
          crop_ha_mean +
          staple_ha_mean +
          rainfed_ha +
          rainfed_share,
         data = kids_train) |>
  step_impute_median(all_numeric_predictors()) |> # Added KNN to impute
         step_dummy(URBAN_RURA) |>
  step_normalize(all_predictors())

# bake(prep(nonsurvey_rec, training = kids_train), new_data = kids_train)

set.seed(103)

folds <- vfold_cv(data = kids_train, v = 10, strata = stunted)

lasso_grid <- grid_regular(penalty(), levels = 10)

#lasso_mod <- linear_reg(
#  penalty = tune(), 
#  mixture = 1
#) |>
#  set_engine("glmnet")
#
#lasso_wf <- workflow() |>
#  add_recipe(nonsurvey_rec) |>
#  add_model(lasso_mod) 
#
#lasso_cv <- lasso_wf |>
#  tune_grid(
#    resamples = folds,
#    grid = lasso_grid
#  )
# # All models failed: For a regression model, the outcome should be <numeric>, not a <factor> object.

### Try 2:
lasso_mod <- logistic_reg(
  penalty = tune(), 
  mixture = 1
) |>
  set_engine("glmnet")

lasso_wf <- workflow() |>
  add_recipe(nonsurvey_rec) |>
  add_model(lasso_mod) 

lasso_cv <- lasso_wf |>
  tune_grid(
    resamples = folds,
    grid = lasso_grid,
    control = control_grid(verbose = TRUE)
  )

# > show_notes(.Last.tune.result)
# unique notes:
#   ───────────────────────────────────────────────────────────
# x has missing values; consider using makeX() to impute them

lasso_best <- lasso_cv |>
  select_best(metric = "roc_auc")

lasso_final <- finalize_workflow(
  lasso_wf,
  parameters = lasso_best
)

lasso_coefs <- lasso_final |>
  fit(data = kids_train) |>
  extract_fit_parsnip() |>
  vi(lambda = lasso_best$penalty) 


###### LM ######

# create a linear regression model using the "lm" package as the engine
lm_mod <- linear_reg() |>
  set_engine("lm")

# create a workflow with the recipe and linear regression model you've created
lm_wf <- workflow() |>
  add_recipe(nonsurvey_rec) |>
  add_model(lm_mod) 

# fit the model by piping your workflow
lm_cv <- lm_wf |>
  fit_resamples(resamples = folds)

# select the best model based on the "rmse" metric
lm_best <- lm_cv |>
  select_best(metric = "roc_auc")

# use the finalize_workflow() function with your workflow and the best model 
# to update (or "finalize") your workflow by modifying the line below
lm_final <- finalize_workflow(
  lm_wf,
  parameters = lm_best
)

# fit to the training data and extract coefficients
lm_coefs <- lm_final |>
  fit(data = kids_train) |>
  extract_fit_parsnip() |>
  vi(lambda = lasso_best$penalty)


### Using Results
results <- load("/Users/gavinaligondalwala/ppol6803/final_project/PPOL-670_Final-Project/results.RData")













