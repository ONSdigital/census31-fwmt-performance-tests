import pika
from datetime import datetime
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
    for i in range(num_of_cases_to_fetch):
        data["caseId"] = str(uuid.uuid4())
        message = json.dumps(data)  

        props = pika.BasicProperties(content_type='application/json', headers = { '__TypeId__':'uk.gov.ons.census.fwmt.common.rm.dto.FwmtActionInstruction',
                'content_type':'application/json'}) 
                                    #             '__TypeId__':'uk.gov.ons.census.fwmt.common.rm.dto.FwmtActionInstruction'}})
        channel.basic_publish(exchange='', routing_key=cfg.RABBITMQ_QUEUENAME, body=message, properties = props) 

    
        canceldata = data;
        canceldata['actionInstruction'] = 'CANCEL';
        
        cancelprops = pika.BasicProperties(content_type='application/json', headers = { '__TypeId__':'uk.gov.ons.census.fwmt.common.rm.dto.FwmtCancelActionInstruction',
            'content_type':'application/json'}) 
        cancelmessage = json.dumps(canceldata)
        watch = StopWatch()
        watch.start()
        channel.basic_publish(exchange='', routing_key=cfg.RABBITMQ_QUEUENAME, body=cancelmessage, properties = cancelprops) 
        watch.stop()
        response_time=watch.elapsed_time()
        current_time=datetime.now()
            
            #print ('Sent data with CaseId {} to RabbitMQ with Response_time of {:.3f}ms'.format(data['caseId'],response_time))
            #print (' {:10} {:50} {:20} {:.3f}ms {:10} {:20} '.format('|',data['caseId'],'-',response_time,'ms',current_time ,'|'))
        print (' {:10} {:50} {:20} {:%Y-%m-%d %H:%M:%S} {:10} {:20} '.format('|',data['caseId'],'-',current_time,'s','|'))

    connection.close()  



if __name__ == '__main__':
    get_createcases()