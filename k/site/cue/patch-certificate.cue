package config

output : [{
	op:    "replace"
	path:  "/spec/dnsNames/0"
	value: "*.\(_wildcard)"
}, {
	op:    "replace"
	path:  "/spec/dnsNames/1"
	value: "*.\(_wildcard_counter)"
},{
	op:    "replace"
	path:  "/spec/issuerRef/name"
	value: "letsencrypt-\(_le_env)"
}]
