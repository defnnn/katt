package config

output: [{
	op:    "replace"
	path:  "/spec/acme/email"
	value: _le_email
}, {
	op:    "replace"
	path:  "/spec/acme/solvers/0/dns01/cloudflare/email"
	value: _cf_email
}, {
	op:    "replace"
	path:  "/spec/acme/solvers/0/selector/dnsZones/0"
	value: _cf_zone
}]
