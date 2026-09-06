#!/usr/bin/env Rscript
# ==============================================================================
# Script 05: Survey Linkage & Psychometrics Extraction
# Project: Social Signatures in NetHealth
# Description: Implements survey linkage to extract:
#              - Alter attributes: Support dimensions (emotional, advice, companionship,
#                financial), relationship categories (family, friend), closeness, trust.
#              - Ego psychometrics: Big Five personality traits, UCLA loneliness scale,
#                CES-D depression scores, and longitudinal trajectories.
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
})

cat(">>> Step 5: Loading survey datasets...\n")
stopifnot(file.exists("data/raw/network_survey.csv"))
stopifnot(file.exists("data/raw/basic_survey.csv"))

# ==============================================================================
# 1. Extract Alter-Level Attributes from Network Survey
# ==============================================================================
cat("Extracting alter-level attributes from network_survey.csv...\n")
net_df <- fread("data/raw/network_survey.csv")
net_df[, egoid := as.character(egoid)]
net_df[, alterid := as.character(alterid)]
net_df[, wave_num := as.integer(gsub("\\D", "", wave))]

# Ensure logical support indicators
to_lgl <- function(x) {
  if (is.logical(x)) return(x)
  if (is.numeric(x)) return(x == 1)
  if (is.character(x)) return(tolower(x) %in% c("1", "true", "yes"))
  rep(FALSE, length(x))
}

net_df[, is_fam := to_lgl(family) | grepl("family|parent|sibling|relative|child", tolower(reltypecat))]
net_df[, is_frn := to_lgl(friend) | grepl("friend|roommate|peer", tolower(reltypecat))]
net_df[, sup_comf := to_lgl(suppcomf)]
net_df[, sup_adv  := to_lgl(suppadv)]
net_df[, sup_hang := to_lgl(supphang)]
net_df[, sup_fin  := to_lgl(suppfin)]
net_df[, closeness_num := as.numeric(close)]

# Aggregate per ego-alter dyad across all waves
alter_attr <- net_df[, .(
  waves_nominated = uniqueN(wave_num),
  is_family = any(is_fam, na.rm = TRUE),
  is_friend = any(is_frn, na.rm = TRUE),
  provides_emotional = any(sup_comf, na.rm = TRUE),
  provides_advice = any(sup_adv, na.rm = TRUE),
  provides_companionship = any(sup_hang, na.rm = TRUE),
  provides_financial = any(sup_fin, na.rm = TRUE),
  mean_closeness = mean(closeness_num, na.rm = TRUE),
  max_closeness = suppressWarnings(max(closeness_num, na.rm = TRUE))
), by = .(egoid, alterid)]

alter_attr[is.infinite(max_closeness), max_closeness := NA_real_]

cat(sprintf("Extracted %s unique ego-alter dyad profiles.\n",
            format(nrow(alter_attr), big.mark = ",")))
saveRDS(alter_attr, "data/processed/alter_survey_attributes.rds")

# ==============================================================================
# 2. Extract Longitudinal Ego Psychometrics from Basic Survey
# ==============================================================================
cat("\nExtracting longitudinal psychometrics from basic_survey.csv...\n")
bs_df <- fread("data/raw/basic_survey.csv")
bs_df[, egoid := as.character(egoid)]

# Conversion maps
cesd_map <- c(
  "Rarely or none of the time (less than 1 day)" = 0,
  "Some or a little of the time (1-2 days)" = 1,
  "Occasionally or a moderate amount of time (3-4 days)" = 2,
  "All of the time (5-7 days)" = 3
)
cesd_rev_map <- c(
  "Rarely or none of the time (less than 1 day)" = 3,
  "Some or a little of the time (1-2 days)" = 2,
  "Occasionally or a moderate amount of time (3-4 days)" = 1,
  "All of the time (5-7 days)" = 0
)

lonely_map <- c(
  "Strongly Disagree" = 1,
  "Disagree" = 2,
  "Somewhat Disagree" = 3,
  "Neither Agree nor Disagree" = 4,
  "Somewhat Agree" = 5,
  "Agree" = 6,
  "Strongly Agree" = 7
)

# Waves to extract: 1, 2, 4, 6, 8
waves_to_extract <- c(1, 2, 4, 6, 8)
ego_psych_list <- list()

for (w in waves_to_extract) {
  b5_extra <- sprintf("Extraversion_%d", w)
  b5_agree <- sprintf("Agreeableness_%d", w)
  b5_consc <- sprintf("Conscientiousness_%d", w)
  b5_neuro <- sprintf("Neuroticism_%d", w)
  b5_open  <- sprintf("Openness_%d", w)
  
  # CES-D items
  cesd_items <- sprintf("CESD%d_%d", 1:20, w)
  cesd_avail <- intersect(cesd_items, names(bs_df))
  
  # Lonely items
  lonely_items <- sprintf("lonely_%d_%d", 1:20, w)
  lonely_avail <- intersect(lonely_items, names(bs_df))
  
  # Check if wave has columns
  has_b5 <- b5_extra %in% names(bs_df)
  if (!has_b5 && length(cesd_avail) == 0 && length(lonely_avail) == 0) next
  
  # Score CES-D
  cesd_score <- rep(NA_real_, nrow(bs_df))
  if (length(cesd_avail) >= 10) {
    cesd_mat <- matrix(NA_real_, nrow = nrow(bs_df), ncol = length(cesd_avail))
    for (j in seq_along(cesd_avail)) {
      col_nm <- cesd_avail[j]
      item_num <- as.integer(gsub("CESD|_.*", "", col_nm))
      vals <- bs_df[[col_nm]]
      if (item_num %in% c(4, 8, 12, 16)) {
        cesd_mat[, j] <- cesd_rev_map[vals]
      } else {
        cesd_mat[, j] <- cesd_map[vals]
      }
    }
    # Require at least 80% non-missing items to compute sum
    valid_count <- rowSums(!is.na(cesd_mat))
    cesd_score <- ifelse(valid_count >= (0.8 * length(cesd_avail)),
                         rowSums(cesd_mat, na.rm = TRUE) * (length(cesd_avail) / valid_count),
                         NA_real_)
  }
  
  # Score Loneliness
  lonely_score <- rep(NA_real_, nrow(bs_df))
  if (length(lonely_avail) >= 5) {
    lonely_mat <- matrix(NA_real_, nrow = nrow(bs_df), ncol = length(lonely_avail))
    for (j in seq_along(lonely_avail)) {
      lonely_mat[, j] <- lonely_map[bs_df[[lonely_avail[j]]]]
    }
    valid_count <- rowSums(!is.na(lonely_mat))
    lonely_score <- ifelse(valid_count >= (0.7 * length(lonely_avail)),
                           rowMeans(lonely_mat, na.rm = TRUE),
                           NA_real_)
  }
  
  w_df <- tibble(
    egoid = bs_df$egoid,
    wave = w,
    extraversion = if (has_b5) as.numeric(bs_df[[b5_extra]]) else NA_real_,
    agreeableness = if (has_b5) as.numeric(bs_df[[b5_agree]]) else NA_real_,
    conscientiousness = if (has_b5) as.numeric(bs_df[[b5_consc]]) else NA_real_,
    neuroticism = if (has_b5) as.numeric(bs_df[[b5_neuro]]) else NA_real_,
    openness = if (has_b5) as.numeric(bs_df[[b5_open]]) else NA_real_,
    cesd_depression = cesd_score,
    loneliness = lonely_score
  )
  ego_psych_list[[length(ego_psych_list) + 1]] <- w_df
}

ego_psych_long <- bind_rows(ego_psych_list)
cat(sprintf("Extracted %d ego-wave psychometric records across %d egos.\n",
            nrow(ego_psych_long), uniqueN(ego_psych_long$egoid)))

cat("Wave 1 Psychometric Summary:\n")
w1_summary <- ego_psych_long %>%
  filter(wave == 1) %>%
  select(extraversion, neuroticism, agreeableness, cesd_depression, loneliness) %>%
  summary()
print(w1_summary)

saveRDS(ego_psych_long, "data/processed/ego_psychometrics_longitudinal.rds")

cat("\n>>> Step 5 completed successfully! Saved to data/processed/ego_psychometrics_longitudinal.rds\n")
