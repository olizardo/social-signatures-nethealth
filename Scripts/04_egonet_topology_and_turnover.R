#!/usr/bin/env Rscript
# ==============================================================================
# Script 04: Egonet Topology and Alter Turnover Analysis
# Project: Social Signatures in NetHealth
# Description: Implements Chandler (2019) Slide 26:
#              - Egonet topology: Density, Clustering/Transitivity, Modularity, Constraint
#              - Alter turnover: Dyadic Jaccard similarity and turnover across windows
#              - Activity dynamics: Delta activity, calls, and turnover interaction
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(igraph)
  library(data.table)
})

cat(">>> Step 4: Loading edge lists, survey data, and signatures...\n")
stopifnot(file.exists("data/raw/alter_alter_edges.csv"))
stopifnot(file.exists("data/raw/network_survey.csv"))
stopifnot(file.exists("data/processed/social_signatures_and_jsd.rds"))

edges_dt <- fread("data/raw/alter_alter_edges.csv")
edges_dt[, egoid := as.character(egoid)]
edges_dt[, vertex1 := as.character(vertex1)]
edges_dt[, vertex2 := as.character(vertex2)]
edges_dt[, wave := as.integer(wave)]

surveys_dt <- fread("data/raw/network_survey.csv", select = c("egoid", "alterid", "wave"))
surveys_dt[, egoid := as.character(egoid)]
surveys_dt[, alterid := as.character(alterid)]
surveys_dt[, wave_num := as.integer(gsub("\\D", "", wave))]

cat(sprintf("Loaded %s alter-alter ties and %s survey nominations across 8 waves.\n",
            format(nrow(edges_dt), big.mark = ","), format(nrow(surveys_dt), big.mark = ",")))

# ==============================================================================
# 1. Compute Egonet Topology per Ego and Wave
# ==============================================================================
cat("Computing egocentric network topology metrics...\n")
ego_waves <- unique(surveys_dt[, .(egoid, wave_num)])

compute_ego_metrics <- function(ego, w) {
  # Alter set nominated by ego
  ego_alters <- unique(surveys_dt[egoid == ego & wave_num == w, alterid])
  ego_alters <- ego_alters[ego_alters != ego & !is.na(ego_alters) & ego_alters != ""]
  n_alters <- length(ego_alters)
  
  if (n_alters < 2) {
    return(tibble(
      egoid = ego,
      wave = w,
      deg = n_alters,
      density = 0,
      clustering = 0,
      modularity = 0,
      constraint = 1
    ))
  }
  
  # Alter-alter edges within this ego's network at wave w
  sub_edges <- edges_dt[egoid == ego & wave == w]
  
  # Filter to edges where both vertices are among ego alters
  valid_edges <- sub_edges[(vertex1 %in% ego_alters) & (vertex2 %in% ego_alters) & (vertex1 != vertex2)]
  
  if (nrow(valid_edges) == 0) {
    return(tibble(
      egoid = ego,
      wave = w,
      deg = n_alters,
      density = 0,
      clustering = 0,
      modularity = 0,
      constraint = 1
    ))
  }
  
  g <- graph_from_data_frame(
    d = valid_edges[, .(vertex1, vertex2)],
    directed = FALSE,
    vertices = data.frame(name = ego_alters)
  )
  
  dens <- edge_density(g)
  clust <- transitivity(g, type = "global")
  if (is.na(clust)) clust <- 0
  
  mod <- 0
  if (gsize(g) > 1 && vcount(g) > 2) {
    tryCatch({
      cl <- cluster_fast_greedy(g)
      mod <- modularity(cl)
    }, error = function(e) { mod <- 0 })
  }
  
  constr <- 0
  tryCatch({
    c_vals <- constraint(g)
    constr <- mean(c_vals, na.rm = TRUE)
  }, error = function(e) { constr <- 1 })
  
  tibble(
    egoid = ego,
    wave = w,
    deg = n_alters,
    density = dens,
    clustering = clust,
    modularity = if (is.na(mod)) 0 else mod,
    constraint = if (is.na(constr)) 1 else constr
  )
}

# Run across all ego-waves
ego_wave_list <- list()
for (idx in 1:nrow(ego_waves)) {
  ego_wave_list[[idx]] <- compute_ego_metrics(ego_waves$egoid[idx], ego_waves$wave_num[idx])
}
egonet_topology <- bind_rows(ego_wave_list)
cat(sprintf("Computed topology for %d ego-wave observations across %d unique egos.\n",
            nrow(egonet_topology), uniqueN(egonet_topology$egoid)))

saveRDS(egonet_topology, "data/processed/egonet_topology_by_wave.rds")

# ==============================================================================
# Helper Functions
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

# ==============================================================================
# 2. Compute Alter Turnover & Divergence across Call Windows
# ==============================================================================
cat("\nComputing alter turnover and signature self-divergence...\n")
sig_data <- readRDS("data/processed/social_signatures_and_jsd.rds")

compute_turnover_df <- function(scheme_res, scheme_name) {
  sig_dt <- scheme_res$sig_dt
  egos <- sort(unique(sig_dt$egoid))
  
  rows <- list()
  for (ego in egos) {
    sub <- sig_dt[egoid == ego][order(window)]
    if (nrow(sub) < 2) next
    
    for (t in 1:(nrow(sub) - 1)) {
      w1 <- sub$window[t]
      w2 <- sub$window[t + 1]
      
      a1 <- sub$alters[[t]]
      a2 <- sub$alters[[t + 1]]
      
      # Jaccard similarity
      inter <- length(intersect(a1, a2))
      union_len <- length(union(a1, a2))
      jaccard <- if (union_len == 0) 1 else inter / union_len
      turnover <- 1 - jaccard
      
      # Activity change
      c1 <- sub$total_calls[t]
      c2 <- sub$total_calls[t + 1]
      delta_activity <- abs(c2 - c1)
      pct_activity_change <- abs(c2 - c1) / max(1, c1)
      
      # Rank 1 persistence: did top alter stay top alter?
      top1_retained <- if (length(a1) > 0 && length(a2) > 0) (a1[1] == a2[1]) else FALSE
      # Top 3 retention
      top3_retained <- if (length(a1) >= 3 && length(a2) >= 3) {
        length(intersect(a1[1:3], a2[1:3])) / 3
      } else {
        NA_real_
      }
      
      # Pairwise JSD
      jsd_val <- jsd_pairwise(sub$signature[[t]], sub$signature[[t + 1]],
                              sub$entropy[t], sub$entropy[t + 1])
      
      rows[[length(rows) + 1]] <- tibble(
        scheme = scheme_name,
        egoid = ego,
        window_from = w1,
        window_to = w2,
        window_pair = paste(w1, w2, sep = " -> "),
        self_jsd = jsd_val,
        jaccard = jaccard,
        turnover = turnover,
        alters_w1 = length(a1),
        alters_w2 = length(a2),
        alters_retained = inter,
        alters_added = length(setdiff(a2, a1)),
        alters_dropped = length(setdiff(a1, a2)),
        calls_w1 = c1,
        calls_w2 = c2,
        delta_activity = delta_activity,
        pct_activity_change = pct_activity_change,
        top1_retained = top1_retained,
        top3_retention_ratio = top3_retained
      )
    }
  }
  bind_rows(rows)
}

turnover_sem <- compute_turnover_df(sig_data$semester, "Semesters")
turnover_mo  <- compute_turnover_df(sig_data$month, "Months")
turnover_roll3 <- compute_turnover_df(sig_data$rolling_3week, "3-Week Rolling")

cat(sprintf("Turnover & Divergence summary for Semesters (N = %d pairs):\n", nrow(turnover_sem)))
cat(sprintf("  - Mean Alter Turnover: %.3f (SD: %.3f)\n", mean(turnover_sem$turnover), sd(turnover_sem$turnover)))
cat(sprintf("  - Mean Self JSD:        %.4f (SD: %.4f)\n", mean(turnover_sem$self_jsd), sd(turnover_sem$self_jsd)))
cat(sprintf("  - Correlation(Turnover, Self-JSD): r = %.3f (p = %g)\n",
            cor(turnover_sem$turnover, turnover_sem$self_jsd),
            cor.test(turnover_sem$turnover, turnover_sem$self_jsd)$p.value))
cat(sprintf("  - Top 1 Alter Retained: %.1f%%\n", mean(turnover_sem$top1_retained) * 100))

# Tease out turnover vs divergence (Slide 26: "How stable when there is more turnover?")
turnover_bins <- turnover_sem %>%
  mutate(turnover_bracket = cut(turnover, breaks = c(0, 0.4, 0.6, 0.8, 1.0),
                                 include.lowest = TRUE,
                                 labels = c("Low (<=0.40)", "Moderate (0.41-0.60)", "High (0.61-0.80)", "Very High (>0.80)"))) %>%
  group_by(turnover_bracket) %>%
  summarise(
    n_pairs = n(),
    mean_turnover = mean(turnover),
    mean_self_jsd = mean(self_jsd),
    sd_self_jsd = sd(self_jsd),
    pct_top1_retained = mean(top1_retained) * 100,
    .groups = "drop"
  )

cat("\nStability across Turnover Brackets (Semesters):\n")
print(turnover_bins)

# Save turnover datasets
saveRDS(list(
  turnover_semester = turnover_sem,
  turnover_month = turnover_mo,
  turnover_rolling3 = turnover_roll3,
  turnover_brackets = turnover_bins
), "data/processed/turnover_and_divergence.rds")

cat("\n>>> Step 4 completed successfully! Saved to data/processed/turnover_and_divergence.rds\n")
