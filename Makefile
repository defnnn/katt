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

KATT_IP := 169.254.21.0

once:
	$(MAKE) network || true
	$(MAKE) os-$(shell uname -s) || true

network:
	docker network create --subnet 172.31.188.0/24 kitt

os-Linux:
	docker run --rm -i --privileged --network=host --pid=host alpine nsenter -t 1 -m -u -n -i -- \
  bash -c "ip link add dummy0 type dummy; ip addr add $(KATT_IP)/32 dev dummy0; ip link set dev dummy0 up"

os-Linux-down:
	docker run --rm -i --privileged --network=host --pid=host alpine nsenter -t 1 -m -u -n -i -- \
	bash -c "ip addr del $(KATT_IP)/32 dev dummy0"

os-Darwin:
	for ip in $(KATT_IP); do sudo ifconfig lo0 alias "$$ip" netmask 255.255.255.255; done

os-Darwin-down:
	for ip in $(KATT_IP); do sudo ifconfig lo0 -alias "$$ip" netmask 255.255.255.255; done

top: # Monitor hyperkit processes
	top $(shell pgrep hyperkit | perl -pe 's{^}{-pid }')

kind:
	$(MAKE) kind-once
	$(MAKE) kind-cluster
	$(MAKE) kind-cilium
	$(MAKE) kind-extras

kind-once:
	kind delete cluster || true
	docker network rm kind || true
	docker network create --subnet 172.18.0.0/16 kind

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

cilium:
	k apply -f cilium.yaml
	while [[ "$$(ks get -o json pods | jq -r '.items[].status | "\(.phase) \(.containerStatuses[].ready)"' | sort -u)" != "Running true" ]]; do ks get pods; sleep 5; echo; done
	k apply -f hubble.yaml

metal:
	k create ns metallb-system || true
	kn metallb-system apply -f metal.yaml

cloudflare.yaml:
	cp $@.example $@

traefik: cloudflare.yaml
	k create ns traefik || true
	kt apply -f crds
	kt apply -f cloudflare.yaml
	kt apply -f traefik.yaml

nginx:
	k apply -f $@.yaml

cilium.yaml:
	helm repo add cilium https://helm.cilium.io/
	helm template cilium/cilium --version 1.8.0-rc4 \
		--namespace kube-system \
		--set global.nodeinit.enabled=true \
		--set global.kubeProxyReplacement=partial \
		--set global.hostServices.enabled=false \
		--set global.externalIPs.enabled=true \
		--set global.nodePort.enabled=true \
		--set global.hostPort.enabled=true \
		--set global.pullPolicy=IfNotPresent \
		--set config.ipam=kubernetes \
		--set global.hubble.enabled=true \
		--set global.hubble.listenAddress=":4244" \
		--set global.hubble.relay.enabled=true \
		--set global.hubble.ui.enabled=true \
		--set global.hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
		--set global.cni.chainingMode=portmap \
		> cilium.yaml

connectivity-check:
	kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.8.0-rc4/examples/kubernetes/connectivity-check/connectivity-check.yaml
