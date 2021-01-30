_domain: "katt.defn.jp"

_workers: [0]

_networking: {
	serviceSubnet: "10.17.0.0/16"
	podSubnet:     "10.18.0.0/16"
}

_address_pools: "general":       "172.25.32.1-172.25.32.254"
_address_pools: "home":          "172.25.31.100/32"
_address_pools: "traefik":       "172.25.31.26/32"
_address_pools: "traefik-proxy": "172.25.31.25/32"
_address_pools: "kuma-ingress":  "172.25.31.24/32"
_address_pools: "pihole":        "172.25.31.1/32"
