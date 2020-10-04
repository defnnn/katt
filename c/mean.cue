_networking: {
	podSubnet:     "10.30.0.0/16"
	serviceSubnet: "10.31.0.0/16"
}

_address_pools: "my-ip-space":   "172.25.90.10-172.25.99.254"
_address_pools: "traefik":       "172.25.35.26/32"
_address_pools: "traefik-proxy": "172.25.35.25/32"
_address_pools: "kuma-ingress":  "172.25.35.24/32"
_address_pools: "pihole":        "172.25.35.1/32"
_address_pools: "home":          "172.25.35.100/32"
