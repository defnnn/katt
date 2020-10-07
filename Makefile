SHELL := /bin/bash

.PHONY: cutout

DOMAIN := defn.jp

first = $(word 1, $(subst -, ,$@))
second = $(word 2, $(subst -, ,$@))

k := kubectl
ks := kubectl -n kube-system
km := kubectl -n metallb-system
kk := kubectl -n kuma-system
kt := kubectl -n traefik
kg := kubectl -n kong
kv := kubectl -n knative-serving
kd := kubectl -n external-dns

menu:
	@perl -ne 'printf("%20s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

test: # Test manifests with kubeval
	for a in k/*/; do kustomize build $$a | kubeval --skip-kinds IngressRoute; done

tilt:
	tilt up --context kind-katt

thing:
	$(MAKE) clean
	$(MAKE) setup
	$(MAKE) katt
	$(MAKE) nice
	$(MAKE) mean

setup: # Setup requirements for katt
	$(MAKE) network

network:
	if ! test "$$(docker network inspect kind | jq -r '.[].IPAM.Config[].Subnet')" = 172.25.0.0/16; then \
		docker network rm kind; fi
	if test -z "$$(docker network inspect kind | jq -r '.[].IPAM.Config[].Subnet')"; then \
		docker network create --subnet 172.25.0.0/16 --ip-range 172.25.1.0/24 kind; fi

katt nice mean: # Bring up a kind cluster
	if [[ "$@" == "katt" ]]; then $(MAKE) registry; fi
	$(MAKE) clean-$@
	$(MAKE) setup
	cue export --out yaml c/$@.cue c/kind.cue | kind create cluster --name $@ --config -
	$(MAKE) use-$@
	env PET=$@ $(MAKE) extras-$@
	$(MAKE) registry
	$(k) get --all-namespaces pods
	$(k) cluster-info

extras-%:
	$(MAKE) cilium wait
	$(MAKE) zerotier wait
	$(MAKE) metal wait
	if [[ "$@" == "extras-katt" ]]; then $(MAKE) traefik wait; $(MAKE) hubble wait; $(MAKE) external-dns wait; $(MAKE) cert-manager wait; fi
	if [[ "$@" == "extras-katt" ]]; then k apply -f acme.yaml; fi 

use-%:
	$(k) config use-context kind-$(second)
	$(k) get nodes

clean: # Teardown
	$(MAKE) clean-katt
	$(MAKE) clean-nice
	$(MAKE) clean-mean

clean-%:
	-kind delete cluster --name $(second)

wait:
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do \
		$(k) get --all-namespaces pods; sleep 5; echo; done

cilium:
	kustomize build k/cilium | $(ks) apply -f -
	$(MAKE) wait
	while $(ks) get nodes | grep NotReady; do \
		sleep 5; done

metal:
	cue export --out yaml c/$(PET).cue c/metal.cue > k/metal/config/config
	kustomize build k/metal | $(km) apply -f -

kong:
	$(k) apply -f https://bit.ly/k4k8s

knative:
	kubectl apply --filename https://github.com/knative/serving/releases/download/v0.16.0/serving-crds.yaml
	kubectl apply --filename https://github.com/knative/serving/releases/download/v0.16.0/serving-core.yaml
	kubectl patch configmap/config-network --namespace knative-serving --type merge --patch '{"data":{"ingress.class":"kong"}}'
	kubectl patch configmap/config-domain --namespace knative-serving --type merge --patch '{"data":{"$(PET).defn.jp":""}}'

traefik:
	cue export --out yaml c/$(PET).cue c/traefik.cue > k/traefik/config/traefik.yaml
	$(kt) apply -f crds
	kustomize build k/traefik | $(kt) apply -f -

external-dns:
	kustomize build --enable_alpha_plugins k/external-dns | $(k) apply -f -

cert-manager:
	kustomize build --enable_alpha_plugins k/cert-manager | $(k) apply -f -

hubble:
	kustomize build k/hubble | $(ks) apply -f -

g2048:
	kustomize build k/g2048 | $(k) apply -f -

zerotier:
	kustomize build --enable_alpha_plugins k/zerotier/$(PET) | $(k) apply -f -

kuma:
	kumactl install control-plane --mode=remote --zone=$(PET) --kds-global-address grpcs://192.168.195.116:5685 | $(k) apply -f -
	$(MAKE) wait
	kumactl install dns | $(k) apply -f -
	sleep 10; kumactl install ingress | $(k) apply -f - || (sleep 30; kumactl install ingress | $(k) apply -f -)
	$(MAKE) wait
	$(MAKE) kuma-inner

kuma-inner:
	echo "---" | yq -y --arg pet "$(PET)" --arg address "$(shell pass katt/$(PET)/ip)" \
	'{type: "Zone", name: $$pet, ingress: { address: "\($$address):10001" }}' \
		| kumactl apply -f -

cert: # Request certificate with acme.sh DOMAIN=
	$(MAKE) ~/.acme.sh/$(DOMAIN)/fullchain.cer
	$(MAKE) acme.json

acme.json: ~/.acme.sh/$(DOMAIN)/fullchain.cer
	@jq -n \
		--arg domain $(DOMAIN) \
		--arg certificate "$(shell cat ~/.acme.sh/$(DOMAIN)/fullchain.cer | ( base64 -w 0 2>/dev/null || base64 ) )" \
		--arg key "$(shell cat ~/.acme.sh/$(DOMAIN)/$(DOMAIN).key | ( base64 -w 0 2>/dev/null || base64 ) )" \
		'{le: { Certificates: [{Store: "default", certificate: $$certificate, key: $$key, domain: {main: $$domain, sans: ["*.\($$domain)"]}}]}}' \
	> acme.json.1
	mv acme.json.1 acme.json

~/.acme.sh/acme.sh:
	curl https://get.acme.sh | sh

~/.acme.sh/$(DOMAIN)/fullchain.cer: ~/.acme.sh/acme.sh # Request certificate with acme.sh
	~/.acme.sh/acme.sh --issue --dns dns_cf \
		-k 4096 \
		-d $(DOMAIN) \
		-d '*.$(DOMAIN)'

registry: # Run a local registry
	k apply -f k/registry.yaml
