#!/usr/bin/env Rscript
# ==============================================================================
# Scripts/check_cache_staleness.R
# Project: Social Signatures in NetHealth
#
# Guards against the exact failure mode discovered 2026-10-04: cache/*.md
# files (hand-pasted into supplementary.tex / manuscript.tex, or synced into
# Word via sync_manuscript.R) silently drifting out of sync with the
# underlying output/tables/*.csv pipeline outputs -- e.g. after a data/
# pipeline change (such as the multichannel pooling revision) that updates
# the CSVs but leaves a previously-generated or hand-edited .md untouched.
#
# Method: re-run Scripts/generate_md_tables.R into a disposable scratch
# directory (via the MD_TABLES_OUT_DIR env var) and byte-diff every file it
# produces against the corresponding committed file in cache/. This never
# duplicates generate_md_tables.R's formatting/labeling logic -- it always
# re-derives the "correct" answer from the single generator script, so any
# future edit to that script's formatting is automatically honored here too.
#
# Usage:
#   Rscript Scripts/check_cache_staleness.R
# Exit status: 0 if cache/ is fully in sync, 1 if any file is stale, missing,
# or extra (present in cache/ but no longer produced by the generator).
# ==============================================================================

suppressPackageStartupMessages(library(tidyverse))

cache_dir <- "cache"
scratch_dir <- file.path(tempdir(), paste0("md_tables_check_", Sys.getpid()))
dir.create(scratch_dir, showWarnings = FALSE, recursive = TRUE)
on.exit(unlink(scratch_dir, recursive = TRUE), add = TRUE)

cat(">>> Regenerating markdown tables into scratch directory for comparison...\n")
gen_result <- system2(
  "Rscript",
  args = c("Scripts/generate_md_tables.R"),
  env = c(paste0("MD_TABLES_OUT_DIR=", scratch_dir)),
  stdout = TRUE, stderr = TRUE
)
cat(paste(gen_result, collapse = "\n"), "\n")

fresh_files <- list.files(scratch_dir, pattern = "\\.md$", full.names = FALSE)
cached_files <- if (dir.exists(cache_dir)) list.files(cache_dir, pattern = "\\.md$", full.names = FALSE) else character(0)

stale <- character(0)
missing_from_cache <- character(0)
orphaned_in_cache <- setdiff(cached_files, fresh_files)

for (f in fresh_files) {
  fresh_path <- file.path(scratch_dir, f)
  cached_path <- file.path(cache_dir, f)

  if (!file.exists(cached_path)) {
    missing_from_cache <- c(missing_from_cache, f)
    next
  }

  fresh_lines <- readLines(fresh_path)
  cached_lines <- readLines(cached_path)

  if (!identical(fresh_lines, cached_lines)) {
    stale <- c(stale, f)
    cat(sprintf("\n=== DRIFT DETECTED: %s ===\n", f))
    max_len <- max(length(fresh_lines), length(cached_lines))
    for (i in seq_len(max_len)) {
      cl <- if (i <= length(cached_lines)) cached_lines[i] else "<missing line>"
      fl <- if (i <= length(fresh_lines)) fresh_lines[i] else "<missing line>"
      if (!identical(cl, fl)) {
        cat(sprintf("  Line %d\n    cache/%-30s %s\n    regenerated:%-21s %s\n", i, f, cl, "", fl))
      }
    }
  }
}

cat("\n==================== Cache Staleness Check Summary ====================\n")
if (length(stale) == 0 && length(missing_from_cache) == 0 && length(orphaned_in_cache) == 0) {
  cat(sprintf("OK: all %d cache/*.md files match the regenerated output of Scripts/generate_md_tables.R.\n",
              length(fresh_files)))
  quit(status = 0)
}

if (length(stale) > 0) {
  cat(sprintf("STALE (%d): %s\n", length(stale), paste(stale, collapse = ", ")))
  cat("  -> these cache/ files no longer match output/tables/*.csv. Re-run\n")
  cat("     Rscript Scripts/generate_md_tables.R to refresh them, then check\n")
  cat("     whether manuscript.tex / supplementary.tex need matching edits.\n")
}
if (length(missing_from_cache) > 0) {
  cat(sprintf("MISSING FROM cache/ (%d): %s\n", length(missing_from_cache), paste(missing_from_cache, collapse = ", ")))
  cat("  -> Scripts/generate_md_tables.R now produces these but cache/ does not have them yet.\n")
}
if (length(orphaned_in_cache) > 0) {
  cat(sprintf("ORPHANED IN cache/ (%d): %s\n", length(orphaned_in_cache), paste(orphaned_in_cache, collapse = ", ")))
  cat("  -> these exist in cache/ but Scripts/generate_md_tables.R no longer produces them\n")
  cat("     (e.g. a removed analysis). Confirm they are not still referenced by\n")
  cat("     manuscript.tex / supplementary.tex, then delete them.\n")
}
quit(status = 1)
