#!/usr/bin/env bash
# Rebuild jobservice.txt from job-service-raw.log and run testFiles.py (after a perf run).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RAW_LOG="${1:-job-service-raw.log}"
PATTERN="${2:-RM_CREATE_REQUEST_RECEIVED}"
JOBSERVICE_FILE="$SCRIPT_DIR/jobservice.txt"
PYTHON="${PYTHON:-python3}"

[[ -f "$RAW_LOG" ]] || { echo "Missing $RAW_LOG" >&2; exit 1; }

grep "$PATTERN" "$RAW_LOG" | "$PYTHON" -c '
import re, sys
pat_log_time = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})")
pat_json_time = re.compile(r"\"localTime\":\"([^\"]+)\"")
pat_case = re.compile(r"\"caseId\":\"([^\"]+)\"")

def to_testfiles_time(line: str) -> str:
    m_log = pat_log_time.search(line)
    if m_log:
        return m_log.group(1).split(" ", 1)[1]
    m_json = pat_json_time.search(line)
    if m_json:
        iso = m_json.group(1)
        tpart = iso.split("T", 1)[-1].split("+")[0].split("Z")[0]
        return tpart[:12] if len(tpart) >= 12 else tpart.ljust(12)[:12]
    return "00:00:00.000"

for line in sys.stdin:
    m_case = pat_case.search(line)
    if not m_case:
        continue
    print(to_testfiles_time(line), m_case.group(1))
' >"$JOBSERVICE_FILE"

echo "Wrote $(wc -l < "$JOBSERVICE_FILE" | tr -d " ") lines to $JOBSERVICE_FILE"
"$PYTHON" testFiles.py
