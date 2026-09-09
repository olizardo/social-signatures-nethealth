#!/usr/bin/env Rscript
# ==============================================================================
# Script 07: Generate Publication Figures & Presentation Visualizations
# Project: Social Signatures in NetHealth
# Description: Produces replication figures (Chandler 2019 slides) and expansion
#              figures (support tiers, turnover dynamics, personality effects).
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
  library(data.table)
  library(scales)
})

cat(">>> Step 7: Loading data for figure generation...\n")
stopifnot(file.exists("data/processed/social_signatures_and_jsd.rds"))
stopifnot(file.exists("data/processed/parametric_models.rds"))
stopifnot(file.exists("data/processed/turnover_and_divergence.rds"))
stopifnot(file.exists("data/processed/expansion_models.rds"))

sig_data    <- readRDS("data/processed/social_signatures_and_jsd.rds")
param_data  <- readRDS("data/processed/parametric_models.rds")
turnover_d  <- readRDS("data/processed/turnover_and_divergence.rds")
expansion_d <- readRDS("data/processed/expansion_models.rds")

# NetHealth Publication Theme
theme_nethealth <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.1), hjust = 0),
      plot.subtitle = element_text(color = "grey30", size = rel(0.95), margin = margin(b = 8)),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey92", linewidth = 0.4),
      axis.title = element_text(face = "bold", size = rel(0.9)),
      legend.position = "bottom",
      legend.title = element_text(face = "bold", size = rel(0.85)),
      strip.text = element_text(face = "bold", size = rel(0.95)),
      plot.background = element_rect(fill = "white", color = NA)
    )
}

# ------------------------------------------------------------------------------
# Figure 1: Mean Social Signatures by Window Width (Replication Slide 7-11)
# ------------------------------------------------------------------------------
cat("Generating Figure 1: Mean Social Signatures across Window Schemes...\n")

extract_rank_props <- function(scheme_res, scheme_label, max_rank = 15) {
  sig_dt <- scheme_res$sig_dt
  rows <- list()
  for (i in 1:nrow(sig_dt)) {
    p <- sig_dt$signature[[i]]
    k <- min(length(p), max_rank)
    rows[[length(rows) + 1]] <- tibble(
      scheme = scheme_label,
      egoid = sig_dt$egoid[i],
      window = sig_dt$window[i],
      rank = 1:k,
      proportion = p[1:k]
    )
  }
  bind_rows(rows)
}

df_ranks <- bind_rows(
  extract_rank_props(sig_data$academic_year, "Academic Years (Jul-Jun)"),
  extract_rank_props(sig_data$semester, "Semesters (6-Month)"),
  extract_rank_props(sig_data$quarter, "Quarters (3-Month)"),
  extract_rank_props(sig_data$month, "Months (1-Month)"),
  extract_rank_props(sig_data$rolling_3week, "3-Week Rolling")
)

df_rank_summary <- df_ranks %>%
  group_by(scheme, rank) %>%
  summarise(
    mean_prop = mean(proportion),
    se_prop = sd(proportion) / sqrt(n()),
    p25 = quantile(proportion, 0.25),
    p75 = quantile(proportion, 0.75),
    .groups = "drop"
  )

p1 <- ggplot(df_rank_summary, aes(x = rank, y = mean_prop, color = scheme, fill = scheme)) +
  geom_ribbon(aes(ymin = mean_prop - 1.96 * se_prop, ymax = mean_prop + 1.96 * se_prop),
              alpha = 0.15, color = NA) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:15) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_color_brewer(palette = "Dark2") +
  scale_fill_brewer(palette = "Dark2") +
  guides(
    color = guide_legend(nrow = 2, byrow = TRUE),
    fill  = guide_legend(nrow = 2, byrow = TRUE)
  ) +
  labs(
    title = "Empirical Social Signatures across Temporal Window Resolutions",
    subtitle = "Ranked proportion of outgoing calls allocated to communication alters (Ranks 1–15)",
    x = "Alter Rank (Descending Call Frequency)",
    y = "Proportion of Total Communication Effort",
    color = "Window Definition:",
    fill = "Window Definition:"
  ) +
  theme_nethealth() +
  theme(legend.position = "bottom",
        legend.box = "horizontal",
        legend.margin = margin(t = 6, b = 2))

ggsave("output/plots/fig01_mean_signatures_by_window.png", p1, width = 8.5, height = 5.5, dpi = 300)
ggsave("Plots/fig01_mean_signatures_by_window.png", p1, width = 8.5, height = 5.5, dpi = 300)

# ------------------------------------------------------------------------------
# Figure 2: Self-Divergence vs Reference-Divergence (Replication Slide 14, 16, 17)
# ------------------------------------------------------------------------------
cat("Generating Figure 2: Self vs Reference Divergence Distributions...\n")

df_div_comp <- bind_rows(
  sig_data$academic_year$ego_comp %>% mutate(scheme = "Academic Years"),
  sig_data$semester$ego_comp %>% mutate(scheme = "Semesters"),
  sig_data$quarter$ego_comp %>% mutate(scheme = "Quarters"),
  sig_data$month$ego_comp %>% mutate(scheme = "Months"),
  sig_data$rolling_3week$ego_comp %>% mutate(scheme = "3-Week Rolling")
) %>%
  pivot_longer(cols = c(mean_self_jsd, mean_ref_jsd),
               names_to = "divergence_type", values_to = "jsd") %>%
  mutate(
    divergence_type = fifelse(divergence_type == "mean_self_jsd", 
                              "Self-Divergence (Intra-individual)", 
                              "Reference-Divergence (Inter-individual)"),
    scheme = factor(scheme, levels = c("Academic Years", "Semesters", "Quarters", "Months", "3-Week Rolling"))
  )

p2 <- ggplot(df_div_comp, aes(x = scheme, y = jsd, fill = divergence_type)) +
  geom_boxplot(outlier.size = 0.8, outlier.alpha = 0.5, width = 0.6, position = position_dodge(0.75)) +
  scale_fill_manual(values = c("Self-Divergence (Intra-individual)" = "#2b8cbe", 
                               "Reference-Divergence (Inter-individual)" = "#de2d26")) +
  scale_y_continuous(limits = c(0, 0.30), breaks = seq(0, 0.30, by = 0.05)) +
  labs(
    title = "Persistence of Social Signatures: Self vs. Reference Divergence",
    subtitle = "Pairwise Jensen-Shannon Divergence (JSD) showing strong intra-individual stability across all timescales",
    x = "Temporal Window Resolution",
    y = "Jensen-Shannon Divergence (JSD in bits)",
    fill = "Divergence Metric:"
  ) +
  theme_nethealth()

ggsave("output/plots/fig02_self_vs_ref_divergence.png", p2, width = 8.5, height = 5.5, dpi = 300)

# ------------------------------------------------------------------------------
# Figure 3: Power-Law vs Exponential Models (Replication Slide 20, 24)
# ------------------------------------------------------------------------------
cat("Generating Figure 3: Power-law vs Exponential Fits...\n")

sem_models <- param_data$semester_models

p3a <- ggplot(sem_models, aes(x = pl_r2, y = exp_r2)) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "grey40") +
  geom_point(alpha = 0.4, color = "#2ca25f", size = 1.5) +
  scale_x_continuous(limits = c(0.4, 1.0), breaks = seq(0.4, 1.0, 0.1)) +
  scale_y_continuous(limits = c(0.4, 1.0), breaks = seq(0.4, 1.0, 0.1)) +
  labs(
    title = "A. Goodness-of-Fit Comparison (R²)",
    subtitle = "Power-law R² vs Exponential R² across semester signatures",
    x = "Power-law Model R²",
    y = "Exponential Model R²"
  ) +
  theme_nethealth()

p3b <- ggplot(sem_models, aes(x = pl_alpha)) +
  geom_histogram(fill = "#3182bd", color = "white", bins = 35, alpha = 0.8) +
  geom_vline(aes(xintercept = mean(pl_alpha)), color = "red", linetype = "dashed", linewidth = 0.9) +
  labs(
    title = "B. Distribution of Power-Law Exponent (α)",
    subtitle = sprintf("Mean α = %.2f (SD = %.2f); red line indicates cohort mean", 
                       mean(sem_models$pl_alpha), sd(sem_models$pl_alpha)),
    x = "Power-law Decay Exponent (α)",
    y = "Frequency"
  ) +
  theme_nethealth()

p3 <- p3a + p3b
ggsave("output/plots/fig03_power_law_vs_exponential.png", p3, width = 10, height = 4.8, dpi = 300)

# ------------------------------------------------------------------------------
# Figure 4: Parameter Burn-In Convergence (Replication Slide 25)
# ------------------------------------------------------------------------------
cat("Generating Figure 4: Parameter Burn-in Convergence...\n")
conv_df <- param_data$burnin_convergence

p4 <- ggplot(conv_df, aes(x = cumulative_months)) +
  geom_line(aes(y = mean_alpha, color = "Mean Alpha (α)"), linewidth = 1) +
  geom_point(aes(y = mean_alpha, color = "Mean Alpha (α)"), size = 2) +
  geom_line(aes(y = mean_abs_error * 5 + 0.5, color = "Mean Absolute Error (vs 24m)"), 
            linewidth = 1, linetype = "dotdash") +
  geom_point(aes(y = mean_abs_error * 5 + 0.5, color = "Mean Absolute Error (vs 24m)"), size = 2) +
  scale_x_continuous(breaks = seq(2, 24, by = 2)) +
  scale_y_continuous(
    name = "Estimated Power-law Alpha (α)",
    sec.axis = sec_axis(~ (. - 0.5) / 5, name = "Mean Absolute Error to 24-Month Asymptote")
  ) +
  scale_color_manual(values = c("Mean Alpha (α)" = "#08519c", 
                                "Mean Absolute Error (vs 24m)" = "#e6550d")) +
  labs(
    title = "Longitudinal Burn-in: Convergence of Ego Social Signature Parameters",
    subtitle = "Tracking stabilization of power-law slope (α) as observation window expands from 2 to 24 months",
    x = "Cumulative Observation Length (Months)",
    color = "Metric:"
  ) +
  theme_nethealth()

ggsave("output/plots/fig04_parameter_burnin.png", p4, width = 8.5, height = 5.2, dpi = 300)

# ------------------------------------------------------------------------------
# Figure 5: Support Tiers by Signature Rank (Expansion 1)
# ------------------------------------------------------------------------------
cat("Generating Figure 5: Support Dimensions across Signature Rank Tiers...\n")
tier_summary <- expansion_d$tier_summary

tier_long <- tier_summary %>%
  select(rank_tier, `Family Kinship` = pct_family, `Friend Peer` = pct_friend,
         `Emotional Support` = pct_emotional, `Advice Support` = pct_advice,
         `Companionship` = pct_companionship, `Financial Support` = pct_financial) %>%
  pivot_longer(cols = -rank_tier, names_to = "dimension", values_to = "percent") %>%
  mutate(
    dimension_type = fifelse(dimension %in% c("Family Kinship", "Friend Peer"), 
                             "Relational Category", "Support Function")
  )

palette_fig5 <- c(
  "Family Kinship"    = "#1f78b4",  # Deep Blue
  "Friend Peer"       = "#33a02c",  # Green
  "Emotional Support" = "#e31a1c",  # Crimson
  "Advice Support"    = "#ff7f00",  # Amber/Orange
  "Companionship"     = "#6a3d9a",  # Purple
  "Financial Support" = "#b15928"   # Rich Brown
)

p5 <- ggplot(tier_long, aes(x = rank_tier, y = percent, group = dimension, color = dimension)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  facet_wrap(~ dimension_type, scales = "free_y") +
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  scale_color_manual(values = palette_fig5) +
  guides(color = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title = "Functional Grounding of Communication Ranks in Social Support Dimensions",
    subtitle = "Survey-reported ties and support functions across call signature rank tiers (N = 13,174 dyads)",
    x = "Call Signature Rank Tier",
    y = "Prevalence Rate (%)",
    color = "Support / Relation:"
  ) +
  theme_nethealth() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1),
        legend.position = "bottom",
        legend.box = "horizontal")

ggsave("output/plots/fig05_rank_by_support_tiers.png", p5, width = 9.5, height = 5.5, dpi = 300)
ggsave("Plots/fig05_rank_by_support_tiers.png", p5, width = 9.5, height = 5.5, dpi = 300)

# ------------------------------------------------------------------------------
# Figure 6: Alter Turnover vs Signature Divergence (Expansion 2)
# ------------------------------------------------------------------------------
cat("Generating Figure 6: Alter Turnover vs Signature Stability...\n")
sem_turnover <- turnover_d$turnover_semester

p6 <- ggplot(sem_turnover, aes(x = turnover, y = self_jsd)) +
  geom_point(aes(color = top1_retained), alpha = 0.45, size = 1.8) +
  geom_smooth(method = "lm", color = "black", linewidth = 1.1, se = TRUE) +
  scale_color_manual(values = c("TRUE" = "#2171b5", "FALSE" = "#cb181d"),
                     labels = c("TRUE" = "Top-1 Alter Retained", "FALSE" = "Top-1 Alter Replaced")) +
  scale_x_continuous(labels = scales::percent_format()) +
  labs(
    title = "The 'Slot-Filling' Dynamic: Alter Turnover vs. Signature Divergence",
    subtitle = sprintf("Semesters: r = 0.456 (p < 0.0001); despite 80%% average tie turnover, signatures remain stable (mean JSD = 0.061)"),
    x = "Dyadic Alter Turnover Between Semesters (1 - Jaccard)",
    y = "Self-Divergence (JSD between consecutive windows)",
    color = "Core Continuity:"
  ) +
  theme_nethealth()

ggsave("output/plots/fig06_turnover_vs_stability.png", p6, width = 8.5, height = 5.2, dpi = 300)

# ------------------------------------------------------------------------------
# Figure 7: Personality & Signature Steepness (Expansion 3)
# ------------------------------------------------------------------------------
cat("Generating Figure 7: Personality Predictors of Signature Alpha...\n")
ego_covars <- expansion_d$ego_param_covariates %>%
  filter(!is.na(neuroticism), !is.na(mean_alpha))

# Panel A: Regression of Decay Exponent on Negative Emotionality
p7a <- ggplot(ego_covars, aes(x = neuroticism, y = mean_alpha)) +
  geom_point(aes(color = neuroticism), size = 2.4, alpha = 0.65) +
  geom_smooth(method = "lm", color = "#b2182b", fill = "#fddbc7", linewidth = 1.1) +
  scale_color_viridis_c(option = "magma", direction = -1, name = "Negative Emotionality:",
                        guide = guide_colorbar(barwidth = 10, barheight = 0.6)) +
  annotate("label", x = 1.5, y = 1.85, hjust = 0, size = 3.3,
           label = "Linear Slope: \u03b2 = +0.098 (SE = 0.019)\nt = 5.08, p < 0.0001\nR\u00b2 = 0.112",
           fill = "white", color = "grey20") +
  labs(
    title = "(A) Exponent vs. Negative Emotionality",
    x = "Baseline Negative Emotionality Score (Big Five)",
    y = "Mean Power-Law Decay Exponent (\u03b1)"
  ) +
  theme_nethealth()

# Panel B: Signatures by Negative Emotionality Tertile
ego_covars <- ego_covars %>%
  mutate(
    neuro_tertile = ntile(neuroticism, 3),
    neuro_group = factor(neuro_tertile, levels = 1:3,
                         labels = c("Low Neg. Emotionality (T1)", "Moderate (T2)", "High Neg. Emotionality (T3)"))
  )

sem_sigs <- sig_data$semester$sig_dt
sem_merged <- merge(sem_sigs, ego_covars[, c("egoid", "neuro_group")], by = "egoid")

rows <- list()
for (i in 1:nrow(sem_merged)) {
  p <- sem_merged$signature[[i]]
  k <- min(length(p), 10)
  rows[[length(rows) + 1]] <- tibble(
    egoid = sem_merged$egoid[i],
    neuro_group = sem_merged$neuro_group[i],
    rank = 1:k,
    proportion = p[1:k]
  )
}
df_neuro_ranks <- bind_rows(rows) %>%
  group_by(neuro_group, rank) %>%
  summarise(
    mean_prop = mean(proportion),
    se_prop = sd(proportion) / sqrt(n()),
    .groups = "drop"
  )

p7b <- ggplot(df_neuro_ranks, aes(x = rank, y = mean_prop, color = neuro_group, fill = neuro_group)) +
  geom_ribbon(aes(ymin = mean_prop - 1.96 * se_prop, ymax = mean_prop + 1.96 * se_prop),
              alpha = 0.15, color = NA) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.2) +
  scale_x_continuous(breaks = 1:10) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_color_manual(values = c("Low Neg. Emotionality (T1)" = "#2166ac",
                                "Moderate (T2)" = "#67a9cf",
                                "High Neg. Emotionality (T3)" = "#b2182b"),
                     name = "Negative Emotionality Group:") +
  scale_fill_manual(values = c("Low Neg. Emotionality (T1)" = "#2166ac",
                               "Moderate (T2)" = "#67a9cf",
                               "High Neg. Emotionality (T3)" = "#b2182b"),
                    name = "Negative Emotionality Group:") +
  guides(color = guide_legend(nrow = 2, byrow = TRUE), 
         fill  = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title = "(B) Mean Signatures by Negative Emotionality Tertile",
    x = "Alter Rank (1\u201310)",
    y = "Proportion of Outgoing Calls"
  ) +
  theme_nethealth() +
  theme(legend.position = "bottom",
        legend.margin = margin(t = 4, b = 2))

p7_combined <- (p7a | p7b) +
  plot_annotation(
    title = "Negative Emotionality as a Driver of Egocentric Relational Concentration",
    subtitle = "Higher Negative Emotionality predicts significantly steeper power-law decay (\u03b2 = 0.098, p < 0.0001) and greater allocation to primary alters",
    theme = theme(
      plot.title = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(color = "grey30", size = 11, margin = margin(b = 6))
    )
  )

ggsave("output/plots/fig07_personality_signature_effects.png", p7_combined, width = 9.5, height = 5.2, dpi = 300)
ggsave("Plots/fig07_personality_signature_effects.png", p7_combined, width = 9.5, height = 5.2, dpi = 300)

cat("\n>>> Step 7 completed successfully! All 7 figures saved to output/plots/\n")
