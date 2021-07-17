SHELL := /bin/bash

first = $(word 1, $(subst -, ,$@))
second = $(word 2, $(subst -, ,$@))
third = $(word 3, $(subst -, ,$@))

k := kubectl
ks := kubectl -n kube-system
kt := kubectl -n traefik
kg := kubectl -n gloo-system
kx := kubectl -n external-secrets
kc := kubectl -n cert-manager
kd := kubectl -n external-dns
ka := kubectl -n argocd
km := kubectl -n kuma-system
kn := kubectl -n

bridge := en0

menu:
	@perl -ne 'printf("%20s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

nue gyoku maki miwa:
	bin/cluster $(shell host $(first).defn.ooo | awk '{print $$NF}') ubuntu $(first)
	$(first) $(MAKE) cilium

west-launch:
	m delete --all --purge
	$(MAKE) $(first)-mp

west-reset:
	-echo /usr/local/bin/k3s-uninstall.sh | m shell $(first)
	-echo "echo drop database kubernetes | sudo -u postgres psql" | m shell $(first)
	m restart $(first)

east-reset:
	-/usr/local/bin/k3s-uninstall.sh
	-echo "database kubernetes" | sudo -u postgres psql
	sudo reboot &
	tmux detach

%-reset:
	-ssh "$(first).defn.ooo" /usr/local/bin/k3s-uninstall.sh
	-echo "drop database kubernetes" | ssh "$(first).defn.ooo" sudo -u postgres psql
	ssh "$(first).defn.ooo" sudo reboot &

east:
	-k3s-uninstall.sh
	-echo "drop database kubernetes" | sudo -u postgres psql
	bin/cluster \
		$(shell tailscale ip | grep ^100) \
		$(shell tailscale ip | grep ^100) \
		$(shell tailscale ip | grep ^100) \
		ubuntu $(first) $(first).defn.ooo \
		10.42.0.0/16 10.43.0.0/16
	$(first) $(MAKE) secrets
	$(first) $(MAKE) cilium cname="katt-$(first)" cid=102
	$(first) cilium clustermesh enable --context $@ --service-type LoadBalancer
	$(first) cilium clustermesh status --context $@ --wait
	$(MAKE) $(first)-argocd

%-mesh:
	$(first) cilium clustermesh connect --context $(first) --destination-context $(second)
	$(first) cilium clustermesh status --context $(first) --wait

%-test:
	-$(first) delete ns cilium-test
	$(first) cilium connectivity test
	$(first) delete ns cilium-test

%-connectivity:
	-$(first) delete ns cilium-test
	-$(second) delete ns cilium-test
	cilium connectivity test --context $(first) --multi-cluster $(second)
	-$(first) delete ns cilium-test
	-$(second) delete ns cilium-test

west:
	-ssh "$(first).defn.ooo" /usr/local/bin/k3s-uninstall.sh
	-echo "alter role postgres with password 'postgres'" | ssh "$(first).defn.ooo" sudo -u postgres psql
	-echo "drop database kubernetes" | ssh "$(first).defn.ooo" sudo -u postgres psql
	bin/cluster \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		ubuntu $(first) $(first).defn.ooo \
		10.40.0.0/16 10.41.0.0/16
	$(MAKE) $(first)-secrets
	$(first) $(MAKE) cilium cname="katt-$(first)" cid=101 copt="--inherit-ca east"
	$(MAKE) $(first)-add
	$(MAKE) $(first)-app

west-plus:
	$(first) cilium clustermesh enable --context $@ --service-type LoadBalancer
	$(first) cilium clustermesh status --context $@ --wait
	$(MAKE) $(first)-east-mesh
	$(MAKE) $(first)-add

.PHONY: a
a:
	-ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" /usr/local/bin/k3s-uninstall.sh
	-echo "alter role postgres with password 'postgres'" | ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" sudo -u postgres psql
	-echo "drop database kubernetes" | ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" sudo -u postgres psql
	bin/cluster \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}') \
		$(shell host $(first)-pub.dev.defn.net | awk '{print $$NF}') \
		ubuntu $(first) $(first).defn.ooo \
		10.50.0.0/16 10.51.0.0/16
	$(first) $(MAKE) cilium cname="katt-$(first)" cid=111

a-plus:
	$(first) cilium clustermesh enable --context $@ --service-type LoadBalancer
	$(first) cilium clustermesh status --context $@ --wait

b:
	-ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" /usr/local/bin/k3s-uninstall.sh
	-echo "alter role postgres with password 'postgres'" | ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" sudo -u postgres psql
	-echo "drop database kubernetes" | ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" sudo -u postgres psql
	bin/cluster \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}') \
		$(shell host $(first)-pub.dev.defn.net | awk '{print $$NF}') \
		ubuntu $(first) $(first).defn.ooo \
		10.52.0.0/16 10.53.0.0/16
	$(first) $(MAKE) cilium cname="katt-$(first)" cid=112 copt="--inherit-ca a"

b-plus:
	$(first) cilium clustermesh enable --context $@ --service-type LoadBalancer
	$(first) cilium clustermesh status --context $@ --wait
	$(MAKE) $(first)-a-mesh

c:
	-ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" /usr/local/bin/k3s-uninstall.sh
	-echo "alter role postgres with password 'postgres'" | ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" sudo -u postgres psql
	-echo "drop database kubernetes" | ssh "$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}')" sudo -u postgres psql
	bin/cluster \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first)-prv.dev.defn.net | awk '{print $$NF}') \
		$(shell host $(first)-pub.dev.defn.net | awk '{print $$NF}') \
		ubuntu $(first) $(first).defn.ooo \
		10.54.0.0/16 10.55.0.0/16
	$(first) $(MAKE) cilium cname="katt-$(first)" cid=113 copt="--inherit-ca a"

c-plus:
	$(first) cilium clustermesh enable --context $@ --service-type LoadBalancer
	$(first) cilium clustermesh status --context $@ --wait
	$(MAKE) $(first)-{a,b}-mesh

%-ssh:
	ssh $(first)-prv.dev.defn.net -A

secrets:
	-$(k) create ns cert-manager
	-pass CF_API_TOKEN | perl -pe 's{\s+$$}{}' | $(kc) create secret generic cert-manager-secret --from-file=CF_API_TOKEN=/dev/stdin
	-$(k) create ns traefik
	-pass SECRET | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-secret --from-file=SECRET=/dev/stdin
	-pass CLIENT_SECRET | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-client-secret --from-file=CLIENT_SECRET=/dev/stdin
	-pass CLIENT_ID | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-client-id --from-file=CLIENT_ID=/dev/stdin
	-pass COOKIE_DOMAINS | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-cookie-domains --from-file=COOKIE_DOMAINS=/dev/stdin
	-pass DOMAINS | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-domains --from-file=DOMAINS=/dev/stdin
	-pass AUTH_HOST | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-auth-host --from-file=AUTH_HOST=/dev/stdin

%-add:
	-argocd cluster rm https://$(first).defn.ooo:6443
	argocd cluster add $(first)

%-mp:
	-m delete --purge $(first)
	m launch -c 2 -d 20G -m 4096M -n $(first)
	ssh-add -L | m exec $(first) -- tee -a .ssh/authorized_keys
	m exec $(first) -- sudo mount bpffs -t bpf /sys/fs/bpf
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | m exec $(first) -- sudo apt-key add -
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | m exec $(first) -- sudo tee /etc/apt/sources.list.d/tailscale.list
	m exec $(first) -- sudo apt-get update
	m exec $(first) -- sudo apt-get install tailscale
	m exec $(first) -- sudo tailscale up --accept-dns=false
	m exec $(first) -- sudo apt install -y --install-recommends linux-generic-hwe-20.04 postgresql postgresql-contrib
	m restart $(first)

consul:
	helm install consul hashicorp/consul --set global.name=consul --set server.replicas=1
	$(k) rollout status statefulset.apps/consul-server

vault:
	helm install vault hashicorp/vault --set global.name=consul --set server.replicas=1

once:
	helm repo add cilium https://helm.cilium.io/ --force-update
	helm repo add hashicorp https://helm.releases.hashicorp.com --force-update
	helm repo update

cilium:
	$(MAKE) cilium-install

cilium-install:
	cilium install --version v1.10.0 --kube-proxy-replacement=strict --config tunnel=vxlan --cluster-name "$(cname)" --cluster-id "$(cid)" --ipam=kubernetes $(copt)
	cilium status --wait
	$(ks) rollout status deployment/cilium-operator
	cilium hubble enable --ui
	$(ks) rollout status deployment/hubble-relay
	$(ks) rollout status deployment/hubble-ui

cilium-clustermesh:
	cilium clustermesh enable --service-type LoadBalancer
	cilium clustermesh status --wait

mean:
	$(MAKE) kind name=mean
	argocd cluster add kind-mean --name mean --upsert

dev:
	$(MAKE) kind name=mean
	$(MAKE) kind name=kind
	$(MAKE) argocd
	$(MAKE) secrets
	$(MAKE) argocd-init
	argocd cluster add kind-mean --name mean --upsert
	$(MAKE) dev-deploy

kind:
	-kind delete cluster --name=$(name)
	kind create cluster --config=etc/$(name).yaml --name=$(name)

argocd:
	kustomize build https://github.com/letfn/katt-argocd/base | $(k) apply -f -
	for deploy in dex-server redis repo-server server; \
		do $(ka) rollout status deploy/argocd-$${deploy}; done
	$(ka) rollout status statefulset/argocd-application-controller

argocd-init:
	$(MAKE) argocd-port &
	sleep 10
	$(MAKE) argocd-login
	$(MAKE) argocd-passwd

dev-deploy:
	$(k) apply -f https://raw.githubusercontent.com/amanibhavam/katt-spiral/master/dev.yaml
	argocd app wait dev --sync
	argocd app wait dev--kind --sync
	argocd app wait dev--mean --sync
	argocd app wait kind--cert-manager --health
	argocd app wait kind--traefik --health
	$(MAKE) ready

ready:
	while ! argocd app wait kind--site --health; do sleep 1; done

argocd-login:
	@echo y | argocd login localhost:8080 --insecure --username admin --password "$(shell $(ka) get -o json secret/argocd-initial-admin-secret | jq -r '.data.password | @base64d')"

argocd-passwd:
	@argocd account update-password --account admin --current-password "$(shell $(ka) get -o json secret/argocd-initial-admin-secret | jq -r '.data.password | @base64d')" --new-password admin

argocd-ignore:
	argocd proj add-orphaned-ignore default cilium.io CiliumIdentity

argocd-port:
	$(ka) port-forward svc/argocd-server 8080:443

bash:
	curl -o bash -sSL https://github.com/robxu9/bash-static/releases/download/5.1.004-1.2.2/bash-linux-x86_64
	chmod 755 bash

kumactl-cli:
	curl -L https://kuma.io/installer.sh | sh -
	rsync -ia kuma-1.2.1/bin/* /usr/local/bin/
	rm -rf kuma-1.2.1

kuma-cp:
	- (sleep 10; kumactl config control-planes add --address http://127.0.0.1:5666 --name local --overwrite) & 
	env KUMA_MODE=zone KUMA_MULTIZONE_ZONE_NAME=defm KUMA_MULTIZONE_ZONE_GLOBAL_ADDRESS=grpcs://100.111.69.60:5685 KUMA_API_SERVER_HTTP_PORT=5666 kuma-cp run

kuma-dp:
	kumactl generate dataplane-token > .kuma-dp.token
	-kuma-dp run --dataplane-file etc/kuma-dp.yaml --dataplane-token-file=.kuma-dp.token
	rm -f .kuma-dp.token

cilium-cli:
	$(MAKE) cilium-cli-$(shell uname -s)
	$(MAKE) hubble-cli-$(shell uname -s)

cilium-cli-Linux:
	curl -sLLO https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
	sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
	rm cilium-linux-amd64.tar.gz

hubble-cli-Linux:
	export HUBBLE_VERSION=$(shell curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
	curl -sSLO "https://github.com/cilium/hubble/releases/download/v0.8.0/hubble-linux-amd64.tar.gz"
	sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
	rm -f hubble-linux-amd64.tar.gz	

cilium-cli-Darwin:
	curl -sLLO https://github.com/cilium/cilium-cli/releases/latest/download/cilium-darwin-amd64.tar.gz
	sudo tar xzvfC cilium-darwin-amd64.tar.gz /usr/local/bin
	rm cilium-darwin-amd64.tar.gz

hubble-cli-Darwin:
	export HUBBLE_VERSION=$(shell curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
	curl -sSLO "https://github.com/cilium/hubble/releases/download/v0.8.0/hubble-darwin-amd64.tar.gz"
	sudo tar xzvfC hubble-darwin-amd64.tar.gz /usr/local/bin
	rm -f hubble-darwin-amd64.tar.gz	

vault-agent:
	helm repo add hashicorp https://helm.releases.hashicorp.com --force-update
	helm repo update
	helm install vault hashicorp/vault --values k/vault-agent/values.yaml

gloo:
	#glooctl install knative -g
	glooctl install gateway --values k/gloo/values.yaml --with-admin-console
	kubectl patch settings -n gloo-system default -p '{"spec":{"linkerd":true}}' --type=merge
	curl -sSL https://raw.githubusercontent.com/solo-io/gloo/v1.2.9/example/petstore/petstore.yaml | $(k) apply -f -
	glooctl add route --path-exact /all-pets --dest-name default-petstore-8080 --prefix-rewrite /api/pets

external-secrets:
	$(kx) apply -f k/external-secrets/crds
	kustomize build --enable-alpha-plugins k/external-secrets | $(kx) apply -f -

home:
	kustomize build --enable-alpha-plugins k/home | $(k) apply -f -

registry: # Run a local registry
	k apply -f k/registry.yaml

gojo todo toge:
	bin/cluster $(shell host $(first).defn.ooo | awk '{print $$NF}') defn $(first)
	$(first) $(MAKE) cilium

