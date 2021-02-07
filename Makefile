SHELL := /bin/bash

.PHONY: cutout

first = $(word 1, $(subst -, ,$@))
second = $(word 2, $(subst -, ,$@))

k := kubectl
ks := kubectl -n kube-system
km := kubectl -n metallb-system
kt := kubectl -n traefik
kx := kubectl -n external-secrets
kc := kubectl -n cert-manager
kld := kubectl -n linkerd

kk := kubectl -n kuma-system
kg := kubectl -n kong
kv := kubectl -n knative-serving
kd := kubectl -n external-dns

menu:
	@perl -ne 'printf("%20s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

test: # Test manifests with kubeval
	for a in k/*/; do kustomize build $$a | kubeval --skip-kinds IngressRoute; done

tilt:
	tilt up --context kind-katt

zero:
	$(MAKE) clean
	$(MAKE) network

one:
	$(MAKE) katt

vpn:
	docker exec kind-control-plane apt-get update
	docker exec kind-control-plane apt-get install -y gnupg2 net-tools iputils-ping dnsutils
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/groovy.gpg | docker exec -i kind-control-plane apt-key add -
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/groovy.list | docker exec -i kind-control-plane tee /etc/apt/sources.list.d/tailscale.list
	curl -fsSL https://install.zerotier.com | docker exec -i kind-control-plane bash
	docker exec -i kind-control-plane apt-get install -y tailscale || true
	docker exec -i kind-control-plane systemctl start tailscaled

setup: c/site.cue .env # Setup install, network requirements
	asdf install
	brew install linkerd

c/site.cue .env:
	cp $@.env $@

network:
	sudo mount bpffs /sys/fs/bpf -t bpf
	. .env && if test -z "$$(docker network inspect kind 2>/dev/null | jq -r '.[].IPAM.Config[].Subnet')"; then \
		docker network create --subnet $${KATT_KIND_CIDR} --ip-range $${KATT_KIND_CIDR} \
			-o com.docker.network.bridge.enable_ip_masquerade=true \
			-o com.docker.network.bridge.enable_icc=true \
			-o com.docker.network.bridge.name=kind0 \
			kind; fi

ryokan tatami:
	cue export --out yaml <(echo "_apiServerAddress: \"$$(ifconfig eth0 | grep 'inet ' | awk '{print $$2}')\"") c/$@.cue c/kind.cue | kind create cluster --config -

katt: # Install all the goodies
	$(MAKE) vpn
	$(MAKE) cilium wait
	$(MAKE) linkerd  wait
	$(MAKE) metal cert-manager traefik kruise hubble wait
	$(MAKE) site wait

clean: # Teardown
	-kind delete cluster
	$(MAKE) down
	docker network rm kind || true
	sudo systemctl restart docker

wait:
	sleep 5
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u | grep -v 'Succeeded false')" != "Running true" ]]; do \
		$(k) get --all-namespaces pods; sleep 5; echo; done

cilium:
	helm repo add cilium https://helm.cilium.io/ --force-update
	helm repo update
	helm install cilium cilium/cilium --version 1.9.3 \
		--namespace kube-system \
		--set nodeinit.enabled=true \
		--set kubeProxyReplacement=partial \
		--set hostServices.enabled=false \
		--set externalIPs.enabled=true \
		--set nodePort.enabled=true \
		--set hostPort.enabled=true \
		--set bpf.masquerade=false \
		--set image.pullPolicy=IfNotPresent \
		--set ipam.mode=kubernetes
	while $(ks) get nodes | grep NotReady; do \
		sleep 5; done

linkerd:
	linkerd check --pre
	linkerd install | perl -pe 's{enforced-host=.*}{enforced-host=}' | $(k) apply -f -
	linkerd check

metal:
	cue export --out yaml c/site.cue c/metal.cue > k/metal/config/config
	kustomize build k/metal | $(km) apply -f -

kruise:
	kustomize build k/kruise | $(k) apply -f -

traefik:
	cue export --out yaml c/site.cue c/traefik.cue > k/traefik/config/traefik.yaml
	$(kt) apply -f k/traefik/crds
	kustomize build k/traefik | $(kt) apply -f -

external-secrets:
	$(kx) apply -f k/external-secrets/crds
	kustomize build --enable_alpha_plugins k/external-secrets | $(kx) apply -f -

kubernetes-dashboard:
	kustomize build --enable_alpha_plugins k/kubernetes-dashboard | $(k) apply -f -

cert-manager:
	kustomize build --enable_alpha_plugins k/cert-manager | $(k) apply -f -

hubble:
	kustomize build k/hubble | $(ks) apply -f -

home:
	kustomize build --enable_alpha_plugins k/home | $(k) apply -f -

site:
	kustomize build k/site | linkerd inject - | $(k) apply -f -

up: # Bring up homd
	docker-compose up -d --remove-orphans

down: # Bring down home
	docker-compose down --remove-orphans

recreate: # Recreate home container
	$(MAKE) down
	$(MAKE) up

recycle: # Recycle home container
	$(MAKE) pull
	$(MAKE) recreate

pull:
	docker-compose pull

logs:
	docker-compose logs -f

registry: # Run a local registry
	k apply -f k/registry.yaml
