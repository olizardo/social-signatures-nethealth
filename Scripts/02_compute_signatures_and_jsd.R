#!/usr/bin/env Rscript
# ==============================================================================
# Script 02: Social Signature Computation and Jensen-Shannon Divergence
# Project: Social Signatures in NetHealth
# Description: Implements Chandler (2019) Slides 2, 3, 12, 13, 15:
#              - Ranked alter proportion vectors (social signatures)
#              - Pairwise JSD with zero-padding and generalized JSD (Lin 1991)
#              - Self-divergence vs Reference-divergence (all pairs & by ego)
#              - Statistical tests of persistence across window definitions
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
})

cat(">>> Step 2: Loading binned window data...\n")
stopifnot(file.exists("data/processed/call_windows.rds"))
windows_data <- readRDS("data/processed/call_windows.rds")

# ==============================================================================
# Information-Theoretic Functions (Lin 1991; Saramäki et al. 2014)
# ==============================================================================
shannon_entropy <- function(p) {
  p_pos <- p[p > 0]
  if (length(p_pos) == 0) return(0)
  -sum(p_pos * log2(p_pos))
}

pad_distributions <- function(p, q) {
  len_p <- length(p)
  len_q <- length(q)
  max_len <- max(len_p, len_q)
  if (len_p < max_len) p <- c(p, rep(0, max_len - len_p))
  if (len_q < max_len) q <- c(q, rep(0, max_len - len_q))
  list(p = p, q = q)
}

jsd_pairwise <- function(p, q, h_p = NULL, h_q = NULL) {
  if (is.null(h_p)) h_p <- shannon_entropy(p)
  if (is.null(h_q)) h_q <- shannon_entropy(q)
  padded <- pad_distributions(p, q)
  m <- 0.5 * (padded$p + padded$q)
  h_m <- shannon_entropy(m)
  max(0, h_m - 0.5 * (h_p + h_q))
}

jsd_generalized <- function(dist_list) {
  n <- length(dist_list)
  if (n <= 1) return(0)
  max_len <- max(sapply(dist_list, length))
  
  mat <- sapply(dist_list, function(v) {
    if (length(v) < max_len) c(v, rep(0, max_len - length(v))) else v
  })
  
  m <- rowMeans(mat)
  h_m <- shannon_entropy(m)
  h_indiv <- mean(apply(mat, 2, shannon_entropy))
  max(0, h_m - h_indiv)
}

# ==============================================================================
# Social Signature Function
# ==============================================================================
compute_signature <- function(alter_weights) {
  w_sorted <- sort(alter_weights, decreasing = TRUE)
  tot <- sum(w_sorted)
  if (tot == 0) rep(0, length(w_sorted)) else w_sorted / tot
}

# Process each scheme with fast vectorized matrix operations
process_signatures_for_scheme <- function(dt, scheme_name, target_egos = NULL) {
  cat(sprintf("\nProcessing scheme: %s ...\n", scheme_name))
  dt_work <- copy(dt)
  if (!is.null(target_egos)) {
    dt_work <- dt_work[egoid %in% target_egos]
  }
  
  # Compute signature and precalculate entropy for each ego-window
  sig_dt <- dt_work[, .(
    signature = list(compute_signature(calls)),
    alters = list(alterid[order(-calls)]),
    weights = list(sort(calls, decreasing = TRUE)),
    total_calls = sum(calls),
    deg = uniqueN(alterid)
  ), by = .(egoid, window)]
  
  # Precompute entropy
  sig_dt[, entropy := sapply(signature, shannon_entropy)]
  
  # Order windows chronologically
  windows <- sort(unique(sig_dt$window))
  num_w <- length(windows)
  egos <- sort(unique(sig_dt$egoid))
  n_egos <- length(egos)
  
  cat(sprintf("  - Scheme %s: %d egos across %d windows.\n", scheme_name, n_egos, num_w))
  
  # 1. Self-Divergence: consecutive window pairs
  self_div_list <- list()
  for (i in egos) {
    ego_sub <- sig_dt[egoid == i]
    setkey(ego_sub, window)
    if (nrow(ego_sub) < 2) next
    
    divs <- numeric(nrow(ego_sub) - 1)
    for (t in 1:(nrow(ego_sub) - 1)) {
      divs[t] <- jsd_pairwise(ego_sub$signature[[t]], 
                              ego_sub$signature[[t + 1]],
                              ego_sub$entropy[t], 
                              ego_sub$entropy[t + 1])
    }
    self_div_list[[i]] <- tibble(
      egoid = i,
      window_pair = paste(ego_sub$window[1:(nrow(ego_sub)-1)], 
                          ego_sub$window[2:nrow(ego_sub)], sep = " -> "),
      self_jsd = divs
    )
  }
  self_div_df <- bind_rows(self_div_list)
  
  # Ego-mean self divergence
  ego_self_mean <- self_div_df %>%
    group_by(egoid) %>%
    summarise(mean_self_jsd = mean(self_jsd, na.rm = TRUE), .groups = "drop")
  
  # 2. Reference Divergence: Vectorized across windows
  ref_ego_list <- list()
  pair_sum_mat <- matrix(0, nrow = n_egos, ncol = n_egos, dimnames = list(egos, egos))
  pair_count_mat <- matrix(0, nrow = n_egos, ncol = n_egos, dimnames = list(egos, egos))
  
  for (w in windows) {
    w_sub <- sig_dt[window == w]
    setkey(w_sub, egoid)
    w_egos <- w_sub$egoid
    k <- length(w_egos)
    if (k < 2) next
    
    # Pad all signatures in window w to uniform length
    max_k_len <- max(sapply(w_sub$signature, length))
    sig_mat <- sapply(w_sub$signature, function(v) {
      if (length(v) < max_k_len) c(v, rep(0, max_k_len - length(v))) else v
    }) # matrix of dimension (max_k_len, k)
    h_vec <- w_sub$entropy
    
    dist_mat <- matrix(0, nrow = k, ncol = k, dimnames = list(w_egos, w_egos))
    
    for (a in 1:(k - 1)) {
      p_a <- sig_mat[, a]
      h_a <- h_vec[a]
      
      # Vectorized over all b > a
      m_block <- 0.5 * (sig_mat[, (a + 1):k, drop = FALSE] + p_a)
      # Entropy of each column in m_block
      # compute -sum(x * log2(x)) vectorized
      pos_mask <- m_block > 0
      log_m <- matrix(0, nrow = nrow(m_block), ncol = ncol(m_block))
      log_m[pos_mask] <- m_block[pos_mask] * log2(m_block[pos_mask])
      h_m_block <- -colSums(log_m)
      
      jsd_block <- pmax(0, h_m_block - 0.5 * (h_a + h_vec[(a + 1):k]))
      dist_mat[a, (a + 1):k] <- jsd_block
      dist_mat[(a + 1):k, a] <- jsd_block
    }
    
    # By ego: average divergence within window w
    ego_means_w <- rowSums(dist_mat) / (k - 1)
    ref_ego_list[[w]] <- tibble(
      window = w,
      egoid = names(ego_means_w),
      ref_jsd = ego_means_w
    )
    
    # Accumulate into pair matrices
    pair_sum_mat[w_egos, w_egos] <- pair_sum_mat[w_egos, w_egos] + dist_mat
    pair_count_mat[w_egos, w_egos] <- pair_count_mat[w_egos, w_egos] + 1
  }
  
  ref_ego_df <- bind_rows(ref_ego_list)
  
  # Overall ego-mean reference divergence (n values)
  ego_ref_mean <- ref_ego_df %>%
    group_by(egoid) %>%
    summarise(mean_ref_jsd = mean(ref_jsd, na.rm = TRUE), .groups = "drop")
  
  # All-pairs reference divergence averaged over windows: Binomial[n, 2] values
  mean_pair_mat <- pair_sum_mat / pmax(1, pair_count_mat)
  pair_vals <- mean_pair_mat[upper.tri(mean_pair_mat)]
  
  # Merge ego self and reference means for statistical testing
  ego_comp <- inner_join(ego_self_mean, ego_ref_mean, by = "egoid")
  
  # Hypothesis test: Wilcoxon signed-rank test (Self < Reference)
  test_res <- wilcox.test(ego_comp$mean_self_jsd, ego_comp$mean_ref_jsd, 
                          paired = TRUE, alternative = "less")
  
  cat(sprintf("  Results for %s:\n", scheme_name))
  cat(sprintf("    Mean Self-Divergence:      %.4f (SD: %.4f)\n", 
              mean(ego_comp$mean_self_jsd), sd(ego_comp$mean_self_jsd)))
  cat(sprintf("    Mean Reference-Divergence: %.4f (SD: %.4f)\n", 
              mean(ego_comp$mean_ref_jsd), sd(ego_comp$mean_ref_jsd)))
  cat(sprintf("    Wilcoxon Signed-Rank Test: V = %.1f, p-value = %g (H1: Self < Ref)\n", 
              test_res$statistic, test_res$p.value))
  
  list(
    scheme = scheme_name,
    sig_dt = sig_dt,
    self_div_df = self_div_df,
    ref_ego_df = ref_ego_df,
    pair_divergences = pair_vals,
    ego_comp = ego_comp,
    wilcox_test = test_res
  )
}

# Run for all schemes
results_ay         <- process_signatures_for_scheme(windows_data$academic_year, "Academic Years")
results_semester   <- process_signatures_for_scheme(windows_data$semester, "Semesters")
results_quarter    <- process_signatures_for_scheme(windows_data$quarter, "Quarters")
results_month      <- process_signatures_for_scheme(windows_data$month, "Months")

# Common Calendar Cohort across all window widths (Slide 13)
common_egos        <- windows_data$common_calendar_egos
results_common_sem <- process_signatures_for_scheme(windows_data$semester, "Common Cohort (Semesters)", common_egos)
results_common_mo  <- process_signatures_for_scheme(windows_data$month, "Common Cohort (Months)", common_egos)

# Week schemes (Rolling 3-week & Discrete 2-week)
results_roll3      <- process_signatures_for_scheme(windows_data$rolling_3week, "3-Week Rolling")
results_week2      <- process_signatures_for_scheme(windows_data$discrete_2week, "2-Week Discrete")

# Compile Table 02: Stability summary and hypothesis tests
table02 <- tibble(
  Scheme = c("Academic Years", "Semesters", "Quarters", "Months", 
             "Common Cohort (Semesters)", "Common Cohort (Months)", 
             "3-Week Rolling", "2-Week Discrete"),
  N_Egos = c(nrow(results_ay$ego_comp), nrow(results_semester$ego_comp), 
             nrow(results_quarter$ego_comp), nrow(results_month$ego_comp),
             nrow(results_common_sem$ego_comp), nrow(results_common_mo$ego_comp),
             nrow(results_roll3$ego_comp), nrow(results_week2$ego_comp)),
  Mean_Self_JSD = c(mean(results_ay$ego_comp$mean_self_jsd), mean(results_semester$ego_comp$mean_self_jsd),
                    mean(results_quarter$ego_comp$mean_self_jsd), mean(results_month$ego_comp$mean_self_jsd),
                    mean(results_common_sem$ego_comp$mean_self_jsd), mean(results_common_mo$ego_comp$mean_self_jsd),
                    mean(results_roll3$ego_comp$mean_self_jsd), mean(results_week2$ego_comp$mean_self_jsd)),
  SD_Self_JSD   = c(sd(results_ay$ego_comp$mean_self_jsd), sd(results_semester$ego_comp$mean_self_jsd),
                    sd(results_quarter$ego_comp$mean_self_jsd), sd(results_month$ego_comp$mean_self_jsd),
                    sd(results_common_sem$ego_comp$mean_self_jsd), sd(results_common_mo$ego_comp$mean_self_jsd),
                    sd(results_roll3$ego_comp$mean_self_jsd), sd(results_week2$ego_comp$mean_self_jsd)),
  Mean_Ref_JSD  = c(mean(results_ay$ego_comp$mean_ref_jsd), mean(results_semester$ego_comp$mean_ref_jsd),
                    mean(results_quarter$ego_comp$mean_ref_jsd), mean(results_month$ego_comp$mean_ref_jsd),
                    mean(results_common_sem$ego_comp$mean_ref_jsd), mean(results_common_mo$ego_comp$mean_ref_jsd),
                    mean(results_roll3$ego_comp$mean_ref_jsd), mean(results_week2$ego_comp$mean_ref_jsd)),
  SD_Ref_JSD    = c(sd(results_ay$ego_comp$mean_ref_jsd), sd(results_semester$ego_comp$mean_ref_jsd),
                    sd(results_quarter$ego_comp$mean_ref_jsd), sd(results_month$ego_comp$mean_ref_jsd),
                    sd(results_common_sem$ego_comp$mean_ref_jsd), sd(results_common_mo$ego_comp$mean_ref_jsd),
                    sd(results_roll3$ego_comp$mean_ref_jsd), sd(results_week2$ego_comp$mean_ref_jsd)),
  Difference    = Mean_Self_JSD - Mean_Ref_JSD,
  Wilcoxon_p    = c(results_ay$wilcox_test$p.value, results_semester$wilcox_test$p.value,
                    results_quarter$wilcox_test$p.value, results_month$wilcox_test$p.value,
                    results_common_sem$wilcox_test$p.value, results_common_mo$wilcox_test$p.value,
                    results_roll3$wilcox_test$p.value, results_week2$wilcox_test$p.value)
)

write_csv(table02, "output/tables/table02_stability_tests.csv")
cat("\n>>> Saved stability test results to output/tables/table02_stability_tests.csv\n")

# Save social signatures and divergence objects
saveRDS(list(
  academic_year = results_ay,
  semester = results_semester,
  quarter = results_quarter,
  month = results_month,
  common_semester = results_common_sem,
  common_month = results_common_mo,
  rolling_3week = results_roll3,
  discrete_2week = results_week2
), "data/processed/social_signatures_and_jsd.rds")

cat(">>> Step 2 completed successfully! Processed results saved to data/processed/social_signatures_and_jsd.rds\n")
