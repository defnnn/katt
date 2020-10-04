accessLog: {}
log: {
	level:  "DEBUG"
	format: "json"
}

ping: {}

api: {
	insecure:  true
	dashboard: true
}

providers: kubernetesCRD: {}

entryPoints: {
	traefik: address: ":8080"
	http: address:    ":80"
	https: {
		address: ":443"
		http: tls: {
			certResolver: "le"
			domains: [{
				main: "*\(_domain)"
			}]
		}
	}
}

certificatesResolvers: le: acme: storage: "/data/traefik-secret/acme.json"
