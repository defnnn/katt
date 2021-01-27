vendor:
	helm repo add traefik https://helm.traefik.io/traefik --force-update
	helm repo update
	helm template traefik/traefik | sed 's#RELEASE-NAME-traefik#traefik#g' > traefik.yaml.vendor
	rm -rf traefik-helm-chart crds
	git clone -b v9.13.0 https://github.com/traefik/traefik-helm-chart
	mv traefik-helm-chart/traefik/crds .
	rm -rf traefik-helm-chart
