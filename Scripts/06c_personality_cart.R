#!/usr/bin/env Rscript
# ==============================================================================
# Script 06c: CART Decision Tree for Personality Determinants of Signature Shape
# Project: Social Signatures in NetHealth
# Description: Reconstructs the regression-tree analysis cited in the
#              manuscript (Figure 8/9) that was previously generated ad hoc
#              without a saved script. Fits a Classification and Regression
#              Tree (rpart) predicting each ego's mean power-law decay
#              exponent (alpha) from baseline Big Five personality traits.
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(rpart)
  library(data.table)
})

cat(">>> Step 6c: Loading personality/signature covariates...\n")
stopifnot(file.exists("data/processed/expansion_models.rds"))
expansion_d <- readRDS("data/processed/expansion_models.rds")

ego_param_mean <- expansion_d$ego_param_covariates %>%
  filter(!is.na(mean_alpha), !is.na(extraversion), !is.na(neuroticism),
         !is.na(agreeableness), !is.na(conscientiousness), !is.na(openness))

cat(sprintf("CART training sample: N = %d egos.\n", nrow(ego_param_mean)))

set.seed(4127)
cart_fit <- rpart(
  mean_alpha ~ extraversion + neuroticism + agreeableness + conscientiousness + openness,
  data = ego_param_mean,
  method = "anova",
  control = rpart.control(minsplit = 20, cp = 0.02, maxdepth = 4)
)

cat("\nCART tree structure:\n")
print(cart_fit)

cat("\nVariable importance (relative, sums to 100):\n")
imp <- cart_fit$variable.importance
imp_pct <- round(100 * imp / sum(imp), 1)
print(imp_pct)

printcp(cart_fit)

saveRDS(list(cart_fit = cart_fit, ego_param_mean = ego_param_mean, importance_pct = imp_pct),
        "data/processed/personality_cart_model.rds")

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write_csv(
  tibble(variable = names(imp_pct), importance_pct = as.numeric(imp_pct)),
  "output/tables/table_cart_variable_importance.csv"
)

cat("\n>>> Step 6c completed successfully! Saved to data/processed/personality_cart_model.rds\n")
