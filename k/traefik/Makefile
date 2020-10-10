vendor:
	helm repo add traefik https://helm.traefik.io/traefik
	helm repo update
	helm template traefik/traefik | sed 's#RELEASE-NAME-traefik#traefik#g' > traefik.yaml.vendor
	rm -rf traefik-helm-chart
	gh repo clone traefik/traefik-helm-chart
	rm -rf crds
	mv traefik-helm-chart/traefik/crds .
	rm -rf traefik-helm-chart
