_pet: "catt"

_workers: [0]

_networking: {
	serviceSubnet: "10.32.0.0/17"
	podSubnet:     "10.32.128.0/17"
}

_address_pools: "traefik":       "172.25.32.26/32"
_address_pools: "traefik-proxy": "172.25.32.25/32"
_address_pools: "pihole":        "172.25.32.1/32"
_address_pools: "general":       "172.25.32.100-172.25.32.199"
