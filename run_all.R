#!/usr/bin/env Rscript
# ==============================================================================
# Master Pipeline: Social Signatures in NetHealth
# Description: Executes complete replication and expansion pipeline end-to-end.
# ==============================================================================

cat("\n======================================================================\n")
cat("Starting Social Signatures in NetHealth Master Execution Pipeline\n")
cat("======================================================================\n\n")

start_time <- Sys.time()

scripts <- c(
  "scripts/01_prepare_call_windows.R",
  "scripts/02_compute_signatures_and_jsd.R",
  "scripts/03_fit_parametric_models.R",
  "scripts/04_egonet_topology_and_turnover.R",
  "scripts/05_survey_linkage_psychometrics.R",
  "scripts/06_expansion_statistical_models.R",
  "scripts/07_generate_figures_and_tables.R"
)

for (s in scripts) {
  cat(sprintf("\n>>> RUNNING: %s\n", s))
  t0 <- Sys.time()
  system2("Rscript", args = c(s))
  t1 <- Sys.time()
  cat(sprintf(">>> FINISHED: %s in %.1f seconds.\n", s, as.numeric(difftime(t1, t0, units = "secs"))))
}

end_time <- Sys.time()
cat("\n======================================================================\n")
cat(sprintf("Pipeline completed successfully in %.1f minutes!\n",
            as.numeric(difftime(end_time, start_time, units = "mins"))))
cat("All figures saved to output/plots/\n")
cat("All tables saved to output/tables/\n")
cat("All datasets saved to data/processed/\n")
cat("======================================================================\n\n")
