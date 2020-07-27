SHELL := /bin/bash

consul-repo:
	helm repo add hashicorp https://helm.releases.hashicorp.com

consul.yaml: consul-values.yaml
	helm template consul hashicorp/consul \
		-f consul-values.yaml \
		> consul.yaml
