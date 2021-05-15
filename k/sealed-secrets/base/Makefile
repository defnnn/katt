sealed-secrets.yaml: clean/sealed-secrets.yaml
	kustomize build clean > $@

clean/sealed-secrets.yaml:
	curl -sSL https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/controller.yaml > $@

diff: sealed-secrets.yaml clean/sealed-secrets.yaml
	kustomize build . > diff.yaml
	diff sealed-secrets.yaml diff.yaml
	rm -f diff.yaml
