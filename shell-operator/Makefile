build:
	docker build -t defn/home:shell-operator .

push:
	docker push defn/home:shell-operator

rbac:
	k create namespace example-monitor-pods
	kn example-monitor-pods create serviceaccount monitor-pods-acc
	k create clusterrole monitor-pods --verb=get,watch,list --resource=pods
	k create clusterrolebinding monitor-pods --clusterrole=monitor-pods --serviceaccount=example-monitor-pods:monitor-pods-acc

deploy:
	kn example-monitor-pods  apply -f shell-operator.yaml
