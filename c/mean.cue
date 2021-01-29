_domain: "mean.defn.jp"

_workers: [0]

_networking: {
	serviceSubnet: "10.35.0.0/16"
	podSubnet:     "10.36.0.0/16"
}

_address_pools: "general":       "172.25.36.1-172.25.36.254"
_address_pools: "home":          "172.25.36.100/32"
_address_pools: "traefik":       "172.25.36.26/32"
_address_pools: "traefik-proxy": "172.25.36.25/32"
_address_pools: "kuma-ingress":  "172.25.36.24/32"
_address_pools: "pihole":        "172.25.36.1/32"
