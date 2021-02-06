_pet: "katt"

_workers: [0]

_networking: {
	serviceSubnet: "10.31.0.0/17"
	podSubnet:     "10.31.128.0/17"
}

_address_pools: "traefik":       "172.25.31.26/32"
_address_pools: "traefik-proxy": "172.25.31.25/32"
_address_pools: "pihole":        "172.25.31.1/32"
_address_pools: "general":       "172.25.31.100-172.25.31.199"
