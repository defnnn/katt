SHELL := /bin/bash

VERSION := 1.8.4

cilium-repo:
	helm repo add cilium https://helm.cilium.io
	helm pull cilium/cilium

cilium.yaml:
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
		> cilium.yaml

connectivity-check.yaml:
	curl -sSL -o connectivity-check.yaml \
		https://raw.githubusercontent.com/cilium/cilium/$(VERSION)/examples/kubernetes/connectivity-check/connectivity-check.yaml
