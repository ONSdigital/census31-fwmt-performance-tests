import os

import pika


class Config:
    RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'localhost')
    RABBITMQ_PORT = os.getenv('RABBITMQ_PORT', '5672')
    RABBITMQ_VHOST = os.getenv('RABBITMQ_VHOST', '/')
    RABBITMQ_EXCHANGE = os.getenv('RABBITMQ_EXCHANGE', 'adapter-outbound-exchange')
    RABBITMQ_USER = os.getenv('RABBITMQ_USERNAME', 'guest')
    RABBITMQ_PASSWORD = os.getenv('RABBITMQ_PASSWORD', 'guest')
    RABBITMQ_QUEUENAME= os.getenv('RABBIT_QUEUENAME', 'RM.Field')
    CASES_TO_FETCH = os.getenv("CASES_TO_FETCH", "10")
    UPDATE_CASES_TO_FETCH = os.getenv("UPDATE_CASES_TO_FETCH", "20")
    OUTCOME_CASES_TO_FECTH = os.getenv("OUTCOME_CASES_TO_FECTH", "1000")
    TMMOCK_API_URL = os.getenv("tm-base-url", "http://localhost:8000/cases/")


def rabbit_connection_parameters():
    """AMQP connection for publish scripts (honours RABBITMQ_PORT, e.g. 5674 local harness)."""
    return pika.ConnectionParameters(
        host=Config.RABBITMQ_HOST,
        port=int(Config.RABBITMQ_PORT),
        virtual_host=Config.RABBITMQ_VHOST,
        credentials=pika.PlainCredentials(Config.RABBITMQ_USER, Config.RABBITMQ_PASSWORD),
    )
