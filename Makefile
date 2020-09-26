SHELL := /bin/bash

.PHONY: cutout

DOMAIN := ooooooooooooooooooooooooooooo.ooo

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
	$(MAKE) network || true
	$(MAKE) dummy || true
	$(MAKE) build

thing: # Bring up both katts: kind, mean
	$(MAKE) clean
	$(MAKE) setup
	$(MAKE) up
	$(MAKE) kuma-global-control-plane
	$(MAKE) katt-kind wait
	$(MAKE) katt-mean wait
	$(MAKE) mean
	$(k) apply -f k/kuma/demo-be.yaml
	$(MAKE) kind
	$(k) apply -f k/kuma/demo-fe.yaml

katt-kind: # Bring up kind katt
	$(MAKE) clean-kind
	$(MAKE) restore-pet PET=kind
	$(MAKE) setup || true
	kind create cluster --name kind --config k/kind.yaml
	$(MAKE) katt-extras PET=kind

katt-mean: # Bring up mean katt
	$(MAKE) clean-mean
	$(MAKE) restore-pet PET=mean
	$(MAKE) setup || true
	kind create cluster --name mean --config k/mean.yaml
	$(MAKE) katt-extras PET=mean

clean: # Teardown
	$(MAKE) clean-global-control-plane
	$(MAKE) clean-kind
	$(MAKE) clean-mean

clean-global-control-plane:
	-docker-compose down

clean-kind:
	-kind delete cluster --name kind

clean-mean:
	-kind delete cluster --name mean

network:
	docker network create --subnet 172.25.0.0/16 --ip-range 172.25.1.0/24 kind

dummy:
	sudo ip link add dummy0 type dummy || true
	sudo ip addr add 169.254.32.1/32 dev dummy0 || true
	sudo ip link set dev dummy0 up
	sudo ip link add dummy1 type dummy || true
	sudo ip addr add 169.254.32.2/32 dev dummy1 || true
	sudo ip link set dev dummy1 up
	sudo ip link add dummy2 type dummy || true
	sudo ip addr add 169.254.32.3/32 dev dummy2 || true
	sudo ip link set dev dummy2 up

defn:
	$(MAKE) metal cloudflared g2048

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
	kumactl install control-plane --mode=remote --zone=$(PET) --kds-global-address grpcs://$(shell docker inspect katt_kuma_1 | jq -r '.[].NetworkSettings.Networks.kind.IPAddress' ):5685 | $(k) apply -f -
	$(MAKE) wait
	kumactl install dns | $(k) apply -f -
	sleep 10; kumactl install ingress | $(k) apply -f - || (sleep 30; kumactl install ingress | $(k) apply -f -)
	$(MAKE) wait
	$(MAKE) kuma-inner PET="$(PET)"

kuma-inner:
	echo "---" | yq -y --arg pet "$(PET)" --arg address \
		"$(shell $(kk) get svc -o json | jq -r '.items[] | select(.metadata.name == "kuma-ingress") | .status.loadBalancer.ingress[].ip')" '{type: "Zone", name: $$pet, ingress: { address: "\($$address):10001" }}' \
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

restore-kind:
	$(MAKE) restore-pet PET=kind

restore-mean:
	$(MAKE) restore-pet PET=mean

restore-pet:
	pass katt/$(PET)/ZT_DEST | perl -pe 's{\s*$$}{}'  > k/zerotier/config/ZT_DEST
	pass katt/$(PET)/ZT_NETWORK | perl -pe 's{\s*$$}{}' > k/zerotier/config/ZT_NETWORK
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

build:
	docker-compose build

up:
	docker-compose rm -f -s
	docker-compose up -d --remove-orphans

restore-global-control-plane:
	set -a; source .env; set +a; $(MAKE) restore-global-control-plane-inner

restore-global-control-plane-inner:
	mkdir -p etc/traefik/acme
	pass kitt/$(katt_DOMAIN)/authtoken.secret | base64 -d | perl -pe 's{\s*$$}{}'  > etc/zerotier/zerotier-one/authtoken.secret
	pass kitt/$(katt_DOMAIN)/identity.public | base64 -d | perl -pe 's{\s*$$}{}' > etc/zerotier/zerotier-one/identity.public
	pass kitt/$(katt_DOMAIN)/identity.secret | base64 -d | perl -pe 's{\s*$$}{}' > etc/zerotier/zerotier-one/identity.secret
	pass kitt/$(katt_DOMAIN)/acme.json | base64 -d > etc/traefik/acme/acme.json
	chmod 0600 etc/traefik/acme/acme.json
	pass kitt/$(katt_DOMAIN)/hook-customize| base64 -d > etc/zerotier/hooks/hook-customize
	chmod 755 etc/zerotier/hooks/hook-customize
	pass kitt/$(katt_DOMAIN)/cert.pem | base64 -d > etc/cloudflared/cert.pem
	pass kitt/$(katt_DOMAIN)/env | base64 -d > .env

restore-global-control-plane-diff:
	set -a; source .env; set +a; $(MAKE) restore-global-control-plane-diff-inner

restore-global-control-plane-diff-inner:
	pdif kitt/$(katt_DOMAIN)/authtoken.secret etc/zerotier/zerotier-one/authtoken.secret
	pdif kitt/$(katt_DOMAIN)/identity.public etc/zerotier/zerotier-one/identity.public
	pdif kitt/$(katt_DOMAIN)/identity.secret etc/zerotier/zerotier-one/identity.secret
	pdiff kitt/$(katt_DOMAIN)/acme.json etc/traefik/acme/acme.json
	pdiff kitt/$(katt_DOMAIN)/hook-customize etc/zerotier/hooks/hook-customize
	pdiff kitt/$(katt_DOMAIN)/cert.pem etc/cloudflared/cert.pem
	pdiff kitt/$(katt_DOMAIN)/env .env

kuma-global-control-plane::
	sudo rsync -ia ~/work/kuma/bin/. /usr/local/bin/.
	sleep 10
	$(MAKE) kumactl
	kumactl apply -f k/traffic-permission-allow-all-traffic.yaml
	kumactl apply -f k/mesh-default.yaml

kumactl:
	kumactl config control-planes add --address http://$(shell docker inspect katt_kuma_1 | jq -r '.[].NetworkSettings.Networks.kind.IPAddress'):5681 --name kitt --overwrite
	kumactl config control-planes switch --name kitt

defn-cp:
	env \
		KUMA_MODE=remote \
		KUMA_MULTICLUSTER_REMOTE_ZONE=defn \
		KUMA_MULTICLUSTER_REMOTE_GLOBAL_ADDRESS=grpcs://192.168.195.116:5685 \
		kuma-cp run

defn-ingress:
	cat defn-ingress.yaml | kumactl apply -f -
	kumactl generate dataplane-token --dataplane=kuma-ingress > defn-ingress-token
	kuma-dp run --name=kuma-ingress --cp-address=http://localhost:5681 --dataplane-token-file=defn-ingress-token --log-level=debug

defn-spiral:
	cat spiral.yaml | kumactl apply -f -
	kumactl generate dataplane-token --dataplane=spiral > spiral-token
	kuma-dp run --name=spiral --cp-address=http://localhost:5681 --dataplane-token-file=spiral-token --log-level=debug

defn-the:
	cat the.yaml | kumactl apply -f -
	kumactl generate dataplane-token --dataplane=the > the-token
	kuma-dp run --name=the --cp-address=http://localhost:5681 --dataplane-token-file=the-token --log-level=debug
