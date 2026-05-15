import pika
from datetime import datetime
import time
import requests
import uuid
import json  
#import psycopg2
from config import Config as cfg

credentials = pika.PlainCredentials(cfg.RABBITMQ_USER, cfg.RABBITMQ_PASSWORD)
connection = pika.BlockingConnection(pika.ConnectionParameters(host=cfg.RABBITMQ_HOST, credentials=credentials))
channel = connection.channel() 
#channel.queue_declare(queue=cfg.RABBITMQ_QUEUENAME) 

CREATE_DATA= {
    "blankFormReturned": "null",
    "latitude": 51.497421,
    "handDeliver": "true",
    "actionInstruction": "CREATE",
    "ce1Complete": "false",
    "estabType": "GRT",
    "fieldCoordinatorId": "SH-TWH1-ZJ",
    "caseRef": "12345678",
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

createcaseIds = []
updatecaseIds = []

class StopWatch():
    def start(self):
        self._start = datetime.now()

    def stop(self):
        self._end = datetime.now()

    def elapsed_time(self):
        timedelta = self._end - self._start
        return timedelta.total_seconds() * 1000

def get_updatecases(num_of_cases_to_fetch=int(cfg.CASES_TO_FETCH)):
    json_str = json.dumps(CREATE_DATA)
    print('{:2}{:5}'.format('','----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'))
    print (' {:10} {:50} {:20} {:10} {:11} {:25}{:20} {:20} {:20} {:20} '.format('|','CASE ID','-','QUEUE PUBLISH TIME','(s)','-','RESPONSE CODE' , '-', 'TM MOCK RESPONSE TIME','|'))
    print('{:2}{:5}'.format('','----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'))
    for i in range(num_of_cases_to_fetch):
        data = json.loads(json_str)
        data["caseId"] = str(uuid.uuid4())
        message = json.dumps(data)  

        props = pika.BasicProperties(content_type='application/json', headers = { '__TypeId__':'uk.gov.ons.census.fwmt.common.rm.dto.FwmtActionInstruction',
                'content_type':'application/json'}) 
                                    #             '__TypeId__':'uk.gov.ons.census.fwmt.common.rm.dto.FwmtActionInstruction'}})
        channel.basic_publish(exchange='', routing_key=cfg.RABBITMQ_QUEUENAME, body=message, properties = props) 
        createcaseIds.append(data)
    
    
        updatedata = data;
        updatedata['actionInstruction'] = 'UPDATE';
        updatedata['addressLine3'] = 'addressLine3-' + str(i);

        updatemessage = json.dumps(updatedata)
        watch = StopWatch()
        watch.start()
        channel.basic_publish(exchange='', routing_key=cfg.RABBITMQ_QUEUENAME, body=updatemessage, properties = props) 
        watch.stop()
        response_time=watch.elapsed_time()
        current_time=datetime.now()
        updatecaseIds.append(data['caseId'])    
            #print ('Sent data with CaseId {} to RabbitMQ with Response_time of {:.3f}ms'.format(data['caseId'],response_time))
            #print (' {:10} {:50} {:20} {:.3f}ms {:10} {:20} '.format('|',data['caseId'],'-',response_time,'ms',current_time ,'|'))
        time.sleep(1)
        responseTmTime = get_tmmock(data['caseId'])
        print (' {:10} {:50} {:20} {:%Y-%m-%d %H:%M:%S} {:10} {:10} {:2} {:20} {:20}'.format('|',data['caseId'],'-',current_time,'s','-',responseTmTime,'s','|'))
    
    print('{:2}{:5}'.format('','---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'))
    connection.close()  

def get_tmmock(caseId):
    uri = "http://fwmtgatewaytmmock:8000/cases/" + str(caseId)
    responseTm = requests.get(uri)
    msg = '{:15}{:22}{:20}'.format(responseTm.status_code, '-', responseTm.elapsed.total_seconds())
    return msg


if __name__ == '__main__':
    get_updatecases()