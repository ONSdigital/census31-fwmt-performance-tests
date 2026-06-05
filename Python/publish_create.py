from datetime import datetime
import time
import uuid
import json
from config import Config as cfg
from publisher import get_publisher, TYPE_ID_CREATE

CREATE_DATA= {
    "blankFormReturned": "null",
    "latitude": 51.497421,
    "handDeliver": "true",
    "actionInstruction": "CREATE",
    "ce1Complete": "false",
    "estabType": "GRT",
    "fieldCoordinatorId": "SH-TWH1-ZJ",
    "caseRef": "GWPERF_12345678",
    "oa": "E00167164",
    "estabUprn": "6123456",
    "surveyName": "CENSUS",
    "undeliveredAsAddress": "false",
    "caseId": "8325a88d-9ecd-43f3-87f0-81e944efd0bc",
    "addressLine1": "Flat 20RAHD",
    "addressLine2": "Fairlead House",
    "addressLine3": "Cassilis Road",
    "addressLevel": "U",
    "longitude": -0.0222139,
    "uprn": "6031151",
    "townName": "London",
    "secureEstablishment": "false",
    "addressType": "SPG",
    "fieldOfficerId": "SH-TWH1-ZJ-05",
    "postcode": "E14 9LB",
    "ceActualResponses": 0,
    "organisationName": "",
    "ceExpectedCapacity": "null"
    }

class StopWatch():
    def start(self):
        self._start = datetime.now()

    def stop(self):
        self._end = datetime.now()

    def elapsed_time(self):
        timedelta = self._end - self._start
        return timedelta.total_seconds() * 1000

def get_createcases(num_of_cases_to_fetch=int(cfg.CASES_TO_FETCH)):
    json_str = json.dumps(CREATE_DATA)

    data = json.loads(json_str)
    current_milli_time = int(round(time.time() * 1000))
    publisher = get_publisher()
    f = open("Message_publish.txt", "a")
    try:
        for i in range(num_of_cases_to_fetch):
            data["caseId"] = str(uuid.uuid4())
            data["caseRef"] = "GWPERF_"+ str(uuid.uuid4())[:30]
            message = json.dumps(data)
            watch = StopWatch()
            watch.start()
            create_time=datetime.now()
            publisher.publish(TYPE_ID_CREATE, message, timestamp_ms=current_milli_time)
            watch.stop()
            response_time=watch.elapsed_time()
            f.write('{:50} {:10} {:%Y-%m-%d %H:%M:%S.%f} \n'.format(data['caseId'],'|',create_time))
        time.sleep(10)
    finally:
        f.close()
        publisher.close()


if __name__ == '__main__':
    get_createcases()
