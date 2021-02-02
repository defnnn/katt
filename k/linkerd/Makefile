vendor:
	helm repo add linkerd https://helm.linkerd.io/stable --force-update
	helm repo update
	linkerd install | perl -pe 's{enforced-host=.*}{enforced-host=-}' > vendor.yaml
