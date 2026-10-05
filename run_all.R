#!/usr/bin/env Rscript
# ==============================================================================
# Master Pipeline: Social Signatures in NetHealth
# Description: Executes complete replication and expansion pipeline end-to-end,
#              then verifies that no stale cache/*.md or manuscript numbers
#              slipped through (see Scripts/check_cache_staleness.R and
#              Scripts/check_manuscript_numbers.R).
# ==============================================================================

cat("\n======================================================================\n")
cat("Starting Social Signatures in NetHealth Master Execution Pipeline\n")
cat("======================================================================\n\n")

start_time <- Sys.time()

# NOTE (fixed 2026-10-04): this list previously pointed at a lowercase
# "scripts/" directory that does not exist on this (case-sensitive) Linux
# filesystem -- every system2() call below silently failed and the loop kept
# going regardless, so the pipeline appeared to "complete" without doing
# anything. The actual directory is "Scripts/" (capital S). system2()'s exit
# status is now checked explicitly so a broken step stops the run instead of
# failing silently again.
scripts <- c(
  "Scripts/01_prepare_call_windows.R",
  "Scripts/02_compute_signatures_and_jsd.R",
  "Scripts/03_fit_parametric_models.R",
  "Scripts/04_egonet_topology_and_turnover.R",
  "Scripts/05_survey_linkage_psychometrics.R",
  "Scripts/06_expansion_statistical_models.R",
  "Scripts/06b_tie_attribute_models.R",
  "Scripts/08_channel_robustness.R",
  "Scripts/07_generate_figures_and_tables.R",
  "Scripts/generate_md_tables.R"
)

for (s in scripts) {
  cat(sprintf("\n>>> RUNNING: %s\n", s))
  t0 <- Sys.time()
  status <- system2("Rscript", args = c(s))
  t1 <- Sys.time()
  cat(sprintf(">>> FINISHED: %s in %.1f seconds.\n", s, as.numeric(difftime(t1, t0, units = "secs"))))
  if (status != 0) {
    stop(sprintf("Pipeline step '%s' exited with non-zero status (%d). Aborting.", s, status))
  }
}

end_time <- Sys.time()
cat("\n======================================================================\n")
cat(sprintf("Pipeline completed successfully in %.1f minutes!\n",
            as.numeric(difftime(end_time, start_time, units = "mins"))))
cat("All figures saved to output/plots/\n")
cat("All tables saved to output/tables/\n")
cat("All datasets saved to data/processed/\n")
cat("All markdown tables saved to cache/\n")
cat("======================================================================\n\n")

# ------------------------------------------------------------------------------
# Staleness audit: confirm cache/*.md matches output/tables/*.csv, and that
# every distinctive cache/*.md value is still reflected somewhere in
# manuscript.tex / supplementary.tex. Both checks print their own detailed
# report; the pipeline run fails loudly here rather than letting a pooling
# revision (or any future data change) silently drift out of the manuscript.
# ------------------------------------------------------------------------------
cat("======================================================================\n")
cat("Running staleness audit: cache/ vs output/tables/, and .tex vs cache/\n")
cat("======================================================================\n")

# check_cache_staleness.R is an exact diff and has shown zero false
# positives, so it is a hard gate: it stops the pipeline run.
cache_status <- system2("Rscript", args = "Scripts/check_cache_staleness.R")
if (cache_status != 0) {
  stop(paste(
    "Cache staleness check failed (see report above).",
    "Re-run Scripts/generate_md_tables.R before treating this pipeline run as final."
  ))
}

# check_manuscript_numbers.R is a heuristic substring search and can
# legitimately flag values that manuscript prose rounds or re-expresses
# differently than cache/*.md -- it is advisory only and does not stop the
# pipeline, but its report is always printed for manual review.
manuscript_status <- system2("Rscript", args = "Scripts/check_manuscript_numbers.R")
if (manuscript_status != 0) {
  cat("\nNOTE: manuscript number cross-check flagged possible drift (see report\n")
  cat("above). This is advisory only -- review the flagged value(s) and update\n")
  cat("manuscript.tex / supplementary.tex if they are genuine, but this does not\n")
  cat("block the pipeline run.\n\n")
} else {
  cat("\nStaleness audit passed: cache/ and the manuscript are in sync.\n\n")
}
