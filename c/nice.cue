_domain: "nice.defn.jp"

_workers: [0]

_networking: {
	serviceSubnet: "10.25.0.0/16"
	podSubnet:     "10.26.0.0/16"
}

_address_pools: "general":       "172.25.34.1-172.25.34.254"
_address_pools: "home":          "172.25.33.100/32"
_address_pools: "traefik":       "172.25.33.26/32"
_address_pools: "traefik-proxy": "172.25.33.25/32"
_address_pools: "kuma-ingress":  "172.25.33.24/32"
_address_pools: "pihole":        "172.25.33.1/32"
