#!/bin/bash
# Resumable background downloader for the full NetHealth CommEvents CSV.
URL="https://drive.usercontent.google.com/download?id=1of-YDACmTcxluEoKLBpzXQNLNpwEVUp1&export=download&confirm=t&uuid=97f498a6-4a44-4f60-99b3-a2a30a64f66f"
OUT="/home/omarlizardo/projects/NETWORKS/social-signatures-NetHealth/data/raw/CommEvents_full_2015_2019.csv.part"
FINAL="/home/omarlizardo/projects/NETWORKS/social-signatures-NetHealth/data/raw/CommEvents_full_2015_2019.csv"
LOG="/home/omarlizardo/projects/NETWORKS/social-signatures-NetHealth/data/raw/download_full_events.log"

echo "=== Download loop started: $(date) ===" >> "$LOG"
for i in $(seq 1 100); do
  curl -L -C - --retry 5 --retry-delay 5 "$URL" -o "$OUT" >> "$LOG" 2>&1
  CODE=$?
  echo "=== curl exited with code $CODE on attempt $i: $(date) ===" >> "$LOG"
  if [ $CODE -eq 0 ]; then
    break
  fi
  sleep 5
done

# Expected size ~5957M; only finalize if we got close to that.
SIZE=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
echo "Final size: $SIZE bytes" >> "$LOG"
if [ "$SIZE" -gt 6000000000 ] || [ "$SIZE" -gt 5900000000 ]; then
  mv "$OUT" "$FINAL"
  echo "=== Moved to final location: $(date) ===" >> "$LOG"
else
  echo "=== WARNING: final size looks too small, not moving. ===" >> "$LOG"
fi
echo "DONE_MARKER" >> "$LOG"
