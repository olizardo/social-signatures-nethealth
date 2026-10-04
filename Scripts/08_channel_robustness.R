#!/usr/bin/env Rscript
# ==============================================================================
# Script 08: Per-Channel Robustness Comparison (Calls-Only vs. Texts-Only vs. Pooled)
# Project: Social Signatures in NetHealth
# Description: Addresses the equal-channel-weighting limitation of the pooled
#              multichannel analysis directly, by recomputing the headline
#              results (eligible cohort size, persistence, power-law scaling,
#              Rank-1 relational composition, and slot-filling top-1 alter
#              retention) separately for the voice-call channel and for the
#              combined text-based channels (SMS + MMS + WhatsApp), using the
#              same semester-window scheme, eligibility criteria, and quality
#              filters as the pooled analysis (Script 01). Produces a single
#              Supplementary Table comparing all three channel definitions.
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
})

cat(">>> Step 8: Loading cached outgoing/iPhone event extract...\n")
interim_file <- "data/raw/CommEvents_outgoing_iphone_2015_2017.csv"
stopifnot(file.exists(interim_file))

events_raw <- fread(interim_file,
                     select = c("egoid", "alterid", "date", "eventtype", "eventtypedetail",
                                "duration", "length", "bytes"),
                     colClasses = list(character = c("egoid", "alterid")))

# NetHealth-recommended data-quality exclusions (identical to Script 01)
drop_mask <- (events_raw$eventtype == "Call" & !is.na(events_raw$duration) & events_raw$duration == 0) |
  (events_raw$eventtype %in% c("SMS", "WhatsApp") & !is.na(events_raw$length) & events_raw$length == 0) |
  (events_raw$eventtype %in% c("MMS", "WhatsApp") & !is.na(events_raw$bytes) & events_raw$bytes == 0) |
  (events_raw$eventtype == "WhatsApp" & events_raw$eventtypedetail == "GC")
events_raw <- events_raw[!drop_mask]
events_raw <- events_raw[!is.na(egoid) & !is.na(alterid) & egoid != alterid & alterid != ""]
events_raw[, date := as.IDate(date)]

cal_start <- as.IDate("2015-07-01")
cal_end   <- as.IDate("2017-06-30")
events_cal <- events_raw[date >= cal_start & date <= cal_end]
events_cal[, semester := fcase(
  date <= as.IDate("2015-12-31"), "2015-Fall",
  date <= as.IDate("2016-06-30"), "2016-Spring",
  date <= as.IDate("2016-12-31"), "2016-Fall",
  default = "2017-Spring"
)]

cat(sprintf("Pooled semester-window candidate pool: %s events across %d egos.\n",
            format(nrow(events_cal), big.mark = ","), uniqueN(events_cal$egoid)))

# ==============================================================================
# Shared helper functions (identical definitions to Scripts 01-03)
# ==============================================================================
shannon_entropy <- function(p) {
  p_pos <- p[p > 0]
  if (length(p_pos) == 0) return(0)
  -sum(p_pos * log2(p_pos))
}
pad_distributions <- function(p, q) {
  max_len <- max(length(p), length(q))
  list(p = c(p, rep(0, max_len - length(p))), q = c(q, rep(0, max_len - length(q))))
}
jsd_pairwise <- function(p, q) {
  padded <- pad_distributions(p, q)
  m <- 0.5 * (padded$p + padded$q)
  max(0, shannon_entropy(m) - 0.5 * (shannon_entropy(p) + shannon_entropy(q)))
}
compute_signature <- function(w) {
  w_sorted <- sort(w, decreasing = TRUE)
  tot <- sum(w_sorted)
  if (tot == 0) rep(0, length(w_sorted)) else w_sorted / tot
}
fit_power_law <- function(sig) {
  k <- length(sig)
  if (k < 3) return(NULL)
  ranks <- 1:k
  df_fit <- data.frame(log_rank = log(ranks), log_prop = log(sig))
  pl_lm <- tryCatch(lm(log_prop ~ log_rank, data = df_fit), error = function(e) NULL)
  exp_lm <- tryCatch(lm(log_prop ~ ranks, data = df_fit), error = function(e) NULL)
  if (is.null(pl_lm) || is.null(exp_lm)) return(NULL)
  tibble(alpha = -coef(pl_lm)[2], pl_r2 = summary(pl_lm)$r.squared,
         exp_r2 = summary(exp_lm)$r.squared,
         pl_aic = AIC(pl_lm), exp_aic = AIC(exp_lm))
}

# ==============================================================================
# Core per-channel analysis function
# ==============================================================================
analyze_channel <- function(dt_channel, label) {
  cat(sprintf("\n--- Channel: %s ---\n", label))

  # Eligibility: >= 2 alters in every semester window, avg > 10 events/window
  agg <- dt_channel[, .(events = .N), by = .(egoid, alterid, semester)]
  num_windows <- uniqueN(dt_channel$semester)
  ego_win <- agg[, .(n_alters = uniqueN(alterid), n_events = sum(events)), by = .(egoid, semester)]
  ego_stats <- ego_win[, .(active_windows = uniqueN(semester), min_alters = min(n_alters),
                            avg_events = sum(n_events) / num_windows), by = egoid]
  eligible <- ego_stats[active_windows == num_windows & min_alters >= 2 & avg_events > 10, egoid]
  agg_el <- agg[egoid %in% eligible]
  n_eligible <- length(eligible)
  cat(sprintf("Eligible egos (semester scheme): %d\n", n_eligible))

  if (n_eligible < 10) {
    return(tibble(channel = label, n_eligible_egos = n_eligible, mean_self_jsd = NA, mean_ref_jsd = NA,
                  wilcoxon_p = NA, mean_alpha = NA, pct_pl_preferred = NA,
                  pct_family_rank1 = NA, pct_friend_rank1 = NA, pct_top1_retained = NA,
                  n_rank1_dyads = NA))
  }

  # Build per-ego-window signatures
  sig_dt <- agg_el[, .(
    signature = list(compute_signature(events)),
    alters = list(alterid[order(-events)]),
    deg = uniqueN(alterid)
  ), by = .(egoid, semester)]

  windows <- sort(unique(sig_dt$semester))
  egos <- sort(unique(sig_dt$egoid))

  # Self-divergence (consecutive windows)
  self_list <- list()
  for (eg in egos) {
    sub <- sig_dt[egoid == eg][order(semester)]
    if (nrow(sub) < 2) next
    for (t in 1:(nrow(sub) - 1)) {
      self_list[[length(self_list) + 1]] <- tibble(egoid = eg,
        jsd = jsd_pairwise(sub$signature[[t]], sub$signature[[t + 1]]))
    }
  }
  self_df <- bind_rows(self_list) %>% group_by(egoid) %>% summarise(mean_self = mean(jsd), .groups = "drop")

  # Reference divergence (by ego, within window, vs all other egos)
  ref_list <- list()
  for (w in windows) {
    w_sub <- sig_dt[semester == w]
    k <- nrow(w_sub)
    if (k < 2) next
    for (a in 1:k) {
      others <- setdiff(1:k, a)
      divs <- sapply(others, function(b) jsd_pairwise(w_sub$signature[[a]], w_sub$signature[[b]]))
      ref_list[[length(ref_list) + 1]] <- tibble(egoid = w_sub$egoid[a], jsd = mean(divs))
    }
  }
  ref_df <- bind_rows(ref_list) %>% group_by(egoid) %>% summarise(mean_ref = mean(jsd), .groups = "drop")

  comp <- inner_join(self_df, ref_df, by = "egoid")
  wtest <- if (nrow(comp) >= 5) wilcox.test(comp$mean_self, comp$mean_ref, paired = TRUE, alternative = "less") else list(p.value = NA)

  # Power-law fits
  pl_list <- list()
  for (i in 1:nrow(sig_dt)) {
    fit <- fit_power_law(sig_dt$signature[[i]])
    if (!is.null(fit)) pl_list[[length(pl_list) + 1]] <- fit
  }
  pl_df <- bind_rows(pl_list)

  # Rank-1 relational composition (merge with alter survey attributes)
  alter_attr <- readRDS("data/processed/alter_survey_attributes.rds")
  alter_attr$egoid <- as.character(alter_attr$egoid)
  alter_attr$alterid <- as.character(alter_attr$alterid)
  rank1_rows <- sig_dt[deg >= 1, .(egoid, semester, rank1_alter = sapply(alters, function(a) a[1]))]
  rank1_merged <- merge(rank1_rows, alter_attr, by.x = c("egoid", "rank1_alter"),
                         by.y = c("egoid", "alterid"))

  # Slot-filling: top-1 alter retention across consecutive semesters
  top1_list <- list()
  for (eg in egos) {
    sub <- sig_dt[egoid == eg][order(semester)]
    if (nrow(sub) < 2) next
    for (t in 1:(nrow(sub) - 1)) {
      a1 <- sub$alters[[t]][1]; a2 <- sub$alters[[t + 1]][1]
      top1_list[[length(top1_list) + 1]] <- tibble(retained = !is.na(a1) && !is.na(a2) && a1 == a2)
    }
  }
  top1_df <- bind_rows(top1_list)

  tibble(
    channel = label,
    n_eligible_egos = n_eligible,
    mean_self_jsd = mean(comp$mean_self),
    mean_ref_jsd = mean(comp$mean_ref),
    wilcoxon_p = wtest$p.value,
    mean_alpha = mean(pl_df$alpha, na.rm = TRUE),
    pct_pl_preferred = mean(pl_df$pl_aic < pl_df$exp_aic, na.rm = TRUE) * 100,
    pct_family_rank1 = mean(rank1_merged$is_family, na.rm = TRUE) * 100,
    pct_friend_rank1 = mean(rank1_merged$is_friend, na.rm = TRUE) * 100,
    pct_top1_retained = mean(top1_df$retained) * 100,
    n_rank1_dyads = nrow(rank1_merged)
  )
}

calls_only <- events_cal[eventtype == "Call"]
texts_only <- events_cal[eventtype %in% c("SMS", "MMS", "WhatsApp")]

res_calls <- analyze_channel(calls_only, "Calls-Only")
res_texts <- analyze_channel(texts_only, "Texts-Only (SMS+MMS+WhatsApp)")

# Pull the already-computed pooled (calls+texts) results for direct comparison
sig_data   <- readRDS("data/processed/social_signatures_and_jsd.rds")
param_data <- readRDS("data/processed/parametric_models.rds")
expansion_d <- readRDS("data/processed/expansion_models.rds")
turnover_d <- readRDS("data/processed/turnover_and_divergence.rds")

pooled_comp <- sig_data$semester$ego_comp
pooled_wtest <- sig_data$semester$wilcox_test
pooled_models <- param_data$semester_models
pooled_rank1 <- expansion_d$dyad_merged %>% filter(rank == 1)
pooled_turnover <- turnover_d$turnover_semester

res_pooled <- tibble(
  channel = "Pooled (Calls + Texts)",
  n_eligible_egos = nrow(pooled_comp),
  mean_self_jsd = mean(pooled_comp$mean_self_jsd),
  mean_ref_jsd = mean(pooled_comp$mean_ref_jsd),
  wilcoxon_p = pooled_wtest$p.value,
  mean_alpha = mean(pooled_models$pl_alpha, na.rm = TRUE),
  pct_pl_preferred = mean(pooled_models$pl_preferred, na.rm = TRUE) * 100,
  pct_family_rank1 = mean(pooled_rank1$is_family, na.rm = TRUE) * 100,
  pct_friend_rank1 = mean(pooled_rank1$is_friend, na.rm = TRUE) * 100,
  pct_top1_retained = mean(pooled_turnover$top1_retained) * 100,
  n_rank1_dyads = nrow(pooled_rank1)
)

robustness_table <- bind_rows(res_calls, res_texts, res_pooled)
print(robustness_table, width = Inf)

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write_csv(robustness_table, "output/tables/table_S1_channel_robustness.csv")
saveRDS(robustness_table, "data/processed/channel_robustness.rds")
cat("\n>>> Step 8 completed successfully! Saved to output/tables/table_S1_channel_robustness.csv\n")
