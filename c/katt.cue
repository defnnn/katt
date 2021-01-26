_domain: "katt.defn.jp"

_workers: [0]

_networking: {
	serviceSubnet: "10.15.0.0/16"
	podSubnet:     "10.16.0.0/16"
}

_address_pools: "general":       "172.25.16.1-172.25.19.254"
_address_pools: "traefik":       "172.25.15.26/32"
_address_pools: "traefik-proxy": "172.25.15.25/32"
_address_pools: "kuma-ingress":  "172.25.15.24/32"
_address_pools: "pihole":        "172.25.15.1/32"
_address_pools: "home":          "172.25.15.100/32"
