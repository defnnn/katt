SHELL := /bin/bash

.PHONY: cutout

DOMAIN := ooooooooooooooooooooooooooooo.ooo

k := kubectl
ks := kubectl -n kube-system
kt := kubectl -n traefik
km := kubectl -n metallb-system

menu:
	@perl -ne 'printf("%10s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

test: # Test manifests with kubeval
	 for a in k/*/; do kustomize build $$a | kubeval --skip-kinds IngressRoute; done

katt: # Bring up a basic katt with kind
	$(MAKE) clean
	$(MAKE) kind-cluster
	$(MAKE) katt-setup

defn: # Bring up a basic katt with kind, api-tunnel, cloudflared
	$(MAKE) metal cloudflared zerotier g2048

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
	docker network create --subnet 172.25.0.0/16 --ip-range 172.25.1.0/24 kind
	kind create cluster --config kind.yaml

kind-config:
	kind export kubeconfig
	$(k) cluster-info

kind-cilium:
	$(MAKE) cilium
	while $(ks) get nodes | grep NotReady; do sleep 5; done
	while [[ "$$($(ks) get -o json pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do $(ks) get pods; sleep 5; echo; done

kind-extras:
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

g2048:
	kustomize build k/g2048 | $(k) apply -f -

cloudflared:
	kustomize build k/cloudflared | $(kt) apply -f -

zerotier:
	kustomize build k/zerotier | $(kt) apply -f -

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
	mv acme.json.1 k/traefik/secret/acme.json

~/.acme.sh/$(DOMAIN)/fullchain.cer cert:
	~/.acme.sh/acme.sh --issue --dns dns_cf \
		-k 4096 \
		-d $(DOMAIN) \
		-d '*.$(DOMAIN)'
