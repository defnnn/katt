SHELL := /bin/bash

.PHONY: cutout

DOMAIN := ooooooooooooooooooooooooooooo.ooo

k := kubectl
ks := kubectl -n kube-system
kt := kubectl -n traefik
km := kubectl -n metallb-system
kk := kubectl -n kuma-system
kg := kubectl -n kong
kv := kubectl -n knative-serving

menu:
	@perl -ne 'printf("%10s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

test: # Test manifests with kubeval
	for a in k/*/; do kustomize build $$a | kubeval --skip-kinds IngressRoute; done

setup: # Setup requirements for katt
	$(MAKE) network || true

katts: # Bring up both katts: kind, mean
	$(MAKE) clean
	$(MAKE) setup
	$(MAKE) katt-kind
	$(MAKE) katt-mean

katt-kind: # Bring up kind katt
	$(MAKE) restore-pet PET=kind
	$(MAKE) setup || true
	kind create cluster --name kind --config k/kind.yaml
	$(MAKE) katt-extras PET=kind

katt-mean: # Bring up mean katt
	$(MAKE) restore-pet PET=mean
	$(MAKE) setup || true
	kind create cluster --name mean --config k/mean.yaml
	$(MAKE) katt-extras PET=mean

clean: # Teardown katt
	$(MAKE) clean-kind || true
	$(MAKE) clean-mean || true
	docker network rm kind || true

clean-kind:
	kind delete cluster --name kind

clean-mean:
	kind delete cluster --name mean

network:
	docker network create --subnet 172.25.0.0/16 --ip-range 172.25.1.0/24 kind

dummy:
	sudo ip link add dummy1 type dummy || true
	sudo ip addr add 169.254.32.2/32 dev dummy1 || true
	sudo ip link set dev dummy1 up
	sudo ip link add dummy2 type dummy || true
	sudo ip addr add 169.254.32.3/32 dev dummy2 || true
	sudo ip link set dev dummy2 up

defn:
	$(MAKE) metal cloudflared g2048

katt-extras: # Setup katt with cilium, metallb, traefik, hubble, kuma, zerotier, knative, kong
	$(MAKE) cilium
	$(MAKE) metal
	$(MAKE) traefik
	$(MAKE) hubble
	$(MAKE) kuma
	$(MAKE) zerotier
	$(MAKE) knative
	$(MAKE) kong
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do \
		$(k) get --all-namespaces pods; sleep 5; echo; done
	$(k) get --all-namespaces pods
	$(k) cluster-info

cilium:
	kustomize build k/cilium | $(ks) apply -f -
	while [[ "$$($(ks) get -o json pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do \
		$(ks) get pods; sleep 5; echo; done
	while $(ks) get nodes | grep NotReady; do \
		sleep 5; done
	while [[ "$$($(ks) get -o json pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do \
		$(ks) get pods; sleep 5; echo; done

metal:
	$(k) create ns metallb-system || true
	kustomize build k/metal | $(km) apply -f -

kuma-kind:
	$(MAKE) kuma PET=kind

kuma-mean:
	$(MAKE) kuma PET=mean

kuma:
	kumactl install control-plane --mode=remote --zone=$(PET) --kds-global-address grpcs://10.88.88.88:5685 | $(k) apply -f -
	sleep 5
	while [[ "$$($(ks) get -o json pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do \
		$(ks) get pods; sleep 5; echo; done
	kumactl install ingress | $(k) apply -f - || (sleep 30; kumactl install ingress | $(k) apply -f -)
	kumactl install metrics | $(k) apply -f -
	kumactl install dns | $(k) apply -f -
	kumactl apply -f k/$(PET)-zone.yaml

kong:
	$(k) apply -f https://bit.ly/k4k8s

knative:
	kubectl apply --filename https://github.com/knative/serving/releases/download/v0.16.0/serving-crds.yaml
	kubectl apply --filename https://github.com/knative/serving/releases/download/v0.16.0/serving-core.yaml
	kubectl patch configmap/config-network --namespace knative-serving --type merge --patch '{"data":{"ingress.class":"kong"}}'
	kubectl patch configmap/config-domain --namespace knative-serving --type merge --patch '{"data":{"$(PET).defn.jp":""}}'

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
	mv acme.json.1 acme.json

~/.acme.sh/$(DOMAIN)/fullchain.cer cert:
	~/.acme.sh/acme.sh --issue --dns dns_cf \
		-k 4096 \
		-d $(DOMAIN) \
		-d '*.$(DOMAIN)'

restore-kind:
	$(MAKE) restore-pet PET=kind

restore-mean:
	$(MAKE) restore-pet PET=mean

restore-pet:
	pass katt/$(PET)/ZT_DEST | perl -pe 's{\s*$$}{}'  > k/zerotier/config/ZT_DEST
	pass katt/$(PET)/ZT_NETWORK | perl -pe 's{\s*$$}{}' > k/zerotier/config/ZT_NETWORK
	pass katt/$(PET)/ZT_VIP | perl -pe 's{\s*$$}{}' > k/zerotier/config/ZT_VIP
	mkdir -p k/zerotier/secret
	pass katt/$(PET)/authtoken.secret | perl -pe 's{\s*$$}{}'  > k/zerotier/secret/ZT_AUTHTOKEN_SECRET
	pass katt/$(PET)/identity.public | perl -pe 's{\s*$$}{}' > k/zerotier/secret/ZT_IDENTITY_PUBLIC
	pass katt/$(PET)/identity.secret | perl -pe 's{\s*$$}{}' > k/zerotier/secret/ZT_IDENTITY_SECRET
	pass katt/$(PET)/hook-customize | base64 -d > k/zerotier/config/hook-customize
	pass katt/$(PET)/acme.json | base64 -d > k/traefik/secret/acme.json
	pass katt/$(PET)/traefik.yaml | base64 -d > k/traefik/config/traefik.yaml
	pass katt/$(PET)/metal/config | base64 -d > k/metal/config/config
	pass katt/$(PET)/metal/secretkey | base64 -d > k/metal/config/secretkey

restore-diff-kind:
	$(MAKE) restore-diff-pet PET=kind

restore-diff-mean:
	$(MAKE) restore-diff-pet PET=mean

restore-diff-pet:
	pdif katt/$(PET)/ZT_DEST k/zerotier/config/ZT_DEST
	pdif katt/$(PET)/ZT_NETWORK k/zerotier/config/ZT_NETWORK
	pdif katt/$(PET)/ZT_VIP k/zerotier/config/ZT_VIP
	pdif katt/$(PET)/authtoken.secret k/zerotier/secret/ZT_AUTHTOKEN_SECRET
	pdif katt/$(PET)/identity.public k/zerotier/secret/ZT_IDENTITY_PUBLIC
	pdif katt/$(PET)/identity.secret k/zerotier/secret/ZT_IDENTITY_SECRET
	pdiff katt/$(PET)/hook-customize k/zerotier/config/hook-customize
	pdiff katt/$(PET)/acme.json k/traefik/secret/acme.json
	pdiff katt/$(PET)/traefik.yaml k/traefik/config/traefik.yaml
	pdiff katt/$(PET)/metal/config k/metal/config/config
	pdiff katt/$(PET)/metal/secretkey k/metal/config/secretkey

kind:
	$(k) config use-context kind-kind
	$(k) get nodes

mean:
	$(k) config use-context kind-mean
	$(k) get nodes
