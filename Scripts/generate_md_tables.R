#!/usr/bin/env Rscript
# ==============================================================================
# Scripts/generate_md_tables.R
# Pre-computes standardized markdown tables into cache/ for Word/Drive injection
# Adheres strictly to AGENTS.md APA 7th formatting rules
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(scales)
  library(lme4)
})

# OUT_DIR is overridable via the MD_TABLES_OUT_DIR env var so that
# Scripts/check_cache_staleness.R can regenerate these tables into a scratch
# directory and diff them against the committed cache/ files, without ever
# overwriting cache/ itself as a side effect of running the check.
OUT_DIR <- Sys.getenv("MD_TABLES_OUT_DIR", "cache")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

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
), file.path(OUT_DIR, "table1_cohort_summary.md"))

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
), file.path(OUT_DIR, "table2_stability_tests.md"))

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
), file.path(OUT_DIR, "table3_parametric_models.md"))

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
), file.path(OUT_DIR, "table4_support_tiers.md"))

# Table 5: Multilevel Regressions
# NOTE: cesd_depression is dropped per AGENTS.md Lesson 14 (psychometric modeling
# in this project is scoped strictly to Big Five traits; CES-D is not reported).
# NOTE: `stars` is blank (NA after CSV round-trip) for non-significant terms, so it
# must be coalesced to "" before pasting into the formatted string, otherwise it
# prints the literal text "NA". Coefficient precision is chosen adaptively (5
# decimals for terms below 0.001 in magnitude, 3 otherwise) so that small-magnitude
# terms like pct_activity_change are not rounded to "0.000".
t5_raw <- read_csv("output/tables/table04_multilevel_regression_results.csv", show_col_types = FALSE) %>%
  filter(term != "cesd_depression") %>%
  mutate(stars = tidyr::replace_na(stars, ""))

t5_wide <- t5_raw %>%
  mutate(
    term_clean = case_when(
      term == "(Intercept)" ~ "Intercept",
      term == "turnover" ~ "Alter Turnover (1 - Jaccard)",
      term == "pct_activity_change" ~ "% Activity Change (|\u0394Events|/Events)",
      term == "egonet_clustering" ~ "Ego Network Clustering Coefficient",
      term == "egonet_density" ~ "Ego Network Density",
      term == "extraversion" ~ "Baseline Extraversion",
      term == "neuroticism" ~ "Baseline Negative Emotionality",
      TRUE ~ term
    ),
    est_dec = ifelse(abs(estimate) < 0.001, 5, 3),
    est_fmt = paste0("%.", est_dec, "f%s (%.", est_dec, "f)"),
    est_str = sprintf(est_fmt, estimate, stars, std.error)
  ) %>%
  select(model, term_clean, est_str) %>%
  pivot_wider(names_from = model, values_from = est_str, values_fill = "--")

writeLines(c(
  "| Predictor Term | Model 1 (Turnover) | Model 2 (Topology) | Model 3 (Integrated) |",
  "|:---------------|:------------------:|:------------------:|:--------------------:|",
  apply(t5_wide, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
), file.path(OUT_DIR, "table5_multilevel_models.md"))

# Table 4b: Tie-Attribute Regressions (Evaluative/Cognitive Alignment, Table S4)
# Coefficients come from Scripts/06b_tie_attribute_models.R's saved CSV; the
# ego random-intercept variance components (tau00, sigma2, ICC) are not part of
# that CSV, so they are recomputed here from the cached lmer model objects in
# data/processed/tie_attribute_models.rds. This keeps the cache file tied to the
# pipeline instead of requiring hand edits whenever the underlying data changes.
if (file.exists("output/tables/table04b_tie_attribute_regressions.csv") &&
    file.exists("data/processed/tie_attribute_models.rds")) {

  t4b_raw <- read_csv("output/tables/table04b_tie_attribute_regressions.csv", show_col_types = FALSE)
  tie_obj <- readRDS("data/processed/tie_attribute_models.rds")

  term_order_4b <- c("(Intercept)", "mean_closeness", "mean_trust", "mean_duration", "cognitive_salience")
  term_labels_4b <- c(
    "(Intercept)"        = "Intercept",
    "mean_closeness"     = "Subjective Closeness (1\u20134)",
    "mean_trust"         = "Interpersonal Trust (1\u201310)",
    "mean_duration"      = "Tie Duration (Years)",
    "cognitive_salience" = "Cognitive Salience (26 - Order)"
  )

  t4b_wide <- t4b_raw %>%
    mutate(
      term = factor(term, levels = term_order_4b),
      term_clean = term_labels_4b[as.character(term)],
      stars = case_when(
        p_value < 0.0001 ~ "***",
        p_value < 0.01   ~ "**",
        p_value < 0.05   ~ "*",
        TRUE             ~ ""
      ),
      # Model 4's outcome is the raw signature rank (1-26 scale), so its
      # coefficients are naturally larger in magnitude than the proportion-
      # scale coefficients in Models 1-3; use fewer decimals for Model 4
      # rather than thresholding on estimate magnitude, which would otherwise
      # truncate Model 1-3's small proportion coefficients (e.g. -0.1240).
      est_dec = ifelse(grepl("Full Rank", model), 2, 4),
      est_fmt = paste0("%.", est_dec, "f%s (%.", est_dec, "f)"),
      est_str = sprintf(est_fmt, estimate, stars, std.error)
    ) %>%
    arrange(term) %>%
    select(model, term_clean, est_str) %>%
    pivot_wider(names_from = model, values_from = est_str, values_fill = "--")

  icc_stats <- function(mod) {
    vc <- as.data.frame(VarCorr(mod))
    tau00 <- vc$vcov[vc$grp == "egoid"]
    sigma2 <- vc$vcov[vc$grp == "Residual"]
    list(tau00 = tau00, sigma2 = sigma2, icc = tau00 / (tau00 + sigma2))
  }

  n_obs <- format(nrow(tie_obj$model_df), big.mark = ",")
  n_ego <- as.character(n_distinct(tie_obj$model_df$egoid))
  model_cols <- names(t4b_wide)[-1]
  model_objs <- list(tie_obj$model1, tie_obj$model2, tie_obj$model3, tie_obj$model4)
  dep_vars <- c("Comm. Proportion ($p$)", "Comm. Proportion ($p$)",
                "Comm. Proportion ($p$)", "Signature Rank ($r$)")

  # Variance-component decimals follow the same Model-4-is-a-different-scale
  # logic as the coefficients above (Model 4's rank-scale variances are two
  # to four orders of magnitude larger than Models 1-3's proportion-scale ones).
  var_dec <- ifelse(grepl("Full Rank", model_cols), 2, 5)

  footer_4b <- bind_rows(
    tibble(term_clean = "Dependent Variable", !!!setNames(as.list(dep_vars), model_cols)),
    tibble(term_clean = "Dyad-Window Observations", !!!setNames(as.list(rep(n_obs, 4)), model_cols)),
    tibble(term_clean = "Ego Clusters", !!!setNames(as.list(rep(n_ego, 4)), model_cols)),
    tibble(term_clean = "Ego Random Variance (tau00)",
           !!!setNames(as.list(sprintf(paste0("%.", var_dec, "f"), sapply(model_objs, function(m) icc_stats(m)$tau00))), model_cols)),
    tibble(term_clean = "Residual Variance (sigma2)",
           !!!setNames(as.list(sprintf(paste0("%.", var_dec, "f"), sapply(model_objs, function(m) icc_stats(m)$sigma2))), model_cols)),
    tibble(term_clean = "Intraclass Correlation (ICC)",
           !!!setNames(as.list(sprintf("%.3f", sapply(model_objs, function(m) icc_stats(m)$icc))), model_cols))
  )

  t4b_full <- bind_rows(t4b_wide, footer_4b)

  writeLines(c(
    "| Predictor Term | Model 1 (Evaluative) | Model 2 (+ Duration) | Model 3 (+ Salience) | Model 4 (Full Rank) |",
    "|:---------------|:--------------------:|:--------------------:|:--------------------:|:-------------------:|",
    apply(t4b_full, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  ), file.path(OUT_DIR, "table4b_tie_regressions.md"))
} else {
  cat("Skipping Table 4b (tie-attribute regressions): required pipeline outputs not found.\n")
}

cat(sprintf("Generated all markdown tables into %s/\n", OUT_DIR))
