cert-manager.yaml: clean/cert-manager.yaml
	kustomize build clean > $@

clean/cert-manager.yaml:
	curl -sSL https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml > $@

diff: cert-manager.yaml clean/cert-manager.yaml
	kustomize build . > diff.yaml
	diff cert-manager.yaml diff.yaml
	rm -f diff.yaml
