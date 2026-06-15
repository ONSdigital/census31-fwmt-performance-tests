import os


class Config:
    # Pub/Sub emulator (mirrors census31-fwmt-acceptance-tests/scripts/setup-pubsub.sh).
    PUBSUB_HOST = os.getenv('FWMT_PUBSUB_HOST', 'localhost')
    PUBSUB_PORT = os.getenv('FWMT_PUBSUB_EMULATOR_PORT', '8085')
    PUBSUB_PROJECT = os.getenv('FWMT_PUBSUB_PROJECT', 'fwmt-local')
    PUBSUB_TOPIC = os.getenv('FWMT_PUBSUB_TOPIC', 'RM.Field')

    CASES_TO_FETCH = os.getenv("CASES_TO_FETCH", "10")
    UPDATE_CASES_TO_FETCH = os.getenv("UPDATE_CASES_TO_FETCH", "20")
    OUTCOME_CASES_TO_FECTH = os.getenv("OUTCOME_CASES_TO_FECTH", "1000")
    TMMOCK_API_URL = os.getenv("tm-base-url", "http://localhost:8000/cases/")


def pubsub_api_base():
    """Base URL for the Pub/Sub emulator REST API for the configured project."""
    return "http://{host}:{port}/v1/projects/{project}".format(
        host=Config.PUBSUB_HOST,
        port=Config.PUBSUB_PORT,
        project=Config.PUBSUB_PROJECT,
    )
