traefik.yaml: clean/traefik.yaml
	kustomize build clean > $@

clean/traefik.yaml:
	-helm repo add traefik https://helm.traefik.io/traefik
	helm repo update
	helm template traefik traefik/traefik --namespace=traefik --values=values.yaml > $@

diff: traefik.yaml clean/traefik.yaml
	kustomize build . > diff.yaml
	diff traefik.yaml diff.yaml
	rm -f diff.yaml
