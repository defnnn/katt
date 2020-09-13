SHELL := /bin/bash

.PHONY: cutout

menu:
	@perl -ne 'printf("%10s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

top: # Monitor hyperkit processes
	top $(shell pgrep hyperkit | perl -pe 's{^}{-pid }')

setup:
	exec/katt-setup

clean:
	kind delete cluster || true
	docker network rm kind || true

kind:
	$(MAKE) clean
	$(MAKE) setup
	$(MAKE) kind-cluster
	@echo; echo; echo
	@echo RUN: make kind-setup to install the rest of katt
	@echo; echo; echo
	$(MAKE) api-tunnel

kind-setup:
	$(MAKE) kind-config
	$(MAKE) kind-cilium
	$(MAKE) kind-extras

kind-cluster:
	kind create cluster --config kind.yaml --wait 1s

kind-config:
	kind export kubeconfig
	k cluster-info

kind-cilium:
	$(MAKE) cilium
	while ks get nodes | grep NotReady; do sleep 5; done
	while [[ "$$(ks get -o json pods | jq -r '.items[].status | "\(.phase) \(.containerStatuses[].ready)"' | sort -u)" != "Running true" ]]; do ks get pods; sleep 5; echo; done

kind-extras:
	$(MAKE) metal
	$(MAKE) traefik
	$(MAKE) hubble
	$(MAKE) nginx
	#$(MAKE) consul

cilium:
	kustomize build k/cilium | ks apply -f -
	while [[ "$$(ks get -o json pods | jq -r '.items[].status | "\(.phase) \(.containerStatuses[].ready)"' | sort -u)" != "Running true" ]]; do ks get pods; sleep 5; echo; done

metal:
	k create ns metallb-system || true
	kustomize build k/metal | kn metallb-system apply -f -

traefik:
	k create ns traefik || true
	kt apply -f crds
	kustomize build k/traefik | kt apply -f -

hubble:
	kustomize build k/hubble | ks apply -f -

nginx:
	kustomize build k/nginx | k apply -f -

consul:
	kustomize build k/consul | k apply -f -

api-tunnel:
	port=$(shell docker inspect kind-control-plane | jq -r '.[].NetworkSettings.Ports["6443/tcp"][] | select(.HostIp == "127.0.0.1") | .HostPort'); ssh defn.sh -L "$$port:localhost:$$port" sleep 8640000
