SHELL := /bin/bash

VERSION := 1.9.3

menu:
	@perl -ne 'printf("%30s: %s\n","$$1","$$2") if m{^([\w+-\.]+):[^#]+#\s(.+)$$}' Makefile

vendor: # Add cilium repo
	helm repo add cilium https://helm.cilium.io --force-update
	helm repo update
	$(MAKE) vendor.yaml connectivity-check.yaml

.PHONY: vendor.yaml connectivity-check.yaml

vendor.yaml: # Generate vendor.yaml
	rm -f vendor.yaml
	helm template cilium/cilium --version $(VERSION) \
		--namespace kube-system \
		--set global.kubeProxyReplacement=partial \
		--set global.nodeinit.enabled=true \
		--set global.pullPolicy=IfNotPresent \
		--set config.ipam=kubernetes \
		--set global.hostServices.enabled=false \
		--set global.externalIPs.enabled=true \
		--set global.nodePort.enabled=true \
		--set global.hostPort.enabled=true \
		--set global.hubble.enabled=true \
		--set global.hubble.listenAddress=":4244" \
		--set global.hubble.relay.enabled=true \
		--set global.hubble.ui.enabled=true \
		--set global.hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
		> vendor.yaml

connectivity-check.yaml: # Get cilium connectivity check manifest
	rm -f connectivity-check.yaml
	curl -sSL -o connectivity-check.yaml \
		https://raw.githubusercontent.com/cilium/cilium/$(VERSION)/examples/kubernetes/connectivity-check/connectivity-check.yaml
