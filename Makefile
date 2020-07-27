SHELL := /bin/bash

.PHONY: cutout

menu:
	@perl -ne 'printf("%10s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

cutout:
	rm -rf cutout
	cookiecutter --no-input --directory t/python gh:defn/cutouts \
		organization="Cuong Chi Nghiem" \
		project_name="katt" \
		repo="defn/katt" \
		repo_cache="defn/cache"
	rsync -ia cutout/. .
	rm -rf cutout
	git difftool --tool=vimdiff -y

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
	$(MAKE) kind-cilium
	$(MAKE) kind-extras

kind-cluster:
	kind create cluster --config kind.yaml
	$(MAKE) kind-config

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
	$(MAKE) nginx
	$(MAKE) consul

.PHONY: cilium metal traefik nginx consul

cilium:
	kustomize build cilium | ks apply -f -
	while [[ "$$(ks get -o json pods | jq -r '.items[].status | "\(.phase) \(.containerStatuses[].ready)"' | sort -u)" != "Running true" ]]; do ks get pods; sleep 5; echo; done

metal:
	k create ns metallb-system || true
	kustomize build metal | kn metallb-system apply -f -

traefik:
	k create ns traefik || true
	kt apply -f crds
	kustomize build traefik | kt apply -f -
	kustomize build hubble | ks apply -f -

nginx:
	kustomize build nginx | k apply -f -

consul:
	kustomize build consul | k apply -f -
