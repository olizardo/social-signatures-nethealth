#!/usr/bin/env Rscript
# ==============================================================================
# Script 06: Expansion Statistical Models & Dyadic Support Linkage
# Project: Social Signatures in NetHealth
# Description: Implements substantive expansions:
#              - Dyadic analysis linking signature rank tiers to survey support dimensions
#              - Multilevel mixed-effects models predicting signature self-divergence
#              - Cross-sectional models linking personality (Big 5) to signature shape (alpha)
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lme4)
  library(broom)
  library(data.table)
})

cat(">>> Step 6: Loading processed datasets for expansion modeling...\n")
stopifnot(file.exists("data/processed/social_signatures_and_jsd.rds"))
stopifnot(file.exists("data/processed/parametric_models.rds"))
stopifnot(file.exists("data/processed/alter_survey_attributes.rds"))
stopifnot(file.exists("data/processed/egonet_topology_by_wave.rds"))
stopifnot(file.exists("data/processed/ego_psychometrics_longitudinal.rds"))
stopifnot(file.exists("data/processed/turnover_and_divergence.rds"))

sig_data   <- readRDS("data/processed/social_signatures_and_jsd.rds")
param_data <- readRDS("data/processed/parametric_models.rds")
alter_attr <- readRDS("data/processed/alter_survey_attributes.rds")
egonet_top <- readRDS("data/processed/egonet_topology_by_wave.rds")
ego_psych  <- readRDS("data/processed/ego_psychometrics_longitudinal.rds")
turnover_d <- readRDS("data/processed/turnover_and_divergence.rds")

# ==============================================================================
# 1. Dyadic Correspondence: Signature Rank Tiers vs Survey Support Dimensions
# ==============================================================================
cat("\nAnalyzing dyadic correspondence between Signature Rank and Survey Support...\n")
sem_sig_dt <- sig_data$semester$sig_dt

# Expand each ego-window into ranked dyad records
dyad_rows <- list()
for (i in 1:nrow(sem_sig_dt)) {
  alts <- sem_sig_dt$alters[[i]]
  props <- sem_sig_dt$signature[[i]]
  wts <- sem_sig_dt$weights[[i]]
  k <- length(alts)
  if (k == 0) next
  
  dyad_rows[[length(dyad_rows) + 1]] <- tibble(
    egoid = sem_sig_dt$egoid[i],
    window = sem_sig_dt$window[i],
    alterid = alts,
    rank = 1:k,
    proportion = props,
    calls = wts
  )
}
dyad_df <- bind_rows(dyad_rows)

# Create theoretical rank tiers
dyad_df <- dyad_df %>%
  mutate(
    rank_tier = case_when(
      rank == 1 ~ "Rank 1 (Core)",
      rank %in% 2:3 ~ "Ranks 2-3",
      rank %in% 4:5 ~ "Ranks 4-5",
      rank %in% 6:10 ~ "Ranks 6-10",
      rank %in% 11:20 ~ "Ranks 11-20",
      TRUE ~ "Ranks >20"
    ),
    rank_tier = factor(rank_tier, levels = c(
      "Rank 1 (Core)", "Ranks 2-3", "Ranks 4-5", "Ranks 6-10", "Ranks 11-20", "Ranks >20"
    ))
  )

# Merge with alter survey attributes (ensure character IDs)
dyad_df$egoid <- as.character(dyad_df$egoid)
dyad_df$alterid <- as.character(dyad_df$alterid)
alter_attr$egoid <- as.character(alter_attr$egoid)
alter_attr$alterid <- as.character(alter_attr$alterid)

dyad_merged <- inner_join(dyad_df, alter_attr, by = c("egoid", "alterid"))

cat(sprintf("Matched %s call-ranked dyads to survey nomination profiles.\n",
            format(nrow(dyad_merged), big.mark = ",")))

# Compute support proportions across rank tiers
tier_summary <- dyad_merged %>%
  group_by(rank_tier) %>%
  summarise(
    n_ties = n(),
    pct_family = mean(is_family, na.rm = TRUE) * 100,
    pct_friend = mean(is_friend, na.rm = TRUE) * 100,
    pct_emotional = mean(provides_emotional, na.rm = TRUE) * 100,
    pct_advice = mean(provides_advice, na.rm = TRUE) * 100,
    pct_companionship = mean(provides_companionship, na.rm = TRUE) * 100,
    pct_financial = mean(provides_financial, na.rm = TRUE) * 100,
    mean_closeness = mean(mean_closeness, na.rm = TRUE),
    .groups = "drop"
  )

print(tier_summary)
write_csv(tier_summary, "output/tables/signature_rank_by_support_tiers.csv")
cat("Saved tier support summary to output/tables/signature_rank_by_support_tiers.csv\n")

# ==============================================================================
# 2. Longitudinal Multilevel Models of Signature Divergence
# ==============================================================================
cat("\nEstimating linear mixed-effects models predicting Self-Divergence (JSD)...\n")
turnover_sem <- turnover_d$turnover_semester

# Merge baseline ego psychometrics (Wave 1)
ego_psych_w1 <- ego_psych %>%
  filter(wave == 1) %>%
  select(egoid, extraversion, agreeableness, conscientiousness, neuroticism, openness,
         cesd_depression, loneliness)

# Mean egonet topology per ego across waves
ego_topo_mean <- egonet_top %>%
  group_by(egoid) %>%
  summarise(
    egonet_deg = mean(deg, na.rm = TRUE),
    egonet_density = mean(density, na.rm = TRUE),
    egonet_clustering = mean(clustering, na.rm = TRUE),
    egonet_modularity = mean(modularity, na.rm = TRUE),
    egonet_constraint = mean(constraint, na.rm = TRUE),
    .groups = "drop"
  )

# Assemble panel regression dataset
reg_df <- turnover_sem %>%
  left_join(ego_psych_w1, by = "egoid") %>%
  left_join(ego_topo_mean, by = "egoid") %>%
  filter(!is.na(self_jsd) & !is.na(turnover))

cat(sprintf("Assembled panel dataset with %d observations across %d egos.\n",
            nrow(reg_df), uniqueN(reg_df$egoid)))

# Save integrated covariates dataset
saveRDS(reg_df, "data/processed/ego_expansion_covariates.rds")

# Model 1: Turnover only
m1 <- lmer(self_jsd ~ turnover + (1 | egoid), data = reg_df)

# Model 2: Turnover + Activity change + Egonet clustering & density
m2 <- lmer(self_jsd ~ turnover + pct_activity_change + egonet_clustering + egonet_density + (1 | egoid), 
           data = reg_df)

# Model 3: Full model adding Personality & Well-being
m3 <- lmer(self_jsd ~ turnover + pct_activity_change + egonet_clustering + 
             extraversion + neuroticism + cesd_depression + (1 | egoid), 
           data = reg_df)

# Tidy summary of models
tidy_lmer <- function(mod, model_name) {
  cf <- summary(mod)$coefficients
  tibble(
    model = model_name,
    term = rownames(cf),
    estimate = cf[, "Estimate"],
    std.error = cf[, "Std. Error"],
    statistic = cf[, "t value"]
  )
}

t1 <- tidy_lmer(m1, "Model 1: Turnover")
t2 <- tidy_lmer(m2, "Model 2: Structural Topology")
t3 <- tidy_lmer(m3, "Model 3: Integrated Full")

table04 <- bind_rows(t1, t2, t3) %>%
  select(model, term, estimate, std.error, statistic) %>%
  mutate(
    p_value = 2 * (1 - pnorm(abs(statistic))),
    stars = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01  ~ "**",
      p_value < 0.05  ~ "*",
      TRUE ~ ""
    )
  )

print(table04)
write_csv(table04, "output/tables/table04_multilevel_regression_results.csv")
cat("Saved multilevel regression results to output/tables/table04_multilevel_regression_results.csv\n")

# ==============================================================================
# 3. Personality Determinants of Social Signature Shape (Power-Law Alpha)
# ==============================================================================
cat("\nEstimating models linking Big Five Personality to Signature Alpha (Steepness)...\n")
sem_models <- param_data$semester_models

# Ego average power-law alpha
ego_param_mean <- sem_models %>%
  group_by(egoid) %>%
  summarise(
    mean_alpha = mean(pl_alpha, na.rm = TRUE),
    mean_alters = mean(k_alters, na.rm = TRUE),
    mean_pl_r2 = mean(pl_r2, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(ego_psych_w1, by = "egoid") %>%
  left_join(ego_topo_mean, by = "egoid") %>%
  filter(!is.na(mean_alpha) & !is.na(extraversion))

# OLS Regression: Alpha ~ Big 5
m_alpha <- lm(mean_alpha ~ extraversion + neuroticism + agreeableness + conscientiousness + openness + egonet_deg,
              data = ego_param_mean)

table05 <- tidy(m_alpha) %>%
  mutate(
    stars = case_when(
      p.value < 0.001 ~ "***",
      p.value < 0.01  ~ "**",
      p.value < 0.05  ~ "*",
      TRUE ~ ""
    )
  )

print(table05)
write_csv(table05, "output/tables/table05_personality_signature_models.csv")
cat("Saved personality determinant models to output/tables/table05_personality_signature_models.csv\n")

# Save model objects
saveRDS(list(
  dyad_merged = dyad_merged,
  tier_summary = tier_summary,
  model1_turnover = m1,
  model2_topology = m2,
  model3_integrated = m3,
  model_alpha_personality = m_alpha,
  ego_param_covariates = ego_param_mean
), "data/processed/expansion_models.rds")

cat("\n>>> Step 6 completed successfully! Saved to data/processed/expansion_models.rds\n")
