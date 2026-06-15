> **THIS REPO IS SEEDED FROM 2021 CODE AND AS SUCH CURRENTLY NEEDS MODERNISATION!** (see also [SEEDING.md](SEEDING.md).)


# FWMT Performance Test Rig

## Description

`census31-fwmt-performance-tests` is split into:

1. **FWMTG-perf-tests** — Python programs to publish messages to the **RM.Field** Pub/Sub topic (local emulator) and track consumption by job-service.
2. **fwmtg-locust** — Locust deployment to simulate load on outcome-service (HTTP: TM → outcome-service → Pub/Sub preprocessing topic).

### Python scripts

| Script | Purpose |
|--------|---------|
| `publish_create.py` | Generate and publish `Create` messages |
| `publish_cancel.py` | `Create` then `Cancel` |
| `publish_update.py` | `Create` then `Update` |
| `testFiles.py` | Compare publish vs consumption timestamps and report rate |
| `run-jobservice-perf.sh` | Orchestrate preflight, optional drain, publish, log scrape, report |

## Typical flow — local Job Service perf

One-time setup (stdlib only for publishing; optional `pipenv install` for `requests` / `psycopg2-binary`):

```bash
cd census31-fwmt-performance-tests/Python
pipenv install   # optional
```

Service startup lives in **`census31-fwmt-acceptance-tests/scripts/`**.

| Step | Command |
|------|---------|
| 1. Start infra | `cd census31-fwmt-acceptance-tests/scripts` then `./start-infra.sh` |
| 2. Bootstrap Pub/Sub | `./setup-messaging.sh` |
| 3. Start apps | `./start-services.sh --build-missing job-service tm-mock` |
| 4. Confirm job-service | `curl -fsS -u user:password http://localhost:8025/swagger-ui.html` |
| 5. Run perf | `cd census31-fwmt-performance-tests/Python` then `./run-jobservice-perf.sh --local --count 100 --scenario create --purge` |

Publishes to topic **RM.Field** on the Pub/Sub emulator (**localhost:8085** by default). Tails **`census31-fwmt-acceptance-tests/scripts/logs/job-service.log`**.

### Perf script options

```bash
./run-jobservice-perf.sh --help

./run-jobservice-perf.sh --count 500 --scenario create --purge
./run-jobservice-perf.sh --local --count 500 --scenario cancel --purge
./run-jobservice-perf.sh --local --job-log /path/to/job-service.log
./run-jobservice-perf.sh --skip-report --count 10    # publish + wait only
```

What the script does: preflight (emulator + job-service health) → optional drain of `job-service-RM-Field` subscription → publish → wait for `RM_*_REQUEST_RECEIVED` in logs → build `jobservice.txt` → run `testFiles.py` (create scenario writes `Message_publish.txt`).

Relevant env vars: `FWMT_PUBSUB_HOST`, `FWMT_PUBSUB_EMULATOR_PORT` (default `8085`), `FWMT_PUBSUB_PROJECT` (default `fwmt-local`), `FWMT_PUBSUB_TOPIC` (default `RM.Field`), `FWMT_PUBSUB_DRAIN_SUB` (default `job-service-RM-Field`).

### Stop / reset

```bash
cd census31-fwmt-acceptance-tests/scripts
./stop-services.sh job-service tm-mock
./drop-infra.sh
```

## GCP deployment (legacy)

Dockerfile and `create-perftests-pod.yml` are in `Python/`. Update `config.py` env vars for your Pub/Sub project before running in-cluster.

## fwmtg-locust

Locust tests simulating TM outcomes over HTTP (no messaging client changes in FMT-47).

### Run locally

1. Build the docker image using `fwmtg-locust/docker/Dockerfile`.
2. `docker run` the locust image.
3. Execute `locust -f load_test.py --no-web -t 10s`

Expected results (example): in a 60s test, ~11k requests at ~257 req/s to `POST /spgOutcome`.
