from datetime import datetime, date, time

def check(caseId):
    with open('jobservice.txt', 'r') as f:
        datafile = f.readlines()
        for line in datafile:
            if caseId in line:
                return line


map_publish_values = {}
total_response_time = 0.0

with open('Message_publish.txt', 'r') as msg_reader:
    for line in msg_reader:
        publish_values = line.split('|')
        key = publish_values[0].strip()
        value = publish_values[1].strip()
        map_publish_values[key] = value

print (' {:2} {:5} {:20} '.format('|','--------------------------------------------------------------------------------------------------------------------------------------------------------------','|'))
print (' {:10} {:50} {:20} {:36} {:20} {:10} {:3} {:20} '.format('|','CASE ID','-','PUBLISH TIME(s)','-','RESPONSE TIME(s)','','|'))
print (' {:2} {:5} {:20} '.format('|','--------------------------------------------------------------------------------------------------------------------------------------------------------------','|'))
totalValues = len(map_publish_values)
keyIndex = 0
total_start_time = 0
total_end_time = 0
not_found_caseids = 0
not_found_caseids_list = []

for key in map_publish_values.keys():

    result = check(key)
    if(result):
        size = len(result)
        value_print = result[0:12]
        # These 2 steps are to convert time string into timestamp 
        message_created_time = datetime.strptime(result[0:12], '%H:%M:%S.%f').time() 
        created_time = datetime.combine(date.today(), message_created_time).timestamp() * 1000
        value_publish = map_publish_values[key]
        pred_data = {'RA':value_publish[11:]}
        RA_2 = datetime.strptime(pred_data['RA'], '%H:%M:%S.%f').time()
        if( (keyIndex - not_found_caseids) == 0):
            total_start_time = (datetime.combine(date.today(), RA_2)).timestamp() * 1000
        message_publish_time = datetime.combine(date.today(), RA_2).timestamp() * 1000
        diff = created_time - message_publish_time
        total_response_time = total_response_time + diff
        print (' {:10} {:50} {:20} {:2} {:20} {:20} {:.3f} {:15}{:20} '.format('|',key,'-',value_publish[11:],'s','-',diff/1000,'s','|'))
    else:
        not_found_caseids = not_found_caseids + 1
        not_found_caseids_list.append(key)

    keyIndex = keyIndex + 1

response_time = created_time - total_start_time
total_records = totalValues - not_found_caseids




if(total_response_time != 0):
    print (' {:2} {:5} {:20} '.format('|','---------------------------------------------------------------------------------------------------------------------------------------------------------------','|'))
    print('\n Total processing time for %d number of requests is %.3fs.' % (total_records, response_time/1000))
    print('\n Average processing time for %d number of requests is %.3fms  / %.3fs.' % (total_records, (total_response_time/len(map_publish_values)), (total_response_time/len(map_publish_values))/1000) )
    print('\n Number of requests per second are %d.' % round((total_records/(response_time/1000)),0))
else:
    print('\n No Records Found')

for case in not_found_caseids_list:    
    print(case)
