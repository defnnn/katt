vendor:
	helm repo add traefik https://helm.traefik.io/traefik --force-update
	helm repo update
	rm -rf traefik-helm-chart crds
	helm template traefik/traefik | sed 's#RELEASE-NAME-##' > vendor.yaml
	git clone -b v9.13.0 https://github.com/traefik/traefik-helm-chart
	mv traefik-helm-chart/traefik/crds crds
	rm -rf traefik-helm-chart
