accessLog: {}

log: {
	level:  "DEBUG"
	format: "json"
}

api: dashboard: "true"

ping: "true"

providers: kubernetesCRD: {}

providers: kubernetesIngress: {
	ingressClass: "traefik"
	ingressEndpoint:
		publishedService: "traefik/traefik"
}

entryPoints: {
  http: address: ":8888/tcp"
  traefik: address: ":9000/tcp"
  web: address: ":8000/tcp"
  websecure: address: ":8443/tcp"
}
