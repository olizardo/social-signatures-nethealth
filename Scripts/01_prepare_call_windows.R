#!/usr/bin/env Rscript
# ==============================================================================
# Script 01: Prepare Call Windows (Calendar & Week-Based Binning)
# Project: Social Signatures in NetHealth
# Description: Implements Chandler (2019) Slide 6 & 13 binning procedures for
#              outgoing calls from iOS devices.
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(data.table)
})

cat(">>> Step 1: Loading raw outgoing calls data...\n")
calls_file <- "data/raw/outgoing_calls_2015_2017.csv.gz"
stopifnot(file.exists(calls_file))

# Read calls data efficiently via zcat command
calls_raw <- fread(cmd = sprintf("zcat %s", calls_file), 
                   select = c("egoid", "alterid", "date", "outgoing", "iphone", "eventtype"))

# Filter to outgoing phone calls from iOS devices (as specified in Chandler 2019 Slide 5)
calls <- calls_raw[outgoing == "Yes" & iphone == 1 & eventtype == "Call"]
calls[, date := as.IDate(date)]
calls[, egoid := as.character(egoid)]
calls[, alterid := as.character(alterid)]

# Drop self-calls or missing IDs
calls <- calls[!is.na(egoid) & !is.na(alterid) & egoid != alterid & alterid != ""]

cat(sprintf("Loaded %s valid outgoing iOS calls across %d egos.\n", 
            format(nrow(calls), big.mark=","), uniqueN(calls$egoid)))

# ==============================================================================
# 1. CALENDAR-BASED WINDOWS (July 1, 2015 - June 30, 2017)
# ==============================================================================
cal_start <- as.IDate("2015-07-01")
cal_end   <- as.IDate("2017-06-30")
calls_cal <- calls[date >= cal_start & date <= cal_end]

# 1a. Academic Years: 2 windows (Jul-Jun)
calls_cal[, academic_year := fifelse(date <= as.IDate("2016-06-30"), "AY15-16", "AY16-17")]

# 1b. Semesters: 4 windows (Jul-Dec; Jan-Jun)
calls_cal[, semester := fcase(
  date <= as.IDate("2015-12-31"), "2015-Fall",
  date <= as.IDate("2016-06-30"), "2016-Spring",
  date <= as.IDate("2016-12-31"), "2016-Fall",
  default = "2017-Spring"
)]

# 1c. Quarters: 8 windows (Jul-Sep, Oct-Dec, Jan-Mar, Apr-Jun)
calls_cal[, quarter := fcase(
  date <= as.IDate("2015-09-30"), "2015-Q3",
  date <= as.IDate("2015-12-31"), "2015-Q4",
  date <= as.IDate("2016-03-31"), "2016-Q1",
  date <= as.IDate("2016-06-30"), "2016-Q2",
  date <= as.IDate("2016-09-30"), "2016-Q3",
  date <= as.IDate("2016-12-31"), "2016-Q4",
  date <= as.IDate("2017-03-31"), "2017-Q1",
  default = "2017-Q2"
)]

# 1d. Months: 24 windows
calls_cal[, month := format(date, "%Y-%m")]

# ==============================================================================
# 2. WEEK-BASED WINDOWS (July 6, 2015 - July 2, 2017 = 104 Monday-Sunday Weeks)
# ==============================================================================
week_start <- as.IDate("2015-07-06")
week_end   <- as.IDate("2017-07-02")
calls_week <- calls[date >= week_start & date <= week_end]
calls_week[, week_idx := as.integer(as.integer(date - week_start) %/% 7L) + 1L]

# ==============================================================================
# 3. Filtering Function (Slide 6 & Slide 13)
#    - More than 1 alter (>1 alter, i.e., min 2 alters) in EVERY window
#    - Average number of calls per window > 10
# ==============================================================================
filter_eligible_cohort <- function(dt, window_col) {
  # Aggregate calls per ego, alter, and window
  agg <- dt[, .(calls = .N), by = c("egoid", "alterid", window_col)]
  setnames(agg, window_col, "window")
  
  all_windows <- sort(unique(dt[[window_col]]))
  num_windows <- length(all_windows)
  
  # Window level stats per ego
  ego_win <- agg[, .(n_alters = uniqueN(alterid), n_calls = sum(calls)), by = .(egoid, window)]
  
  # Ego overall stats
  ego_stats <- ego_win[, .(
    active_windows = uniqueN(window),
    min_alters = min(n_alters),
    total_calls = sum(n_calls),
    avg_calls = sum(n_calls) / num_windows
  ), by = egoid]
  
  # Selection criteria: active in all windows, >1 alter in all windows, avg calls > 10
  eligible_egos <- ego_stats[active_windows == num_windows & min_alters >= 2 & avg_calls > 10, egoid]
  
  list(
    agg_filtered = agg[egoid %in% eligible_egos],
    eligible_egos = eligible_egos,
    num_windows = num_windows,
    total_candidate_egos = uniqueN(dt$egoid),
    eligible_count = length(eligible_egos)
  )
}

cat(">>> Step 2: Binning calls into Calendar and Week-based schemes...\n")
res_ay       <- filter_eligible_cohort(calls_cal, "academic_year")
res_semester <- filter_eligible_cohort(calls_cal, "semester")
res_quarter  <- filter_eligible_cohort(calls_cal, "quarter")
res_month    <- filter_eligible_cohort(calls_cal, "month")
res_week1    <- filter_eligible_cohort(calls_week, "week_idx")

# 2-week discrete windows (52 windows)
calls_week[, biweek_idx := as.integer((week_idx - 1) %/% 2) + 1L]
res_week2    <- filter_eligible_cohort(calls_week, "biweek_idx")

# 3-week rolling windows stepped by 1 week (102 windows)
rolling_list <- list()
for (start_w in 1:102) {
  end_w <- start_w + 2
  sub <- calls_week[week_idx >= start_w & week_idx <= end_w, 
                    .(calls = .N), by = .(egoid, alterid)]
  sub[, window := sprintf("W%03d-W%03d", start_w, end_w)]
  rolling_list[[start_w]] <- sub
}
calls_roll3 <- rbindlist(rolling_list)

# Filter 3-week rolling:
ego_win_roll3 <- calls_roll3[, .(n_alters = uniqueN(alterid), n_calls = sum(calls)), by = .(egoid, window)]
ego_stats_roll3 <- ego_win_roll3[, .(
  active_windows = uniqueN(window),
  min_alters = min(n_alters),
  avg_calls = sum(n_calls) / 102
), by = egoid]
eligible_roll3 <- ego_stats_roll3[active_windows == 102 & min_alters >= 2 & avg_calls > 10, egoid]
agg_roll3 <- calls_roll3[egoid %in% eligible_roll3]

# Comparison cohort (Slide 13: "When comparing window widths, select those egos satisfying the above criteria for all window widths")
common_calendar_egos <- intersect(intersect(res_ay$eligible_egos, res_semester$eligible_egos),
                                  intersect(res_quarter$eligible_egos, res_month$eligible_egos))

cat(sprintf("Eligible Egos:\n - Academic Years (2 windows): %d\n - Semesters (4 windows): %d\n - Quarters (8 windows): %d\n - Months (24 windows): %d\n - Common Calendar Cohort: %d\n - 3-week Rolling (102 windows): %d\n - 2-week Discrete (52 windows): %d\n - 1-week Discrete (104 windows): %d\n",
            res_ay$eligible_count, res_semester$eligible_count, res_quarter$eligible_count, 
            res_month$eligible_count, length(common_calendar_egos),
            length(eligible_roll3), res_week2$eligible_count, res_week1$eligible_count))

# Save summary table
table01 <- tibble(
  Scheme = c("Academic Years", "Semesters", "Quarters", "Months", "Common Calendar Intersection", 
             "3-Week Rolling", "2-Week Discrete", "1-Week Discrete"),
  Window_Span = c("Jul 2015 - Jun 2017", "Jul 2015 - Jun 2017", "Jul 2015 - Jun 2017", "Jul 2015 - Jun 2017",
                  "Jul 2015 - Jun 2017", "Jul 2015 - Jul 2017", "Jul 2015 - Jul 2017", "Jul 2015 - Jul 2017"),
  Number_of_Windows = c(res_ay$num_windows, res_semester$num_windows, res_quarter$num_windows, res_month$num_windows,
                        NA, 102, res_week2$num_windows, res_week1$num_windows),
  Min_Alters_Criteria = ">= 2 in every window",
  Min_Avg_Calls_Criteria = "> 10 per window",
  Eligible_Egos = c(res_ay$eligible_count, res_semester$eligible_count, res_quarter$eligible_count, res_month$eligible_count,
                    length(common_calendar_egos), length(eligible_roll3), res_week2$eligible_count, res_week1$eligible_count)
)

write_csv(table01, "output/tables/table01_cohort_summary.csv")
cat("Saved cohort summary table to output/tables/table01_cohort_summary.csv\n")

# Save processed window datasets
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
saveRDS(list(
  academic_year = res_ay$agg_filtered,
  semester = res_semester$agg_filtered,
  quarter = res_quarter$agg_filtered,
  month = res_month$agg_filtered,
  rolling_3week = agg_roll3,
  discrete_2week = res_week2$agg_filtered,
  discrete_1week = res_week1$agg_filtered,
  common_calendar_egos = common_calendar_egos,
  calls_cal = calls_cal
), "data/processed/call_windows.rds")

cat(">>> Step 1 completed successfully! Processed data saved to data/processed/call_windows.rds\n")
