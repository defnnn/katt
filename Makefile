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

setup: # Setup requirements for katt
	$(MAKE) network || true
	$(MAKE) dummy || true

kitt:
	docker-compose build
	docker-compose rm -f -s
	docker-compose up -d --remove-orphans

katts: # Bring up both katts: kind, mean
	$(MAKE) clean
	$(MAKE) setup
	$(MAKE) katt-kind
	$(MAKE) katt-mean

katt-kind: # Bring up kind katt
	$(MAKE) restore-pet PET=kind
	$(MAKE) setup || true
	kind create cluster --name kind --config k/kind.yaml
	$(MAKE) katt-extras

katt-mean: # Bring up mean katt
	$(MAKE) restore-pet PET=mean
	$(MAKE) setup || true
	kind create cluster --name mean --config k/mean.yaml
	$(MAKE) katt-extras

clean: # Teardown katt
	$(MAKE) clean-kind || true
	$(MAKE) clean-mean || true
	docker network rm kind || true
	sudo ip link del dummy1 || true
	sudo ip link del dummy2 || true

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

katt-extras: # Setup katt with cilium, traefik, hubble, zerotier
	$(MAKE) cilium
	$(MAKE) traefik
	$(MAKE) hubble
	$(MAKE) zerotier
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do $(k) get --all-namespaces pods; sleep 5; echo; done
	$(k) get --all-namespaces pods
	$(k) cluster-info

cilium:
	kustomize build k/cilium | $(ks) apply -f -
	while [[ "$$($(ks) get -o json pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u)" != "Running true" ]]; do $(ks) get pods; sleep 5; echo; done
	while $(ks) get nodes | grep NotReady; do sleep 5; done
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

restore-kitt:
	set -a; source ../kitt/.env; set +a; $(MAKE) restore-kitt-inner

restore-kitt-inner:
	pass kitt/$(KITT_DOMAIN)/env | base64 -d > .env
	pass kitt/$(KITT_DOMAIN)/authtoken.secret | perl -pe 's{\s*$$}{}'  > etc/zerotier/zerotier-one/authtoken.secret
	pass kitt/$(KITT_DOMAIN)/identity.public | perl -pe 's{\s*$$}{}' > etc/zerotier/zerotier-one/identity.public
	pass kitt/$(KITT_DOMAIN)/identity.secret | perl -pe 's{\s*$$}{}' > etc/zerotier/zerotier-one/identity.secret
	pass kitt/$(KITT_DOMAIN)/hook-start | base64 -d > etc/zerotier/hooks/hook-start
