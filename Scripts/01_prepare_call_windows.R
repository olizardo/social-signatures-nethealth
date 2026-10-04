#!/usr/bin/env Rscript
# ==============================================================================
# Script 01: Prepare Communication-Event Windows (Calendar & Week-Based Binning)
# Project: Social Signatures in NetHealth
# Description: Bins pooled, multichannel outgoing communication events (voice
#              calls, SMS, MMS, and WhatsApp messages) from iOS devices into
#              calendar and week-based windows (Chandler 2019 Slides 6 & 13).
#
#              NOTE ON SCOPE (2026 revision): The original version of this
#              script restricted the analytic universe to eventtype == "Call"
#              only. Call events represent just 2.3% of all communication
#              events logged in NetHealth (vs. 97.7% text-based channels:
#              SMS 87.2%, WhatsApp 7.3%, MMS 3.2%; see
#              docs/Codebook Communication Events). This revision pools ALL
#              four event types into a single multichannel measure of
#              communication effort, counting each outgoing event (call, SMS,
#              MMS, or WhatsApp message) as one unit of interaction directed
#              from ego to alter, regardless of channel. This matches the
#              project's decision to analyze pooled multichannel signatures
#              rather than per-channel signatures.
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(data.table)
})

cat(">>> Step 1: Loading raw outgoing communication-events data (all channels)...\n")
full_file   <- "data/raw/CommEvents_full_2015_2019.csv.gz"
interim_file <- "data/raw/CommEvents_outgoing_iphone_2015_2017.csv"

# ------------------------------------------------------------------------------
# The full CommEvents file contains 60,486,564 rows (all egos, all event types,
# full 2015-2019 study period, incoming + outgoing, Android + iPhone). Loading
# that directly into R risks exhausting memory, so we first shell out to a
# single-pass awk filter (outgoing == "Yes", iphone == 1, and the analytic
# date window used throughout this project: 2015-06-30 to 2017-07-02) before
# handing a much smaller file to data.table::fread(). This mirrors the
# project's established "Fast GZ Ingestion" pattern for large raw extracts.
# ------------------------------------------------------------------------------
if (!file.exists(interim_file)) {
  stopifnot(file.exists(full_file))
  cat("    Pre-filtering full event log via awk (outgoing, iPhone, date window)...\n")
  awk_cmd <- sprintf(
    "zcat %s | awk -F',' 'NR==1{print;next} $12==\"Yes\" && $13==1 && $2>=\"2015-06-30\" && $2<=\"2017-07-02\" {print}' > %s",
    full_file, interim_file
  )
  system(awk_cmd)
}
stopifnot(file.exists(interim_file))

events_raw <- fread(interim_file,
                     select = c("egoid", "alterid", "date", "eventtype", "eventtypedetail",
                                "duration", "length", "bytes"),
                     colClasses = list(character = c("egoid", "alterid")))

cat(sprintf("Loaded %s outgoing iOS communication events (all channels), %s.\n",
            format(nrow(events_raw), big.mark = ","), "2015-06-30 through 2017-07-02"))

# ==============================================================================
# Apply NetHealth-recommended data-quality exclusions (see Communication Event
# Data documentation at https://sites.nd.edu/nethealth/communication-event-data/):
#   - Exclude calls of zero duration
#   - Exclude messages (SMS/WhatsApp) of zero Length
#   - Exclude messages (MMS/WhatsApp) of zero Bytes
#   - Exclude WhatsApp Group Chats (eventtypedetail == "GC"; not dyadic ties)
# Records with MISSING duration/length/bytes are retained, per NetHealth
# guidance, since missingness there does not indicate a zero-content event.
# ==============================================================================
cat(">>> Applying NetHealth-recommended data-quality filters...\n")
n0 <- nrow(events_raw)
drop_mask <- (events_raw$eventtype == "Call" & !is.na(events_raw$duration) & events_raw$duration == 0) |
  (events_raw$eventtype %in% c("SMS", "WhatsApp") & !is.na(events_raw$length) & events_raw$length == 0) |
  (events_raw$eventtype %in% c("MMS", "WhatsApp") & !is.na(events_raw$bytes) & events_raw$bytes == 0) |
  (events_raw$eventtype == "WhatsApp" & events_raw$eventtypedetail == "GC")
events_raw <- events_raw[!drop_mask]
cat(sprintf("    Dropped %s records (zero-duration/length/bytes or WhatsApp group chats).\n",
            format(sum(drop_mask), big.mark = ",")))
rm(drop_mask); gc(verbose = FALSE)

# Drop self-events or missing ids
events <- events_raw[!is.na(egoid) & !is.na(alterid) & egoid != alterid & alterid != ""]
events[, date := as.IDate(date)]
rm(events_raw); gc(verbose = FALSE)

cat(sprintf("Retained %s valid pooled outgoing events across %d egos.\n",
            format(nrow(events), big.mark = ","), uniqueN(events$egoid)))
cat("Composition by channel:\n")
print(events[, .N, by = eventtype][order(-N)])

# ==============================================================================
# 1. CALENDAR-BASED WINDOWS (July 1, 2015 - June 30, 2017)
# ==============================================================================
cal_start <- as.IDate("2015-07-01")
cal_end   <- as.IDate("2017-06-30")
events_cal <- events[date >= cal_start & date <= cal_end]

# 1a. Academic Years: 2 windows (Jul-Jun)
events_cal[, academic_year := fifelse(date <= as.IDate("2016-06-30"), "AY15-16", "AY16-17")]

# 1b. Semesters: 4 windows (Jul-Dec; Jan-Jun)
events_cal[, semester := fcase(
  date <= as.IDate("2015-12-31"), "2015-Fall",
  date <= as.IDate("2016-06-30"), "2016-Spring",
  date <= as.IDate("2016-12-31"), "2016-Fall",
  default = "2017-Spring"
)]

# 1c. Quarters: 8 windows (Jul-Sep, Oct-Dec, Jan-Mar, Apr-Jun)
events_cal[, quarter := fcase(
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
events_cal[, month := format(date, "%Y-%m")]

# ==============================================================================
# 2. WEEK-BASED WINDOWS (July 6, 2015 - July 2, 2017 = 104 Monday-Sunday Weeks)
# ==============================================================================
week_start <- as.IDate("2015-07-06")
week_end   <- as.IDate("2017-07-02")
events_week <- events[date >= week_start & date <= week_end]
events_week[, week_idx := as.integer(as.integer(date - week_start) %/% 7L) + 1L]

# ==============================================================================
# 3. Filtering Function (Slide 6 & Slide 13)
#    - More than 1 alter (>1 alter, i.e., min 2 alters) in EVERY window
#    - Average number of communication events per window > 10
# ==============================================================================
filter_eligible_cohort <- function(dt, window_col) {
  # Aggregate pooled events per ego, alter, and window
  agg <- dt[, .(events = .N), by = c("egoid", "alterid", window_col)]
  setnames(agg, window_col, "window")

  all_windows <- sort(unique(dt[[window_col]]))
  num_windows <- length(all_windows)

  # Window level stats per ego
  ego_win <- agg[, .(n_alters = uniqueN(alterid), n_events = sum(events)), by = .(egoid, window)]

  # Ego overall stats
  ego_stats <- ego_win[, .(
    active_windows = uniqueN(window),
    min_alters = min(n_alters),
    total_events = sum(n_events),
    avg_events = sum(n_events) / num_windows
  ), by = egoid]

  # Selection criteria: active in all windows, >1 alter in all windows, avg events > 10
  eligible_egos <- ego_stats[active_windows == num_windows & min_alters >= 2 & avg_events > 10, egoid]

  list(
    agg_filtered = agg[egoid %in% eligible_egos],
    eligible_egos = eligible_egos,
    num_windows = num_windows,
    total_candidate_egos = uniqueN(dt$egoid),
    eligible_count = length(eligible_egos)
  )
}

cat(">>> Step 2: Binning pooled communication events into Calendar and Week-based schemes...\n")
res_ay       <- filter_eligible_cohort(events_cal, "academic_year")
res_semester <- filter_eligible_cohort(events_cal, "semester")
res_quarter  <- filter_eligible_cohort(events_cal, "quarter")
res_month    <- filter_eligible_cohort(events_cal, "month")
res_week1    <- filter_eligible_cohort(events_week, "week_idx")

# 2-week discrete windows (52 windows)
events_week[, biweek_idx := as.integer((week_idx - 1) %/% 2) + 1L]
res_week2    <- filter_eligible_cohort(events_week, "biweek_idx")

# 3-week rolling windows stepped by 1 week (102 windows)
rolling_list <- list()
for (start_w in 1:102) {
  end_w <- start_w + 2
  sub <- events_week[week_idx >= start_w & week_idx <= end_w,
                    .(events = .N), by = .(egoid, alterid)]
  sub[, window := sprintf("W%03d-W%03d", start_w, end_w)]
  rolling_list[[start_w]] <- sub
}
events_roll3 <- rbindlist(rolling_list)

# Filter 3-week rolling:
ego_win_roll3 <- events_roll3[, .(n_alters = uniqueN(alterid), n_events = sum(events)), by = .(egoid, window)]
ego_stats_roll3 <- ego_win_roll3[, .(
  active_windows = uniqueN(window),
  min_alters = min(n_alters),
  avg_events = sum(n_events) / 102
), by = egoid]
eligible_roll3 <- ego_stats_roll3[active_windows == 102 & min_alters >= 2 & avg_events > 10, egoid]
agg_roll3 <- events_roll3[egoid %in% eligible_roll3]

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
  Min_Avg_Events_Criteria = "> 10 per window",
  Eligible_Egos = c(res_ay$eligible_count, res_semester$eligible_count, res_quarter$eligible_count, res_month$eligible_count,
                    length(common_calendar_egos), length(eligible_roll3), res_week2$eligible_count, res_week1$eligible_count)
)

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
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
  events_cal = events_cal
), "data/processed/call_windows.rds")

cat(">>> Step 1 completed successfully! Processed data saved to data/processed/call_windows.rds\n")
