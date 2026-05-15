import os
import time
import uuid
import logging
from locust import HttpLocust, TaskSet, task

logger = logging.getLogger(__name__)
logger.setLevel(os.getenv("LOCUST_LOG_LEVEL", "INFO").upper())

datas = """
    {"transactionId":"e664473d-9a24-4218-8739-a7d7ef3a1b11","eventDate":"2020-04-14T15:25:17.000+0000","officerId":"SW-CGN1-ZA-25","coordinatorId":"SW-CGN1-ZA","primaryOutcomeDescription":"Access Granted - No contact","secondaryOutcomeDescription":"Resident is out","outcomeCode":"10-30-03","address":{"addressLine1":"77 Bea way","addressLine2":null,"addressLine3":null,"locality":"Park Gate","postcode":"SO31 7GL","latitude":50.8742751084436,"longitude":-1.27286911010742},"accessInfo":null,"careCodes":null,"fulfilmentRequests":null,"dummyInfoCollected":true,"ceDetails":null}
     """
header = {"authorization": "Basic dXNlcjpwYXNzd29yZA==","Content-type": "application/json"}

class OutcomeTaskSet(TaskSet):

    @task
    def put_tests(self):
        caseId = uuid.uuid4()

        response = self.client.post("http://34.105.175.176:8030/spgOutcome/"+str(caseId), datas, headers = header,name="/spgOutcome")


class OutcomeLoadTester(HttpLocust):
    host = 'http://34.105.175.176:8030'
    task_set = OutcomeTaskSet