SHELL := /bin/bash

.PHONY: cutout

DOMAIN := defn.jp

k := kubectl
ks := kubectl -n kube-system
km := kubectl -n metallb-system
kk := kubectl -n kuma-system
kt := kubectl -n traefik
kg := kubectl -n kong
kv := kubectl -n knative-serving

menu:
	@perl -ne 'printf("%10s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

test: # Test manifests with kubeval
	for a in k/*/; do kustomize build $$a | kubeval --skip-kinds IngressRoute; done

setup: # Setup requirements for katt
	$(MAKE) network

thing: # Bring up both katts: kind, mean
	$(MAKE) clean
	$(MAKE) setup

kind: # Bring up kind katt
	$(MAKE) clean-kind
	$(MAKE) setup
	kind create cluster --name kind --config k/kind.yaml
	#$(MAKE) katt-extras PET=kind

mean: # Bring up mean katt
	$(MAKE) clean-mean
	$(MAKE) setup
	kind create cluster --name mean --config k/mean.yaml
	#$(MAKE) katt-extras PET=mean

clean: # Teardown
	$(MAKE) clean-kind
	$(MAKE) clean-mean

clean-kind:
	-kind delete cluster --name kind

clean-mean:
	-kind delete cluster --name mean

network:
	if ! test "$$(docker network inspect kind | jq -r '.[].IPAM.Config[].Subnet')" = 172.25.0.0/16; then docker network rm kind; fi
	if test -z "$$(docker network inspect kind | jq -r '.[].IPAM.Config[].Subnet')"; then docker network create --subnet 172.25.0.0/16 --ip-range 172.25.1.0/24 kind; fi

wait:
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do \
		$(k) get --all-namespaces pods; sleep 5; echo; done

katt-extras: # Setup katt with cilium, metallb, kuma, traefik, zerotier, kong, knative, hubble
	$(MAKE) cilium wait
	$(MAKE) metal wait
	$(MAKE) kuma
	$(MAKE) traefik wait
	$(MAKE) zerotier wait
	#$(MAKE) knative wait
	#$(MAKE) kong wait
	#$(MAKE) hubble wait
	$(k) get --all-namespaces pods
	$(k) cluster-info

cilium:
	kustomize build k/cilium | $(ks) apply -f -
	$(MAKE) wait
	while $(ks) get nodes | grep NotReady; do \
		sleep 5; done

metal:
	kustomize build k/metal | $(km) apply -f -

kuma-kind:
	$(MAKE) kuma PET=kind

kuma-mean:
	$(MAKE) kuma PET=mean

kuma:
	kumactl install control-plane --mode=remote --zone=$(PET) --kds-global-address grpcs://192.168.195.116:5685 | $(k) apply -f -
	$(MAKE) wait
	kumactl install dns | $(k) apply -f -
	sleep 10; kumactl install ingress | $(k) apply -f - || (sleep 30; kumactl install ingress | $(k) apply -f -)
	$(MAKE) wait
	$(MAKE) kuma-inner PET="$(PET)"

kuma-inner:
	echo "---" | yq -y --arg pet "$(PET)" --arg address "$(shell pass katt/$(PET)/ip)" \
	'{type: "Zone", name: $$pet, ingress: { address: "\($$address):10001" }}' \
		| kumactl apply -f -

kong:
	$(k) apply -f https://bit.ly/k4k8s

knative:
	kubectl apply --filename https://github.com/knative/serving/releases/download/v0.16.0/serving-crds.yaml
	kubectl apply --filename https://github.com/knative/serving/releases/download/v0.16.0/serving-core.yaml
	kubectl patch configmap/config-network --namespace knative-serving --type merge --patch '{"data":{"ingress.class":"kong"}}'
	kubectl patch configmap/config-domain --namespace knative-serving --type merge --patch '{"data":{"$(PET).defn.jp":""}}'

traefik:
	$(kt) apply -f crds
	kustomize build k/traefik | $(kt) apply -f -

hubble:
	kustomize build k/hubble | $(ks) apply -f -

g2048:
	kustomize build k/g2048 | $(k) apply -f -

cloudflared:
	kustomize build k/cloudflared | $(kt) apply -f -

zerotier:
	kustomize build k/zerotier | $(k) apply -f -

home:
	kustomize build k/home | $(k) apply -f -

top: # Monitor hyperkit processes
	top $(shell pgrep hyperkit | perl -pe 's{^}{-pid }')

k/traefik/secret/acme.json acme.json:
	@jq -n \
		--arg domain $(DOMAIN) \
		--arg certificate "$(shell cat ~/.acme.sh/$(DOMAIN)/fullchain.cer | base64 -w 0)" \
		--arg key "$(shell cat ~/.acme.sh/$(DOMAIN)/$(DOMAIN).key | base64 -w 0)" \
		'{le: { Certificates: [{Store: "default", certificate: $$certificate, key: $$key, domain: {main: $$domain, sans: ["*.\($$domain)"]}}]}}' \
	> acme.json.1
	mv acme.json.1 acme.json

~/.acme.sh/$(DOMAIN)/fullchain.cer cert:
	~/.acme.sh/acme.sh --issue --dns dns_cf \
		-k 4096 \
		-d $(DOMAIN) \
		-d '*.$(DOMAIN)'

use-kind:
	$(k) config use-context kind-kind
	$(k) get nodes

use-mean:
	$(k) config use-context kind-mean
	$(k) get nodes
