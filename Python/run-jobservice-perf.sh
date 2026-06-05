#!/usr/bin/env bash
# Orchestrate Job Service perf: preflight → optional purge → publish → wait → report.
#
# Docker mode (default): Job Service + Rabbit in acceptance docker-compose containers.
# Local mode (--local): Spring Boot job-service via census31-fwmt-docs acceptance harness;
#   tail logs from FWMT_LOG_DIR/job-service.log (see start-services.sh).
#
# Examples:
#   ./run-jobservice-perf.sh --count 100 --scenario create --purge
#   ./run-jobservice-perf.sh --local --count 100 --purge --job-port 8025
#   ./run-jobservice-perf.sh --local --job-log /path/to/job-service.log --rabbit-port 5674

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# census31-fwmt-performance-tests/Python -> repo root is two levels up
_CENSUS31_REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CENSUS31_FWMT_ROOT="${CENSUS31_FWMT_ROOT:-$_CENSUS31_REPO_ROOT}"
ACCEPTANCE_HARNESS_DIR="${ACCEPTANCE_HARNESS_DIR:-$CENSUS31_FWMT_ROOT/census31-fwmt-acceptance-tests/scripts}"
DEFAULT_LOCAL_JOB_LOG="${FWMT_LOG_DIR:-$ACCEPTANCE_HARNESS_DIR/logs}/job-service.log"

COUNT="${CASES_TO_FETCH:-10}"
SCENARIO="create"
MODE="docker"
MESSAGING="${FWMT_MESSAGING:-rabbit}"
RABBIT_HOST="${RABBITMQ_HOST:-localhost}"
RABBIT_PORT="${RABBITMQ_PORT:-5672}"
RABBIT_USER="${RABBITMQ_USERNAME:-guest}"
RABBIT_PASSWORD="${RABBITMQ_PASSWORD:-guest}"
RABBIT_VHOST="${RABBITMQ_VHOST:-/}"
QUEUE_NAME="${RABBIT_QUEUENAME:-RM.Field}"
DLQ_NAME="${RM_FIELD_DLQ:-RM.FieldDLQ}"

# Pub/Sub emulator (mirrors census31-fwmt-acceptance-tests/scripts/setup-pubsub.sh)
PUBSUB_HOST="${FWMT_PUBSUB_HOST:-localhost}"
PUBSUB_PORT="${FWMT_PUBSUB_EMULATOR_PORT:-8085}"
PUBSUB_PROJECT="${FWMT_PUBSUB_PROJECT:-fwmt-local}"
PUBSUB_TOPIC="${FWMT_PUBSUB_TOPIC:-$QUEUE_NAME}"
# Service subscription drained in lieu of a Rabbit queue purge.
PUBSUB_DRAIN_SUB="${FWMT_PUBSUB_DRAIN_SUB:-job-service-RM-Field}"

JOB_CONTAINER="${JOB_CONTAINER:-jobv4}"
RABBIT_CONTAINER="${RABBIT_CONTAINER:-rabbit}"
JOB_PORT="${JOB_PORT:-}"
JOB_LOG_FILE="${JOB_LOG_FILE:-}"

PURGE=false
WAIT_TIMEOUT_SEC=600
POLL_INTERVAL_SEC=2
SKIP_REPORT=false
SKIP_HEALTH=false
PYTHON="${PYTHON:-python3}"

ARTIFACT_DIR="${ARTIFACT_DIR:-$SCRIPT_DIR}"
MESSAGE_PUBLISH_FILE="$ARTIFACT_DIR/Message_publish.txt"
JOBSERVICE_FILE="$ARTIFACT_DIR/jobservice.txt"
RAW_LOG_FILE="$ARTIFACT_DIR/job-service-raw.log"

LOG_EVENT_PATTERN="${LOG_EVENT_PATTERN:-}"

usage() {
  cat <<EOF
Usage: run-jobservice-perf.sh [options]

  --count N              Number of messages (default: 10)
  --scenario TYPE        create | cancel | update (default: create)
  --messaging BACKEND    rabbit | pubsub (default: rabbit; or set FWMT_MESSAGING)
  --purge                Purge (rabbit) or drain (pubsub) before run
  --local                Spring Boot mode: no job Docker container; tail --job-log
  --docker               Job Service in Docker (default)
  --rabbit-host HOST     (default: localhost)
  --rabbit-port PORT     (default: 5672; local harness often uses 5674 — set FWMT_RM_RABBIT_PORT)
  --rabbit-container C   Docker container for Rabbit preflight (default: rabbit)
  --pubsub-host HOST     Pub/Sub emulator host (default: localhost)
  --pubsub-port PORT     Pub/Sub emulator port (default: 8085)
  --job-container C      Docker container for logs in --docker mode (default: jobv4)
  --job-port PORT        HTTP health on localhost (local default: 8025)
  --job-log FILE         Log file to tail in --local mode
  --wait-timeout SEC     Max wait for consumption (default: 600)
  --skip-report          Publish only; skip testFiles.py
  --skip-health          Skip Job Service HTTP health check
  -h, --help

Local stack (before --local):
  cd $ACCEPTANCE_HARNESS_DIR    # census31-fwmt-acceptance-tests/scripts
  ./start-infra.sh
  # Rabbit (default):
  ./start-services.sh --build-missing job-service tm-mock
  # Pub/Sub: start the emulator + services in pubsub mode, e.g.
  FWMT_MESSAGING=pubsub ./start-services.sh --build-missing job-service tm-mock

Environment: CASES_TO_FETCH, FWMT_MESSAGING, RABBITMQ_*, FWMT_RM_RABBIT_PORT,
             FWMT_PUBSUB_HOST/PORT/PROJECT/TOPIC, JOB_LOG_FILE, CENSUS31_FWMT_ROOT
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count) COUNT="$2"; shift 2 ;;
    --scenario) SCENARIO="$2"; shift 2 ;;
    --messaging) MESSAGING="$2"; shift 2 ;;
    --purge) PURGE=true; shift ;;
    --local) MODE="local"; shift ;;
    --docker) MODE="docker"; shift ;;
    --rabbit-host) RABBIT_HOST="$2"; shift 2 ;;
    --rabbit-port) RABBIT_PORT="$2"; shift 2 ;;
    --rabbit-container) RABBIT_CONTAINER="$2"; shift 2 ;;
    --pubsub-host) PUBSUB_HOST="$2"; shift 2 ;;
    --pubsub-port) PUBSUB_PORT="$2"; shift 2 ;;
    --job-container) JOB_CONTAINER="$2"; shift 2 ;;
    --job-port) JOB_PORT="$2"; shift 2 ;;
    --job-log) JOB_LOG_FILE="$2"; shift 2 ;;
    --wait-timeout) WAIT_TIMEOUT_SEC="$2"; shift 2 ;;
    --skip-report) SKIP_REPORT=true; shift ;;
    --skip-health) SKIP_HEALTH=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$MODE" == "local" ]]; then
  RABBIT_PORT="${RABBITMQ_PORT:-${FWMT_RM_RABBIT_PORT:-5674}}"
  JOB_PORT="${JOB_PORT:-8025}"
  JOB_LOG_FILE="${JOB_LOG_FILE:-$DEFAULT_LOCAL_JOB_LOG}"
fi

MESSAGING="$(printf '%s' "$MESSAGING" | tr '[:upper:]' '[:lower:]')"
case "$MESSAGING" in
  rabbit|pubsub) ;;
  *) echo "Invalid --messaging '$MESSAGING' (expected rabbit or pubsub)" >&2; exit 1 ;;
esac

PUBSUB_API_BASE="http://${PUBSUB_HOST}:${PUBSUB_PORT}/v1/projects/${PUBSUB_PROJECT}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

require_container() {
  local name="$1"
  if ! docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -qx true; then
    die "Container '$name' is not running. Start your compose stack first."
  fi
  log "OK: container '$name' is running"
}

check_rabbit_tcp() {
  if command -v nc >/dev/null 2>&1; then
    if ! nc -z "$RABBIT_HOST" "$RABBIT_PORT" 2>/dev/null; then
      die "Cannot reach RabbitMQ at ${RABBIT_HOST}:${RABBIT_PORT}"
    fi
    log "OK: RabbitMQ TCP ${RABBIT_HOST}:${RABBIT_PORT}"
  else
    log "WARN: 'nc' not found; skipping TCP check"
  fi
}

check_rabbit_docker() {
  if docker inspect -f '{{.State.Running}}' "$RABBIT_CONTAINER" 2>/dev/null | grep -qx true; then
    if docker exec "$RABBIT_CONTAINER" rabbitmq-diagnostics check_running >/dev/null 2>&1; then
      log "OK: RabbitMQ broker healthy in '$RABBIT_CONTAINER'"
      return
    fi
    die "RabbitMQ in '$RABBIT_CONTAINER' failed rabbitmq-diagnostics check_running"
  fi
  log "WARN: container '$RABBIT_CONTAINER' not running; relying on TCP check only"
}

check_pubsub_emulator() {
  if ! curl -fsS "${PUBSUB_API_BASE}/topics" -H "Content-Type: application/json" >/dev/null 2>&1; then
    die "Cannot reach Pub/Sub emulator at ${PUBSUB_HOST}:${PUBSUB_PORT} (project ${PUBSUB_PROJECT}).
  Start infra and bootstrap topics first, e.g.:
  cd $ACCEPTANCE_HARNESS_DIR && ./start-infra.sh && FWMT_MESSAGING=pubsub ./setup-messaging.sh"
  fi
  log "OK: Pub/Sub emulator ${PUBSUB_HOST}:${PUBSUB_PORT} (project ${PUBSUB_PROJECT})"
}

check_broker() {
  if [[ "$MESSAGING" == "pubsub" ]]; then
    check_pubsub_emulator
  else
    check_rabbit_tcp
    check_rabbit_docker
  fi
}

check_job_health() {
  [[ "$SKIP_HEALTH" == true ]] && return
  [[ -z "$JOB_PORT" ]] && return
  if curl -sf -u user:password "http://localhost:${JOB_PORT}/swagger-ui.html" >/dev/null 2>&1; then
    log "OK: Job service responding on port $JOB_PORT"
  elif curl -sf "http://localhost:${JOB_PORT}/actuator/health" >/dev/null 2>&1; then
    log "OK: Job service /actuator/health on port $JOB_PORT"
  elif curl -sf "http://localhost:${JOB_PORT}/health" >/dev/null 2>&1; then
    log "OK: Job service /health on port $JOB_PORT"
  else
    die "Job service HTTP check failed on localhost:${JOB_PORT}"
  fi
}

preflight_docker() {
  log "Preflight: Docker mode (messaging: $MESSAGING)..."
  [[ "$MESSAGING" == "rabbit" ]] && require_container "$RABBIT_CONTAINER"
  require_container "$JOB_CONTAINER"
  check_broker
  check_job_health
}

preflight_local() {
  log "Preflight: local Spring Boot mode (messaging: $MESSAGING)..."
  check_broker
  check_job_health
  if [[ ! -f "$JOB_LOG_FILE" ]]; then
    die "Job log not found: $JOB_LOG_FILE — start services first, e.g.:
  cd $ACCEPTANCE_HARNESS_DIR
  ./start-infra.sh
  ./start-services.sh job-service tm-mock"
  fi
  log "OK: job log file $JOB_LOG_FILE"
}

purge_queues() {
  log "Purging queues: $QUEUE_NAME, $DLQ_NAME"
  QUEUE_NAME="$QUEUE_NAME" DLQ_NAME="$DLQ_NAME" \
  RABBITMQ_HOST="$RABBIT_HOST" RABBITMQ_PORT="$RABBIT_PORT" \
  RABBITMQ_USERNAME="$RABBIT_USER" RABBITMQ_PASSWORD="$RABBIT_PASSWORD" \
  RABBITMQ_VHOST="$RABBIT_VHOST" \
  "$PYTHON" - <<'PY'
import os
import pika

host = os.environ["RABBITMQ_HOST"]
port = int(os.environ.get("RABBITMQ_PORT", "5672"))
user = os.environ.get("RABBITMQ_USERNAME", "guest")
password = os.environ.get("RABBITMQ_PASSWORD", "guest")
vhost = os.environ.get("RABBITMQ_VHOST", "/")
queues = [os.environ["QUEUE_NAME"], os.environ["DLQ_NAME"]]

creds = pika.PlainCredentials(user, password)
params = pika.ConnectionParameters(
    host=host, port=port, virtual_host=vhost, credentials=creds
)
conn = pika.BlockingConnection(params)
ch = conn.channel()
for q in queues:
    try:
        ch.queue_purge(q)
        print(f"Purged {q}")
    except Exception as exc:
        print(f"WARN: could not purge {q}: {exc}")
conn.close()
PY
}

drain_pubsub() {
  log "Draining Pub/Sub subscription: $PUBSUB_DRAIN_SUB"
  local sub_url="${PUBSUB_API_BASE}/subscriptions/${PUBSUB_DRAIN_SUB}"
  local pulled=0
  while true; do
    local response
    response="$(curl -fsS -X POST "${sub_url}:pull" \
      -H "Content-Type: application/json" \
      -d '{"maxMessages":500,"returnImmediately":true}' 2>/dev/null || true)"
    if [[ -z "$response" || "$response" != *"ackId"* ]]; then
      break
    fi
    local ack_ids
    ack_ids="$(printf '%s' "$response" \
      | grep -o '"ackId"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | sed 's/.*"\([^"]*\)"$/\1/')"
    [[ -z "$ack_ids" ]] && break
    local json_ids
    json_ids="$(printf '%s' "$ack_ids" | awk 'BEGIN{ORS=""} {printf "%s\"%s\"", (NR>1?",":""), $0}')"
    curl -fsS -X POST "${sub_url}:acknowledge" \
      -H "Content-Type: application/json" \
      -d "{\"ackIds\":[${json_ids}]}" >/dev/null 2>&1 || true
    pulled=$(( pulled + $(printf '%s\n' "$ack_ids" | grep -c . ) ))
  done
  log "Drained $pulled message(s) from $PUBSUB_DRAIN_SUB"
}

purge_messaging() {
  if [[ "$MESSAGING" == "pubsub" ]]; then
    drain_pubsub
  else
    purge_queues
  fi
}

build_jobservice_file() {
  local pattern="$1"
  # Bash 3.2 (macOS): "cmd | python - <<'PY'" feeds the heredoc to python, not cmd output.
  # Use -c with stdin from the pipe instead.
  grep "$pattern" "$RAW_LOG_FILE" | "$PYTHON" -c '
import re
import sys

# Prefer Spring log prefix (local JVM time) over JSON localTime (UTC) for testFiles.py
pat_log_time = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})")
pat_json_time = re.compile(r"\"localTime\":\"([^\"]+)\"")
pat_case = re.compile(r"\"caseId\":\"([^\"]+)\"")

def to_testfiles_time(line: str) -> str:
    m_log = pat_log_time.search(line)
    if m_log:
        # 2026-05-22 11:03:31.990 -> 11:03:31.990
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
}

LOG_PID=""
LOG_GROUP_PID=""

cleanup() {
  # Bash 3.2 quirks (macOS /bin/bash):
  #   1. `$!` after `cmd1 | cmd2 &` returns the LAST PID (tee), not the first (tail).
  #   2. `wait $!` on a backgrounded pipeline blocks until the WHOLE pipeline ends,
  #      so a `tail -F` that never gets SIGPIPE wedges the script forever.
  # Fix: wrap the pipeline in its own subshell, capture that subshell's PID, and
  # kill the entire process group. Don't `wait` on it.
  if [[ -n "$LOG_GROUP_PID" ]]; then
    kill -- "-${LOG_GROUP_PID}" 2>/dev/null || true
    kill "$LOG_GROUP_PID" 2>/dev/null || true
  fi
  if [[ -n "$LOG_PID" ]]; then
    kill "$LOG_PID" 2>/dev/null || true
  fi
  pkill -P $$ -x tail 2>/dev/null || true
  pkill -P $$ -x tee  2>/dev/null || true
}

trap cleanup EXIT INT TERM

start_log_capture() {
  rm -f "$RAW_LOG_FILE"
  if [[ "$MODE" == "docker" ]]; then
    log "Tailing docker logs from '$JOB_CONTAINER' (pattern: $LOG_EVENT_PATTERN)..."
    ( set -m; docker logs -f "$JOB_CONTAINER" 2>&1 | tee "$RAW_LOG_FILE" ) &
  else
    log "Tailing log file '$JOB_LOG_FILE' (pattern: $LOG_EVENT_PATTERN)..."
    ( set -m; tail -n 0 -F "$JOB_LOG_FILE" 2>/dev/null | tee "$RAW_LOG_FILE" ) &
  fi
  LOG_GROUP_PID=$!
  LOG_PID=$LOG_GROUP_PID
}

# --- Preflight ---
if [[ "$MODE" == "local" ]]; then
  preflight_local
else
  preflight_docker
fi

if [[ "$MESSAGING" == "rabbit" ]]; then
  if ! "$PYTHON" -c "import pika" 2>/dev/null; then
    die "Python package 'pika' not installed (pip install pika, or pipenv install in $SCRIPT_DIR)"
  fi
  log "OK: $PYTHON with pika"
else
  log "OK: $PYTHON (pubsub publisher uses stdlib urllib)"
fi

# --- Scenario ---
case "$SCENARIO" in
  create)
    PUBLISH_SCRIPT="publish_create.py"
    LOG_EVENT_PATTERN="${LOG_EVENT_PATTERN:-RM_CREATE_REQUEST_RECEIVED}"
    ;;
  cancel)
    PUBLISH_SCRIPT="publish_cancel.py"
    LOG_EVENT_PATTERN="${LOG_EVENT_PATTERN:-RM_CANCEL_REQUEST_RECEIVED}"
    ;;
  update)
    PUBLISH_SCRIPT="publish_update.py"
    LOG_EVENT_PATTERN="${LOG_EVENT_PATTERN:-RM_UPDATE_REQUEST_RECEIVED}"
    ;;
  *)
    die "Unknown scenario '$SCENARIO' (use create|cancel|update)"
    ;;
esac

[[ -f "$PUBLISH_SCRIPT" ]] || die "Missing $PUBLISH_SCRIPT"

if [[ "$PURGE" == true ]]; then
  purge_messaging
fi

rm -f "$MESSAGE_PUBLISH_FILE" "$JOBSERVICE_FILE"
log "Cleared artefact files"

start_log_capture

# --- Publish ---
log "Publishing $COUNT message(s) via $PUBLISH_SCRIPT (messaging: $MESSAGING)..."
export CASES_TO_FETCH="$COUNT"
export FWMT_MESSAGING="$MESSAGING"
export RABBITMQ_HOST="$RABBIT_HOST"
export RABBITMQ_PORT="$RABBIT_PORT"
export RABBITMQ_USERNAME="$RABBIT_USER"
export RABBITMQ_PASSWORD="$RABBIT_PASSWORD"
export RABBITMQ_VHOST="$RABBIT_VHOST"
export RABBIT_QUEUENAME="$QUEUE_NAME"
export FWMT_PUBSUB_HOST="$PUBSUB_HOST"
export FWMT_PUBSUB_EMULATOR_PORT="$PUBSUB_PORT"
export FWMT_PUBSUB_PROJECT="$PUBSUB_PROJECT"
export FWMT_PUBSUB_TOPIC="$PUBSUB_TOPIC"

"$PYTHON" "$PUBLISH_SCRIPT"
log "Publish finished"

# --- Wait for consumption ---
log "Waiting for $COUNT x '$LOG_EVENT_PATTERN' (timeout ${WAIT_TIMEOUT_SEC}s)..."
deadline=$(( $(date +%s) + WAIT_TIMEOUT_SEC ))
received=0
while [[ $(date +%s) -lt $deadline ]]; do
  received=$(grep -c "$LOG_EVENT_PATTERN" "$RAW_LOG_FILE" 2>/dev/null || true)
  received="${received:-0}"
  if [[ "$received" -ge "$COUNT" ]]; then
    log "OK: saw $received matching log line(s)"
    break
  fi
  sleep "$POLL_INTERVAL_SEC"
done

if [[ "$received" -lt "$COUNT" ]]; then
  log "WARN: only $received / $COUNT events after timeout; continuing"
fi

cleanup
LOG_PID=""
LOG_GROUP_PID=""
trap - EXIT INT TERM

# --- Build jobservice.txt for testFiles.py ---
log "Building $JOBSERVICE_FILE..."
build_jobservice_file "$LOG_EVENT_PATTERN"
lines=$(wc -l < "$JOBSERVICE_FILE" | tr -d ' ')
log "jobservice.txt: $lines line(s)"

if [[ "$SKIP_REPORT" == true ]]; then
  log "Skipping testFiles.py (--skip-report)"
  exit 0
fi

if [[ ! -f "$MESSAGE_PUBLISH_FILE" ]]; then
  if [[ "$SCENARIO" == "create" ]]; then
    die "Missing $MESSAGE_PUBLISH_FILE (publish_create.py should create it)"
  fi
  log "WARN: no Message_publish.txt for scenario $SCENARIO; skipping testFiles.py"
  exit 0
fi

log "Running testFiles.py..."
"$PYTHON" testFiles.py
log "Done."
