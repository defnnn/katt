_networking: {
	podSubnet:     "10.25.0.0/16"
	serviceSubnet: "10.26.0.0/16"
}

_address_pools: "general":       "172.25.26.1-172.25.29.254"
_address_pools: "traefik":       "172.25.25.26/32"
_address_pools: "traefik-proxy": "172.25.25.25/32"
_address_pools: "kuma-ingress":  "172.25.25.24/32"
_address_pools: "pihole":        "172.25.25.1/32"
_address_pools: "home":          "172.25.25.100/32"
