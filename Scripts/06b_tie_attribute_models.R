#!/usr/bin/env Rscript
# ==============================================================================
# Script 06b: Tie-Attribute Models of Signature Allocation and Rank
# Project: Social Signatures in NetHealth
# Description: Reconstructs the evaluative/cognitive alignment analysis cited
#              in the manuscript (Figure 5b / Table 4b) that was previously
#              generated ad hoc without a saved script. Links communication
#              signature rank/proportion to three ego-network survey tie
#              attributes:
#                - Subjective closeness ("close": Distant/LessThanClose/
#                  MerelyClose/EspeciallyClose, treated as an ordered 1-4 scale)
#                - Interpersonal trust ("trust": 1-10 scale)
#                - Tie duration ("duration": categorical year bins, recoded to
#                  numeric year midpoints)
#                - Cognitive salience ("position": the alter's nomination/
#                  recall order in the survey elicitation; lower = more salient)
#              Estimates linear mixed-effects models with ego random intercepts
#              (lme4::lmer), since ties are nested within egos.
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lme4)
  library(broom.mixed)
  library(data.table)
})

cat(">>> Step 6b: Loading network survey and social signature data...\n")
stopifnot(file.exists("data/raw/network_survey.csv"))
stopifnot(file.exists("data/processed/social_signatures_and_jsd.rds"))

net_df <- fread("data/raw/network_survey.csv",
                 select = c("egoid", "alterid", "wave", "position", "close", "trust", "duration"))
net_df[, egoid := as.character(egoid)]
net_df[, alterid := as.character(alterid)]

# ------------------------------------------------------------------------------
# Recode subjective closeness to an ordered 1-4 scale and tie duration from
# categorical year bins to numeric year midpoints.
# ------------------------------------------------------------------------------
closeness_map <- c("Distant" = 1, "LessThanClose" = 2, "MerelyClose" = 3, "EspeciallyClose" = 4)
duration_map <- c(
  "LessThan1" = 0.5, "1+" = 1, "2+" = 2, "3+" = 3, "4+" = 4, "5+" = 5,
  "6+" = 6, "7+" = 7, "8+" = 8, "9+" = 9, "10+" = 10,
  "11to12" = 11.5, "13to14" = 13.5, "15to16" = 15.5, "17to18" = 17.5,
  "19to20" = 19.5, "MoreThan20" = 21
)

net_df[, closeness_num := closeness_map[close]]
net_df[, duration_years := duration_map[duration]]

# Aggregate to one row per ego-alter dyad (mean across waves nominated;
# recall salience uses the BEST [lowest/most salient] position observed)
dyad_survey <- net_df[, .(
  mean_closeness   = mean(closeness_num, na.rm = TRUE),
  especially_close = mean(closeness_num == 4, na.rm = TRUE) >= 0.5,
  mean_trust       = mean(trust, na.rm = TRUE),
  mean_duration    = mean(duration_years, na.rm = TRUE),
  best_position    = min(position, na.rm = TRUE)
), by = .(egoid, alterid)]
dyad_survey[, cognitive_salience := 26 - best_position]
dyad_survey[is.infinite(mean_trust), mean_trust := NA_real_]

# ==============================================================================
# Build dyad-level communication signature records (Semester scheme)
# ==============================================================================
sig_data <- readRDS("data/processed/social_signatures_and_jsd.rds")
sem_sig_dt <- sig_data$semester$sig_dt

dyad_rows <- list()
for (i in 1:nrow(sem_sig_dt)) {
  alts <- sem_sig_dt$alters[[i]]
  props <- sem_sig_dt$signature[[i]]
  k <- length(alts)
  if (k == 0) next
  dyad_rows[[length(dyad_rows) + 1]] <- tibble(
    egoid = sem_sig_dt$egoid[i],
    window = sem_sig_dt$window[i],
    alterid = alts,
    rank = 1:k,
    proportion = props
  )
}
dyad_sig <- bind_rows(dyad_rows)
dyad_sig$egoid <- as.character(dyad_sig$egoid)
dyad_sig$alterid <- as.character(dyad_sig$alterid)

# Keep the dyad-WINDOW level structure (one row per ego-alter-semester
# observation, as in the original analysis), so that dyads appearing in
# multiple semester windows contribute multiple nested observations. Survey
# attributes (closeness, trust, duration, salience) are constant across
# windows for a given dyad since they are summarized across the full
# 8-wave survey period, not measured per-semester.
dyad_sig$rank_tier <- cut(
  dyad_sig$rank,
  breaks = c(0, 1, 3, 5, 10, 20, Inf),
  labels = c("Rank 1 (Core)", "Ranks 2-3", "Ranks 4-5", "Ranks 6-10", "Ranks 11-20", "Ranks >20")
)

tie_merged <- inner_join(dyad_sig, dyad_survey, by = c("egoid", "alterid")) %>%
  filter(!is.na(mean_closeness) | !is.na(mean_trust) | !is.na(mean_duration))

cat(sprintf("Matched %s dyad-window observations with evaluative/cognitive survey attributes across %d egos.\n",
            format(nrow(tie_merged), big.mark = ","), n_distinct(tie_merged$egoid)))

# ==============================================================================
# Evaluative/cognitive alignment summary across rank tiers (Figure 5b)
# ==============================================================================
tier_eval_summary <- tie_merged %>%
  group_by(rank_tier) %>%
  summarise(
    n_ties = n(),
    pct_especially_close = mean(especially_close, na.rm = TRUE) * 100,
    mean_duration_years = mean(mean_duration, na.rm = TRUE),
    median_duration_years = median(mean_duration, na.rm = TRUE),
    pct_recalled_top5 = mean(best_position <= 5, na.rm = TRUE) * 100,
    mean_recall_position = mean(best_position, na.rm = TRUE),
    .groups = "drop"
  )
print(tier_eval_summary)

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write_csv(tier_eval_summary, "output/tables/signature_rank_by_evaluative_cognitive_tiers.csv")
cat("Saved evaluative/cognitive tier summary to output/tables/signature_rank_by_evaluative_cognitive_tiers.csv\n")

# Correlations referenced in text
cor_close <- cor.test(tie_merged$mean_closeness, tie_merged$rank, method = "pearson")
cor_dur   <- cor.test(tie_merged$mean_duration, tie_merged$rank, method = "pearson")
cor_sal   <- cor.test(tie_merged$cognitive_salience, tie_merged$rank, method = "pearson")
cat(sprintf("\nCorrelations with signature rank:\n  Closeness: r = %.3f, p = %g\n  Duration:  r = %.3f, p = %g\n  Salience:  r = %.3f, p = %g\n",
            cor_close$estimate, cor_close$p.value, cor_dur$estimate, cor_dur$p.value, cor_sal$estimate, cor_sal$p.value))

# ==============================================================================
# Linear mixed-effects models with ego random intercepts (Table 4b)
# ==============================================================================
model_df <- tie_merged %>%
  filter(!is.na(mean_closeness), !is.na(mean_trust), !is.na(mean_duration), !is.na(cognitive_salience))

cat(sprintf("\nComplete-case dyadic model sample: N = %d ties across J = %d egos.\n",
            nrow(model_df), n_distinct(model_df$egoid)))

m1 <- lmer(proportion ~ mean_closeness + mean_trust + (1 | egoid), data = model_df)
m2 <- lmer(proportion ~ mean_closeness + mean_trust + mean_duration + (1 | egoid), data = model_df)
m3 <- lmer(proportion ~ mean_closeness + mean_trust + mean_duration + cognitive_salience + (1 | egoid), data = model_df)
m4 <- lmer(rank ~ mean_closeness + mean_trust + mean_duration + cognitive_salience + (1 | egoid), data = model_df)

icc <- function(mod) {
  vc <- as.data.frame(VarCorr(mod))
  tau00 <- vc$vcov[vc$grp == "egoid"]
  sigma2 <- vc$vcov[vc$grp == "Residual"]
  list(tau00 = tau00, sigma2 = sigma2, icc = tau00 / (tau00 + sigma2))
}

for (nm in c("m1", "m2", "m3", "m4")) {
  mod <- get(nm)
  ic <- icc(mod)
  cat(sprintf("%s: tau00 = %.5f, sigma2 = %.5f, ICC = %.3f\n", nm, ic$tau00, ic$sigma2, ic$icc))
}

tidy_lmer_full <- function(mod, model_name) {
  cf <- summary(mod)$coefficients
  tibble(
    model = model_name,
    term = rownames(cf),
    estimate = cf[, "Estimate"],
    std.error = cf[, "Std. Error"],
    statistic = cf[, "t value"]
  )
}

table4b <- bind_rows(
  tidy_lmer_full(m1, "Model 1 (Evaluative)"),
  tidy_lmer_full(m2, "Model 2 (+ Duration)"),
  tidy_lmer_full(m3, "Model 3 (+ Salience)"),
  tidy_lmer_full(m4, "Model 4 (Full Rank)")
) %>%
  mutate(p_value = 2 * (1 - pnorm(abs(statistic))))

print(table4b, n = 30)
write_csv(table4b, "output/tables/table04b_tie_attribute_regressions.csv")
cat("Saved tie-attribute regression results to output/tables/table04b_tie_attribute_regressions.csv\n")

saveRDS(list(
  tie_merged = tie_merged,
  tier_eval_summary = tier_eval_summary,
  model1 = m1, model2 = m2, model3 = m3, model4 = m4,
  model_df = model_df
), "data/processed/tie_attribute_models.rds")

cat("\n>>> Step 6b completed successfully! Saved to data/processed/tie_attribute_models.rds\n")
