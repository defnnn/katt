SHELL := /bin/bash

.PHONY: cutout

first = $(word 1, $(subst -, ,$@))
second = $(word 2, $(subst -, ,$@))

k := kubectl
ks := kubectl -n kube-system
km := kubectl -n metallb-system
kt := kubectl -n traefik
kg := kubectl -n gloo-system
kx := kubectl -n external-secrets
kc := kubectl -n cert-manager
kld := kubectl -n linkerd

kv := kubectl -n knative-serving
kd := kubectl -n external-dns

menu:
	@perl -ne 'printf("%20s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

test: # Test manifests with kubeval
	for a in k/*/; do kustomize build $$a | kubeval --skip-kinds IngressRoute; done

zero:
	$(MAKE) PET=$(PET) clean
	$(MAKE) PET=$(PET) network

clean: # Teardown
	-ssh $(PET) ./env.sh kind delete cluster
	ssh $(PET) docker network rm kind || true
	ssh $(PET) sudo systemctl restart docker

vpn:
	ssh $(PET) docker exec kind-control-plane apt-get update
	ssh $(PET) docker exec kind-control-plane apt-get install -y gnupg2 net-tools iputils-ping dnsutils
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/groovy.gpg | ssh $(PET) docker exec -i kind-control-plane apt-key add -
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/groovy.list | ssh $(PET) docker exec -i kind-control-plane tee /etc/apt/sources.list.d/tailscale.list
	curl -fsSL https://install.zerotier.com | ssh $(PET) docker exec -i kind-control-plane bash
	ssh $(PET) docker exec -i kind-control-plane apt-get install -y tailscale || true
	ssh $(PET) docker exec -i kind-control-plane systemctl start tailscaled

network:
	ssh $(PET) sudo mount bpffs /sys/fs/bpf -t bpf
	. .env.$(PET) && if test -z "$$(ssh $(PET) docker network inspect kind 2>/dev/null | jq -r '.[].IPAM.Config[].Subnet')"; then \
		ssh $(PET) docker network create --subnet $${KATT_KIND_CIDR} --ip-range $${KATT_KIND_CIDR} \
			-o com.docker.network.bridge.enable_ip_masquerade=true \
			-o com.docker.network.bridge.enable_icc=true \
			-o com.docker.network.bridge.name=kind0 \
			kind; fi

ryokan tatami:
	$(MAKE) $@-kind
	$(MAKE) $@-config
	$(MAKE) $@-katt

%-kind:
	$(MAKE) PET=$(first) zero
	echo "_apiServerAddress: \"$$(host $(first).defn.jp | awk '{print $$NF}')\"" > c/.$(first).cue
	cue export --out yaml c/.$(first).cue c/$(first).cue c/kind.cue | ssh $(first) ./env.sh kind create cluster --config -
	$(MAKE) $(first)-config
	$(MAKE) PET=$(first) vpn

%-config:
	mkdir -p ~/.kube
	rsync -ia $(first):.kube/config ~/.kube/$(first).conf
	env KUBECONFIG=$$HOME/.kube/$(first).conf k cluster-info

%-katt:
	env KUBECONFIG=$$HOME/.kube/$(first).conf $(MAKE) PET=$(first) katt

katt: # Install all the goodies
	$(MAKE) cilium wait
	$(MAKE) $(PET)-linkerd wait
	$(MAKE) $(PET)-metal $(PET)-traefik
	$(MAKE) gloo cert-manager flagger kruise hubble wait
	$(MAKE) $(PET)-site wait

tatami-linkerd:
	$(MAKE) linkerd wait
	$(MAKE) linkerd-trust-anchor
	$(MAKE) linkerd-use-trust

ryokan-linkerd:
	$(MAKE) linkerd-with-trust wait

wait:
	sleep 5
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u | grep -v 'Succeeded false')" != "Running true" ]]; do \
		$(k) get --all-namespaces pods; sleep 5; echo; done

cilium:
	helm repo add cilium https://helm.cilium.io/ --force-update
	helm repo update
	helm install cilium cilium/cilium --version 1.9.4 \
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

linkerd-trust-anchor:
	step certificate create root.linkerd.cluster.local root.crt root.key \
   	--profile root-ca --no-password --insecure --force
	step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
		--profile intermediate-ca --not-after 8760h --no-password --insecure \
		--ca root.crt --ca-key root.key --force
	$(kld) get cm linkerd-config -ojsonpath="{.data.values}" | yq -r .global.identityTrustAnchorsPEM  > trustAnchor.crt
	cat trustAnchor.crt root.crt > bundle.crt

linkerd-use-trust:
	linkerd upgrade --identity-trust-anchors-file=./bundle.crt | kubectl apply -f -

linkerd:
	linkerd check --pre
	linkerd install | perl -pe 's{enforced-host=.*}{enforced-host=}' | $(k) apply -f -
	linkerd check
	linkerd multicluster install | $(k) apply -f -
	linkerd check --multicluster

linkerd-with-trust:
	linkerd check --pre
	linkerd install \
		--identity-trust-anchors-file bundle.crt \
  	--identity-issuer-certificate-file issuer.crt \
  	--identity-issuer-key-file issuer.key | perl -pe 's{enforced-host=.*}{enforced-host=}' | $(k) apply -f -
	linkerd check
	linkerd multicluster install | $(k) apply -f -
	linkerd check --multicluster

link:
	tatami linkerd multicluster link --cluster-name tatami | ryokan $(k) apply -f -

link-check:
	linkerd check --multicluster
	linkerd multicluster gateways

flagger:
	kustomize build https://github.com/fluxcd/flagger/kustomize/linkerd?ref=v1.6.2 | kubectl apply -f -

kruise:
	kustomize build k/kruise | $(k) apply -f -

%-metal:
	bin/metal $(first)

%-traefik:
	cue export --out yaml c/.$(first).cue c/$(first).cue c/traefik.cue > k/traefik/config/traefik.yaml
	$(kt) apply -f k/traefik/crds
	kustomize build k/traefik | $(kt) apply -f -

gloo:
	#glooctl install knative -g
	glooctl install gateway --values k/gloo/values.yaml --with-admin-console
	kubectl patch settings -n gloo-system default -p '{"spec":{"linkerd":true}}' --type=merge
	curl -sSL https://raw.githubusercontent.com/solo-io/gloo/v1.2.9/example/petstore/petstore.yaml | linkerd inject - | $(k) apply -f -
	glooctl add route --path-exact /all-pets --dest-name default-petstore-8080 --prefix-rewrite /api/pets

external-secrets:
	$(kx) apply -f k/external-secrets/crds
	kustomize build --enable_alpha_plugins k/external-secrets | $(kx) apply -f -

kubernetes-dashboard:
	kustomize build --enable_alpha_plugins k/kubernetes-dashboard | $(k) apply -f -

cert-manager:
	kustomize build --enable_alpha_plugins k/cert-manager | $(k) apply -f -

hubble:
	helm upgrade cilium cilium/cilium --version 1.9.4 \
		--namespace kube-system \
		--reuse-values \
		--set hubble.listenAddress=":4244" \
		--set hubble.relay.enabled=true \
		--set hubble.ui.enabled=true

home:
	kustomize build --enable_alpha_plugins k/home | $(k) apply -f -

%-site:
	kustomize build k/site | linkerd inject - | $(k) apply -f -
	$(k) apply -f k/site/$(first).yaml

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
