#!/usr/bin/env Rscript
# ==============================================================================
# Scripts/sync_manuscript.R
# Master driver script for Google Drive manuscript synchronization.
# Adheres strictly to AGENTS.md Section 8 and Section 10:
# - Formats manuscript in Alegreya Sans 11pt, 1.5 line spacing, 0.5-inch indent
# - Injects APA 7th native OpenXML tables and 300 DPI publication figures
# - Updates Google Doc directly on Google Drive
# - Cleans up intermediate scratch files automatically
# ==============================================================================

suppressPackageStartupMessages({
  library(googledrive)
})

main <- function() {
  doc_id <- "1CAVM2L25colX4ok5fdewBGo1-wWk-NzhX9esQ2nBU_o"
  base_docx <- "draft_base.docx"
  injected_docx <- "draft_injected.docx"
  formatted_docx <- "draft_formatted.docx"

  # Automated cleanup handler (AGENTS.md Section 6)
  on.exit({
    unlink(Sys.glob("draft_*.docx"))
    unlink(Sys.glob("draft_*.txt"))
    unlink(Sys.glob("*.tmp"))
    unlink("replacements.json")
  }, add = TRUE)

  message("[1/4] Ensuring table summaries in cache/ are up to date...")
  if (file.exists("Scripts/generate_md_tables.R")) {
    source("Scripts/generate_md_tables.R")
  }

  message("[2/4] Compiling standalone manuscript markdown to base docx...")
  system2("pandoc", args = c("draft_manuscript.md", "-o", base_docx))

  message("[3/4] Performing OpenXML table and figure injection and typography formatting...")
  exit_inject <- system2("python3", args = c("Scripts/sync_manuscript.py", base_docx, injected_docx))
  if (exit_inject != 0) {
    stop("Error during OpenXML injection.")
  }

  exit_format <- system2("python3", args = c("Scripts/format_manuscript.py", injected_docx, formatted_docx))
  if (exit_format != 0) {
    stop("Error during manuscript formatting.")
  }

  message("[4/4] Uploading updated manuscript to Google Drive...")
  drive_auth(email = "omarlizardo@gmail.com")
  drive_update(as_id(doc_id), media = formatted_docx)

  message("====================================================================")
  message("Synchronization complete! Standalone Google Doc updated successfully.")
  message(paste0("Document URL: https://docs.google.com/document/d/", doc_id))
  message("====================================================================")
}

main()
