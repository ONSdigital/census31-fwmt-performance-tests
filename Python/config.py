import os


class Config:
    # Messaging backend selector: rabbit (default) or pubsub.
    FWMT_MESSAGING = os.getenv('FWMT_MESSAGING', 'rabbit').lower()

    RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'localhost')
    RABBITMQ_PORT = os.getenv('RABBITMQ_PORT', '5672')
    RABBITMQ_VHOST = os.getenv('RABBITMQ_VHOST', '/')
    RABBITMQ_EXCHANGE = os.getenv('RABBITMQ_EXCHANGE', 'adapter-outbound-exchange')
    RABBITMQ_USER = os.getenv('RABBITMQ_USERNAME', 'guest')
    RABBITMQ_PASSWORD = os.getenv('RABBITMQ_PASSWORD', 'guest')
    RABBITMQ_QUEUENAME = os.getenv('RABBIT_QUEUENAME', 'RM.Field')

    # Pub/Sub emulator (mirrors census31-fwmt-acceptance-tests/scripts/setup-pubsub.sh).
    PUBSUB_HOST = os.getenv('FWMT_PUBSUB_HOST', 'localhost')
    PUBSUB_PORT = os.getenv('FWMT_PUBSUB_EMULATOR_PORT', '8085')
    PUBSUB_PROJECT = os.getenv('FWMT_PUBSUB_PROJECT', 'fwmt-local')
    # Topic carries the same name as the Rabbit queue (RM.Field) on the emulator.
    PUBSUB_TOPIC = os.getenv('FWMT_PUBSUB_TOPIC', os.getenv('RABBIT_QUEUENAME', 'RM.Field'))

    CASES_TO_FETCH = os.getenv("CASES_TO_FETCH", "10")
    UPDATE_CASES_TO_FETCH = os.getenv("UPDATE_CASES_TO_FETCH", "20")
    OUTCOME_CASES_TO_FECTH = os.getenv("OUTCOME_CASES_TO_FECTH", "1000")
    TMMOCK_API_URL = os.getenv("tm-base-url", "http://localhost:8000/cases/")


def rabbit_connection_parameters():
    """AMQP connection for publish scripts (honours RABBITMQ_PORT, e.g. 5674 local harness)."""
    import pika
    return pika.ConnectionParameters(
        host=Config.RABBITMQ_HOST,
        port=int(Config.RABBITMQ_PORT),
        virtual_host=Config.RABBITMQ_VHOST,
        credentials=pika.PlainCredentials(Config.RABBITMQ_USER, Config.RABBITMQ_PASSWORD),
    )


def pubsub_api_base():
    """Base URL for the Pub/Sub emulator REST API for the configured project."""
    return "http://{host}:{port}/v1/projects/{project}".format(
        host=Config.PUBSUB_HOST,
        port=Config.PUBSUB_PORT,
        project=Config.PUBSUB_PROJECT,
    )
