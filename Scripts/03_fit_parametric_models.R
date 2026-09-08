#!/usr/bin/env Rscript
# ==============================================================================
# Script 03: Fit Parametric Models (Power-law vs Exponential & Burn-in)
# Project: Social Signatures in NetHealth
# Description: Implements Chandler (2019) Slides 20, 24, 25:
#              - Power-law: p(r) = c * r^(-alpha)
#              - Exponential: p(r) = c * exp(-beta * r)
#              - Model evaluation (R2, AIC, BIC) across egos and windows
#              - Ego variation in parameters and burn-in convergence analysis
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
})

cat(">>> Step 3: Loading social signature datasets...\n")
stopifnot(file.exists("data/processed/social_signatures_and_jsd.rds"))
sig_data <- readRDS("data/processed/social_signatures_and_jsd.rds")

# ==============================================================================
# Parametric Fitting Functions
# ==============================================================================
compute_signature <- function(alter_weights) {
  w_sorted <- sort(alter_weights, decreasing = TRUE)
  tot <- sum(w_sorted)
  if (tot == 0) rep(0, length(w_sorted)) else w_sorted / tot
}

fit_models_for_signature <- function(sig) {
  k <- length(sig)
  if (k < 3) return(NULL) # need at least 3 ranks for meaningful fit
  
  ranks <- 1:k
  props <- sig
  
  # Power-law: log(p) = log(c) - alpha * log(r)
  df_fit <- data.frame(rank = ranks, prop = props, log_rank = log(ranks), log_prop = log(props))
  
  pl_lm <- tryCatch(lm(log_prop ~ log_rank, data = df_fit), error = function(e) NULL)
  exp_lm <- tryCatch(lm(log_prop ~ rank, data = df_fit), error = function(e) NULL)
  
  if (is.null(pl_lm) || is.null(exp_lm)) return(NULL)
  
  pl_sum <- summary(pl_lm)
  exp_sum <- summary(exp_lm)
  
  # Parameters
  pl_alpha <- -coef(pl_lm)[2]
  pl_alpha_p <- pl_sum$coefficients[2, 4]
  pl_c <- exp(coef(pl_lm)[1])
  pl_r2 <- pl_sum$r.squared
  pl_aic <- AIC(pl_lm)
  pl_bic <- BIC(pl_lm)
  pl_rmse <- sqrt(mean(pl_lm$residuals^2))
  
  exp_beta <- -coef(exp_lm)[2]
  exp_beta_p <- exp_sum$coefficients[2, 4]
  exp_c <- exp(coef(exp_lm)[1])
  exp_r2 <- exp_sum$r.squared
  exp_aic <- AIC(exp_lm)
  exp_bic <- BIC(exp_lm)
  exp_rmse <- sqrt(mean(exp_lm$residuals^2))
  
  tibble(
    k_alters = k,
    # Power law
    pl_alpha = pl_alpha,
    pl_alpha_p = pl_alpha_p,
    pl_c = pl_c,
    pl_r2 = pl_r2,
    pl_aic = pl_aic,
    pl_bic = pl_bic,
    pl_rmse = pl_rmse,
    # Exponential
    exp_beta = exp_beta,
    exp_beta_p = exp_beta_p,
    exp_c = exp_c,
    exp_r2 = exp_r2,
    exp_aic = exp_aic,
    exp_bic = exp_bic,
    exp_rmse = exp_rmse,
    # Comparison
    delta_aic = exp_aic - pl_aic, # positive means Power-law is better
    pl_preferred = pl_aic < exp_aic
  )
}

# 1. Fit for Semester Windows
cat("Fitting parametric models for Semester scheme...\n")
sem_sig_dt <- sig_data$semester$sig_dt

sem_models_list <- list()
for (i in 1:nrow(sem_sig_dt)) {
  res <- fit_models_for_signature(sem_sig_dt$signature[[i]])
  if (!is.null(res)) {
    res$egoid <- sem_sig_dt$egoid[i]
    res$window <- sem_sig_dt$window[i]
    sem_models_list[[length(sem_models_list) + 1]] <- res
  }
}
sem_models_df <- bind_rows(sem_models_list)

# 2. Fit for Month Windows
cat("Fitting parametric models for Month scheme...\n")
mo_sig_dt <- sig_data$month$sig_dt

mo_models_list <- list()
for (i in 1:nrow(mo_sig_dt)) {
  res <- fit_models_for_signature(mo_sig_dt$signature[[i]])
  if (!is.null(res)) {
    res$egoid <- mo_sig_dt$egoid[i]
    res$window <- mo_sig_dt$window[i]
    mo_models_list[[length(mo_models_list) + 1]] <- res
  }
}
mo_models_df <- bind_rows(mo_models_list)

# Summary of Power-law significance (Slide 20: "Both parameters statistically significant at p < 0.00001")
pct_pl_sig_sem <- mean(sem_models_df$pl_alpha_p < 1e-4, na.rm = TRUE) * 100
pct_pl_pref_sem <- mean(sem_models_df$pl_preferred, na.rm = TRUE) * 100

pct_pl_sig_mo <- mean(mo_models_df$pl_alpha_p < 1e-4, na.rm = TRUE) * 100
pct_pl_pref_mo <- mean(mo_models_df$pl_preferred, na.rm = TRUE) * 100

cat(sprintf("\nSemester Models (N = %d):\n", nrow(sem_models_df)))
cat(sprintf("  - Power-law alpha significant (p < 0.0001): %.1f%%\n", pct_pl_sig_sem))
cat(sprintf("  - Mean Power-law R2: %.3f (SD: %.3f)\n", mean(sem_models_df$pl_r2), sd(sem_models_df$pl_r2)))
cat(sprintf("  - Mean Exponential R2: %.3f (SD: %.3f)\n", mean(sem_models_df$exp_r2), sd(sem_models_df$exp_r2)))
cat(sprintf("  - Power-law preferred by AIC: %.1f%%\n", pct_pl_pref_sem))

cat(sprintf("\nMonth Models (N = %d):\n", nrow(mo_models_df)))
cat(sprintf("  - Power-law alpha significant (p < 0.0001): %.1f%%\n", pct_pl_sig_mo))
cat(sprintf("  - Mean Power-law R2: %.3f (SD: %.3f)\n", mean(mo_models_df$pl_r2, na.rm = TRUE), sd(mo_models_df$pl_r2, na.rm = TRUE)))
cat(sprintf("  - Mean Exponential R2: %.3f (SD: %.3f)\n", mean(mo_models_df$exp_r2, na.rm = TRUE), sd(mo_models_df$exp_r2, na.rm = TRUE)))
cat(sprintf("  - Power-law preferred by AIC: %.1f%%\n", pct_pl_pref_mo))

# ==============================================================================
# 3. Burn-in & Parameter Convergence Analysis (Slide 25)
#    "How long before ego's model is stable?"
# ==============================================================================
cat("\nAnalyzing parameter burn-in across cumulative observation windows...\n")
windows_data <- readRDS("data/processed/call_windows.rds")
calls_cal <- windows_data$calls_cal
common_egos <- windows_data$common_calendar_egos

# For common cohort egos, calculate cumulative signatures from month 1 to month M (M = 1..24)
all_months <- sort(unique(calls_cal$month))
burnin_list <- list()

for (m_idx in 2:length(all_months)) {
  m_sub <- calls_cal[egoid %in% common_egos & month %in% all_months[1:m_idx]]
  cum_agg <- m_sub[, .(calls = .N), by = .(egoid, alterid)]
  
  # For each ego, compute signature and fit power law
  for (ego in common_egos) {
    ego_calls <- cum_agg[egoid == ego, calls]
    if (length(ego_calls) >= 3) {
      sig <- compute_signature(ego_calls)
      fit <- fit_models_for_signature(sig)
      if (!is.null(fit)) {
        burnin_list[[length(burnin_list) + 1]] <- tibble(
          egoid = ego,
          cumulative_months = m_idx,
          end_month = all_months[m_idx],
          k_alters = fit$k_alters,
          alpha = fit$pl_alpha,
          r2 = fit$pl_r2,
          rmse = fit$pl_rmse
        )
      }
    }
  }
}
burnin_df <- bind_rows(burnin_list)

# Check stability of alpha relative to final 24-month alpha
final_alpha <- burnin_df %>%
  filter(cumulative_months == length(all_months)) %>%
  select(egoid, final_alpha = alpha)

burnin_convergence <- burnin_df %>%
  inner_join(final_alpha, by = "egoid") %>%
  mutate(alpha_abs_error = abs(alpha - final_alpha)) %>%
  group_by(cumulative_months) %>%
  summarise(
    mean_alpha = mean(alpha, na.rm = TRUE),
    sd_alpha = sd(alpha, na.rm = TRUE),
    mean_abs_error = mean(alpha_abs_error, na.rm = TRUE),
    median_abs_error = median(alpha_abs_error, na.rm = TRUE),
    mean_r2 = mean(r2, na.rm = TRUE),
    mean_alters = mean(k_alters, na.rm = TRUE),
    .groups = "drop"
  )

cat("Burn-in convergence summary (first 8 cumulative months):\n")
print(head(burnin_convergence, 8))

# Save Table 03: Parametric Model Comparison
table03 <- tibble(
  Scheme = c("Semesters", "Months"),
  Total_Models_Fitted = c(nrow(sem_models_df), nrow(mo_models_df)),
  Mean_PowerLaw_Alpha = c(mean(sem_models_df$pl_alpha, na.rm = TRUE), mean(mo_models_df$pl_alpha, na.rm = TRUE)),
  SD_PowerLaw_Alpha   = c(sd(sem_models_df$pl_alpha, na.rm = TRUE), sd(mo_models_df$pl_alpha, na.rm = TRUE)),
  Mean_PowerLaw_R2    = c(mean(sem_models_df$pl_r2, na.rm = TRUE), mean(mo_models_df$pl_r2, na.rm = TRUE)),
  Mean_Exp_Beta       = c(mean(sem_models_df$exp_beta, na.rm = TRUE), mean(mo_models_df$exp_beta, na.rm = TRUE)),
  Mean_Exp_R2         = c(mean(sem_models_df$exp_r2, na.rm = TRUE), mean(mo_models_df$exp_r2, na.rm = TRUE)),
  Pct_PowerLaw_Preferred_AIC = c(pct_pl_pref_sem, pct_pl_pref_mo),
  Pct_Alpha_p_lt_0001 = c(pct_pl_sig_sem, pct_pl_sig_mo)
)
write_csv(table03, "output/tables/table03_parametric_comparison.csv")
cat("\nSaved parametric comparison table to output/tables/table03_parametric_comparison.csv\n")

# Save all models and burn-in datasets
saveRDS(list(
  semester_models = sem_models_df,
  month_models = mo_models_df,
  burnin_df = burnin_df,
  burnin_convergence = burnin_convergence
), "data/processed/parametric_models.rds")

cat(">>> Step 3 completed successfully! Saved to data/processed/parametric_models.rds\n")
