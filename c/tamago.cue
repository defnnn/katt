_petHostname: "tamago.defn.jp"

_networking: {
	serviceSubnet: "10.30.0.0/17"
	podSubnet:     "10.30.128.0/17"
}

_address_pools: "traefik-proxy": "172.25.0.25/32"
_address_pools: "general":       "172.25.0.100-172.25.0.149"
