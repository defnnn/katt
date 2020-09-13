SHELL := /bin/bash

.PHONY: cutout

k := kubectl
ks := kubectl -n kube-system
kt := kubectl -n traefik
km := kubectl -n metallb-system

menu:
	@perl -ne 'printf("%10s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

katt: # Bring up a basic katt with kind
	$(MAKE) clean
	$(MAKE) kind-cluster
	$(MAKE) katt-setup

katt-defn: # Bring up a basic katt with kind, api-tunnel, cloudflared
	$(MAKE) clean
	$(MAKE) kind-cluster1s
	(sleep 10; $(MAKE) katt-setup; $(MAKE) cloudflared) & $(MAKE) api-tunnel

katt-setup: # Setup katt with configs, cilium, and extras
	$(MAKE) kind-config
	$(MAKE) kind-cilium
	$(MAKE) kind-extras
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do $(k) get --all-namespaces pods; sleep 5; echo; done
	$(k) get --all-namespaces pods
	$(k) cluster-info

clean: # Teardown katt
	kind delete cluster || true
	docker network rm kind || true

kind-cluster:
	kind create cluster --config kind.yaml

kind-cluster1s:
	kind create cluster --config kind.yaml --wait 1s

kind-config:
	kind export kubeconfig
	$(k) cluster-info

kind-cilium:
	$(MAKE) cilium
	while $(ks) get nodes | grep NotReady; do sleep 5; done
	while [[ "$$($(ks) get -o json pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do $(ks) get pods; sleep 5; echo; done

kind-extras:
	$(MAKE) metal
	$(MAKE) traefik
	$(MAKE) hubble

cilium:
	kustomize build k/cilium | $(ks) apply -f -
	while [[ "$$($(ks) get -o json pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do $(ks) get pods; sleep 5; echo; done

metal:
	$(k) create ns metallb-system || true
	kustomize build k/metal | $(km) apply -f -

traefik:
	$(k) create ns traefik || true
	$(kt) apply -f crds
	kustomize build k/traefik | $(kt) apply -f -

hubble:
	kustomize build k/hubble | $(ks) apply -f -

cloudflared:
	-kubectl create secret generic katt.run --from-file="$(HOME)/.cloudflared/cert.pem"
	kustomize build k/cloudflared | $(k) apply -f -

consul:
	kustomize build k/consul | $(k) apply -f -

top: # Monitor hyperkit processes
	top $(shell pgrep hyperkit | perl -pe 's{^}{-pid }')

api-tunnel: # ssh tunnel to kind api port
	port=$(shell docker inspect kind-control-plane | jq -r '.[].NetworkSettings.Ports["6443/tcp"][] | select(.HostIp == "127.0.0.1") | .HostPort'); \
			ssh defn.sh -L "$$port:localhost:$$port" sleep 8640000
