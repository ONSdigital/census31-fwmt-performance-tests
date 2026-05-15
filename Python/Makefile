
python :
	kubectl logs -f $$(kubectl get pods --selector=app=fwmtgatewayjobsvcv4-test -o jsonpath='{.items[*].metadata.name}') >> testFiles.txt  &
	kubectl exec -it $$(kubectl get pods --selector=app=fwmtg-perf-tools -o jsonpath='{.items[*].metadata.name}') -- python publish_create.py


consume : 
	cat testFiles.txt| grep 'RECEIVED' | awk '{print $$2 ,substr($$25,31,36)}' >> jobservice.txt
	kubectl cp jobservice.txt $$(kubectl get pods --selector=app=fwmtg-perf-tools -o jsonpath='{.items[*].metadata.name}'):/queloader/

report :
	kubectl exec -it $$(kubectl get pods --selector=app=fwmtg-perf-tools -o jsonpath='{.items[*].metadata.name}') -- python testFiles.py

clean :
	kubectl exec -it $$(kubectl get pods --selector=app=fwmtg-perf-tools -o jsonpath='{.items[*].metadata.name}') -- rm -f Message_publish.txt jobservice.txt
	rm -f testFiles.txt jobservice.txt
	pkill 'kubectl logs -f $$(kubectl get pods --selector=app=fwmtgatewayjobsvcv4-test -o jsonpath='{.items[*].metadata.name}') >> testFiles.txt  & ' 