_pet: "katt"

_workers: [0]

_networking: {
	serviceSubnet: "10.31.0.0/17"
	podSubnet:     "10.31.128.0/17"
}

_address_pools: "traefik-proxy": "172.25.1.25/32"
_address_pools: "general":       "172.25.1.100-172.25.1.149"
