_pet: "catt"

_workers: [0]

_networking: {
	serviceSubnet: "10.32.0.0/17"
	podSubnet:     "10.32.128.0/17"
}

_address_pools: "traefik-proxy": "172.26.1.25/32"
_address_pools: "general":       "172.26.1.100-172.26.1.149"
