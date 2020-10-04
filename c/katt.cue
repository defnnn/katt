_domain: "defn.jp"

_networking: {
	podSubnet:     "10.10.0.0/16"
	serviceSubnet: "10.11.0.0/16"
}

_address_pools: "general":       "172.25.70.10-172.25.79.254"
_address_pools: "traefik":       "172.25.15.26/32"
_address_pools: "traefik-proxy": "172.25.15.25/32"
_address_pools: "kuma-ingress":  "172.25.15.24/32"
_address_pools: "pihole":        "172.25.15.1/32"
_address_pools: "home":          "172.25.15.100/32"
