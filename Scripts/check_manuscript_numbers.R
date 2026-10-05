#!/usr/bin/env Rscript
# ==============================================================================
# Scripts/check_manuscript_numbers.R
# Project: Social Signatures in NetHealth
#
# Closes the last link in the staleness chain discovered 2026-10-04:
#   output/tables/*.csv (pipeline)  --[Scripts/generate_md_tables.R]-->  cache/*.md
#   cache/*.md  --[hand-pasted]-->  manuscript.tex / supplementary.tex
# Scripts/check_cache_staleness.R guards the first arrow (pipeline -> cache).
# This script guards the second arrow (cache -> manuscript prose/tables) by
# checking that every "distinctive" numeric value appearing in cache/*.md can
# also be found, in some plausible rounding, somewhere in manuscript.tex or
# supplementary.tex.
#
# This is a HEURISTIC substring search, not an exact diff: manuscript prose
# legitimately rounds, re-expresses, or omits individual cache values, so a
# flagged value is a prompt for manual review, not automatic proof of drift.
# To keep false positives manageable, only "distinctive" tokens (numbers with
# a decimal point, or with >= 3 digits) are checked -- small plain integers
# (ranks, footnote markers, list counts, etc.) are skipped because they match
# too much incidental text to be informative.
#
# Usage:   Rscript Scripts/check_manuscript_numbers.R
# Exit status: 0 if every distinctive cache/*.md value is found; 1 otherwise.
# ==============================================================================

suppressPackageStartupMessages(library(tidyverse))

tex_files <- c("manuscript.tex", "supplementary.tex")
tex_files <- tex_files[file.exists(tex_files)]
if (length(tex_files) == 0) stop("Neither manuscript.tex nor supplementary.tex found in the working directory.")

tex_text <- paste(unlist(lapply(tex_files, readLines, warn = FALSE)), collapse = "\n")

cache_files <- sort(list.files("cache", pattern = "\\.md$", full.names = TRUE))
if (length(cache_files) == 0) stop("No cache/*.md files found; run Scripts/generate_md_tables.R first.")

# Pull numeric tokens (ints/decimals, optional thousands commas, optional sign)
extract_tokens <- function(line) {
  m <- gregexpr("[-+]?[0-9][0-9,]*\\.?[0-9]*", line)
  toks <- regmatches(line, m)[[1]]
  toks[!toks %in% c("", "-", "+")]
}

is_distinctive <- function(tok) {
  plain <- gsub("[,+-]", "", tok)
  grepl("\\.", tok) || nchar(plain) >= 3
}

# Accept the token as-is, without thousands commas, and rounded one decimal
# place coarser (the most common way prose re-expresses a table value).
value_variants <- function(tok) {
  variants <- c(tok, gsub(",", "", tok))
  no_comma <- gsub(",", "", tok)
  num <- suppressWarnings(as.numeric(no_comma))
  if (!is.na(num) && grepl("\\.", no_comma)) {
    dec <- nchar(strsplit(no_comma, "\\.")[[1]][2])
    if (dec >= 1) variants <- c(variants, sprintf(paste0("%.", dec - 1, "f"), num))
  }
  unique(variants)
}

found_in_tex <- function(tok) any(vapply(value_variants(tok), grepl, logical(1), x = tex_text, fixed = TRUE))

results <- list()
for (cf in cache_files) {
  lines <- readLines(cf, warn = FALSE)
  if (length(lines) < 3) next
  data_lines <- lines[-(1:2)]  # drop header + markdown separator row
  for (i in seq_along(data_lines)) {
    toks <- unique(Filter(is_distinctive, extract_tokens(data_lines[i])))
    missing <- Filter(Negate(found_in_tex), toks)
    if (length(missing) > 0) {
      results[[length(results) + 1]] <- tibble(
        cache_file = basename(cf), row = i, token = missing, row_text = trimws(data_lines[i])
      )
    }
  }
}

report <- if (length(results) > 0) bind_rows(results) %>% unnest(token) else tibble()

cat("\n================ Manuscript/Supplementary Number Cross-Check ================\n")
cat(sprintf("Checked against: %s\n", paste(tex_files, collapse = ", ")))
cat(sprintf("Cache files scanned: %s\n\n", paste(basename(cache_files), collapse = ", ")))

if (nrow(report) == 0) {
  cat("OK: every distinctive numeric value in cache/*.md was found, in some\n")
  cat("plausible rounding, somewhere in manuscript.tex / supplementary.tex.\n")
  quit(status = 0)
}

cat(sprintf("%d distinctive value(s) from cache/*.md were NOT found in either .tex file:\n\n", nrow(report)))
for (cf in unique(report$cache_file)) {
  sub <- report %>% filter(cache_file == cf)
  cat(sprintf("--- %s ---\n", cf))
  for (j in seq_len(nrow(sub))) {
    cat(sprintf("  Row %d: '%s'  (row: %s)\n", sub$row[j], sub$token[j], sub$row_text[j]))
  }
  cat("\n")
}
cat("NOTE: this is a heuristic substring search, not an exact diff. Prose that\n")
cat("rounds, re-expresses, or simply omits a cache value will show up here as\n")
cat("a false positive -- treat every line above as a prompt to manually verify\n")
cat("against manuscript.tex / supplementary.tex, not as definitive drift.\n")
quit(status = 1)
