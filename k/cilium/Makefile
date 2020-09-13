SHELL := /bin/bash

cilium-repo:
	helm repo add cilium https://helm.cilium.io

cilium.yaml:
	helm template cilium/cilium --version 1.8.2 \
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
		https://raw.githubusercontent.com/cilium/cilium/1.8.2/examples/kubernetes/connectivity-check/connectivity-check.yaml
