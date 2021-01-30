_domain: "katt.defn.jp"

_workers: [0]

_networking: {
	serviceSubnet: "10.203.0.0/17"
	podSubnet:     "10.203.128.0/17"
}

_address_pools: "traefik":       "172.25.31.26/32"
_address_pools: "traefik-proxy": "172.25.31.25/32"
_address_pools: "kuma-ingress":  "172.25.31.24/32"
_address_pools: "pihole":        "172.25.31.1/32"

_address_pools: "general":       "172.25.31.100-172.25.31.199"
