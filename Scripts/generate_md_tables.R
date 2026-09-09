#!/usr/bin/env Rscript
# ==============================================================================
# Scripts/generate_md_tables.R
# Pre-computes standardized markdown tables into cache/ for Word/Drive injection
# Adheres strictly to AGENTS.md APA 7th formatting rules
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(scales)
})

dir.create("cache", showWarnings = FALSE)

# Table 1: Cohort Summary
t1_raw <- read_csv("output/tables/table01_cohort_summary.csv", show_col_types = FALSE)
t1_md <- t1_raw %>%
  mutate(
    Windows = ifelse(is.na(Number_of_Windows), "--", as.character(Number_of_Windows)),
    Eligible_Egos = format(Eligible_Egos, big.mark = ",")
  ) %>%
  select(Scheme, `Window Span` = Window_Span, Windows, Criteria = Min_Alters_Criteria, `Eligible Egos` = Eligible_Egos)

writeLines(c(
  "| Scheme | Window Span | Windows | Criteria | Eligible Egos |",
  "|:-------|:------------|:-------:|:---------|:-------------:|",
  apply(t1_md, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
), "cache/table1_cohort_summary.md")

# Table 2: Stability Tests
t2_raw <- read_csv("output/tables/table02_stability_tests.csv", show_col_types = FALSE)
t2_md <- t2_raw %>%
  mutate(
    `Egos (N)` = format(N_Egos, big.mark = ","),
    `Self-JSD (SD)` = sprintf("%.4f (%.4f)", Mean_Self_JSD, SD_Self_JSD),
    `Ref-JSD (SD)`  = sprintf("%.4f (%.4f)", Mean_Ref_JSD, SD_Ref_JSD),
    `Difference`    = sprintf("%+.4f", Difference),
    `p-value`       = ifelse(Wilcoxon_p < 1e-12, "< 0.001", sprintf("%.4f", Wilcoxon_p))
  ) %>%
  select(Scheme, `Egos (N)`, `Self-JSD (SD)`, `Ref-JSD (SD)`, Difference, `p-value`)

writeLines(c(
  "| Scheme | Egos (N) | Self-JSD (SD) | Ref-JSD (SD) | Difference | p-value |",
  "|:-------|:--------:|:-------------:|:------------:|:----------:|:-------:|",
  apply(t2_md, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
), "cache/table2_stability_tests.md")

# Table 3: Parametric Comparison
t3_raw <- read_csv("output/tables/table03_parametric_comparison.csv", show_col_types = FALSE)
t3_md <- t3_raw %>%
  mutate(
    `Models (N)` = format(Total_Models_Fitted, big.mark = ","),
    `Power-Law α (SD)` = sprintf("%.2f (%.2f)", Mean_PowerLaw_Alpha, SD_PowerLaw_Alpha),
    `Power-Law R²` = sprintf("%.3f", Mean_PowerLaw_R2),
    `Exp β` = sprintf("%.2f", Mean_Exp_Beta),
    `Exp R²` = sprintf("%.3f", Mean_Exp_R2),
    `% PL Preferred` = sprintf("%.1f%%", Pct_PowerLaw_Preferred_AIC)
  ) %>%
  select(Scheme, `Models (N)`, `Power-Law α (SD)`, `Power-Law R²`, `Exp β`, `Exp R²`, `% PL Preferred`)

writeLines(c(
  "| Scheme | Models (N) | Power-Law α (SD) | Power-Law R² | Exp β | Exp R² | % PL Preferred |",
  "|:-------|:----------:|:----------------:|:------------:|:-----:|:------:|:--------------:|",
  apply(t3_md, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
), "cache/table3_parametric_models.md")

# Table 4: Support Tiers
t4_raw <- read_csv("output/tables/signature_rank_by_support_tiers.csv", show_col_types = FALSE)
t4_md <- t4_raw %>%
  mutate(
    `Ties (N)` = format(n_ties, big.mark = ","),
    `% Family` = sprintf("%.1f%%", pct_family),
    `% Friend` = sprintf("%.1f%%", pct_friend),
    `% Emotional` = sprintf("%.1f%%", pct_emotional),
    `% Advice` = sprintf("%.1f%%", pct_advice),
    `% Companionship` = sprintf("%.1f%%", pct_companionship),
    `% Financial` = sprintf("%.1f%%", pct_financial)
  ) %>%
  select(`Rank Tier` = rank_tier, `Ties (N)`, `% Family`, `% Friend`, `% Emotional`, `% Advice`, `% Companionship`, `% Financial`)

writeLines(c(
  "| Rank Tier | Ties (N) | % Family | % Friend | % Emotional | % Advice | % Companionship | % Financial |",
  "|:----------|:--------:|:--------:|:--------:|:-----------:|:--------:|:---------------:|:-----------:|",
  apply(t4_md, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
), "cache/table4_support_tiers.md")

# Table 5: Multilevel Regressions
t5_raw <- read_csv("output/tables/table04_multilevel_regression_results.csv", show_col_types = FALSE)
t5_wide <- t5_raw %>%
  mutate(
    term_clean = case_when(
      term == "(Intercept)" ~ "Intercept",
      term == "turnover" ~ "Alter Turnover (1 - Jaccard)",
      term == "pct_activity_change" ~ "% Activity Change (|ΔCalls|/Calls)",
      term == "egonet_clustering" ~ "Ego Network Clustering Coefficient",
      term == "egonet_density" ~ "Ego Network Density",
      term == "extraversion" ~ "Baseline Extraversion",
      term == "neuroticism" ~ "Baseline Negative Emotionality",
      term == "cesd_depression" ~ "Baseline CES-D Depression",
      TRUE ~ term
    ),
    est_str = sprintf("%.3f%s (%.4f)", estimate, stars, std.error)
  ) %>%
  select(model, term_clean, est_str) %>%
  pivot_wider(names_from = model, values_from = est_str, values_fill = "--")

writeLines(c(
  "| Predictor Term | Model 1 (Turnover) | Model 2 (Topology) | Model 3 (Integrated) |",
  "|:---------------|:------------------:|:------------------:|:--------------------:|",
  apply(t5_wide, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
), "cache/table5_multilevel_models.md")

# Table 6: Personality Determinants of Alpha
t6_raw <- read_csv("output/tables/table05_personality_signature_models.csv", show_col_types = FALSE)
t6_md <- t6_raw %>%
  mutate(
    term_clean = case_when(
      term == "(Intercept)" ~ "Intercept",
      term == "extraversion" ~ "Extraversion",
      term == "neuroticism" ~ "Negative Emotionality",
      term == "agreeableness" ~ "Agreeableness",
      term == "conscientiousness" ~ "Conscientiousness",
      term == "openness" ~ "Openness",
      term == "egonet_deg" ~ "Personal Network Degree",
      TRUE ~ term
    ),
    Estimate = sprintf("%.3f%s", estimate, stars),
    `Std. Error` = sprintf("(%.3f)", std.error),
    `t value` = sprintf("%.2f", statistic),
    `p-value` = ifelse(p.value < 0.001, "< 0.001", sprintf("%.4f", p.value))
  ) %>%
  select(Term = term_clean, Estimate, `Std. Error`, `t value`, `p-value`)

writeLines(c(
  "| Term | Estimate | Std. Error | t value | p-value |",
  "|:-----|:--------:|:----------:|:-------:|:-------:|",
  apply(t6_md, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
), "cache/table6_personality_models.md")

cat("Generated all markdown tables into cache/\n")
