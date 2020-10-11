vendor:
	helm repo add external-secrets https://godaddy.github.io/kubernetes-external-secrets/
	helm repo update
	helm template external-secrets/kubernetes-external-secrets | sed 's#RELEASE-NAME-kubernetes-external-secrets#external-secrets#g' > external-secrets.yaml.vendor
