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

%-launch:
	bin/cluster \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		ubuntu $(first) $(first).defn.ooo \
		$(shell $(MAKE) $(first)-network)

%-join:
	bin/join \
		ubuntu $(shell host $(first).defn.ooo | awk '{print $$NF}') \
		ubuntu $(shell host $(second).defn.ooo | awk '{print $$NF}')

%-cilium:
	true

%-network:
	@echo 10.200.0.0/16 10.101.0.0/16

mini-network:
	@echo 10.201.0.0/16 10.101.0.0/16

imac-network:
	@echo 10.202.0.0/16 10.102.0.0/16

mbpro-network:
	@echo 10.203.0.0/16 10.103.0.0/16

mbair-network:
	@echo 10.204.0.0/16 10.104.0.0/16


mbpro-cilium:
	$(first) cilium -n cilium clustermesh enable --context $(first) --service-type LoadBalancer
	$(first) cilium -n cilium clustermesh status --context $(first) --wait

imac-cilium:
	$(first) cilium -n cilium clustermesh enable --context $(first) --service-type LoadBalancer
	$(first) cilium -n cilium clustermesh status --context $(first) --wait

mini-cilium:
	$(first) cilium -n cilium clustermesh enable --context $(first) --service-type LoadBalancer
	$(first) cilium -n cilium clustermesh status --context $(first) --wait

mbair-cilium:
	$(first) cilium -n cilium clustermesh enable --context $(first) --service-type LoadBalancer
	$(first) cilium -n cilium clustermesh status --context $(first) --wait

test-%:
	true

status-%:
	true

test-mbpro test-imac test-mini test-mbair:
	-$(second) delete ns cilium-test
	$(second) cilium -n cilium connectivity test
	-$(second) delete ns cilium-test

status-mbpro status-imac status-mini status-mbair:
	$(second) cilium -n cilium status

%-reset:
	-ssh "$(first).defn.ooo" /usr/local/bin/k3s-uninstall.sh
	-ssh "$(first).defn.ooo" sudo apt install -y postgresql postgresql-contrib
	-echo "alter role postgres with password 'postgres'" | ssh "$(first).defn.ooo" sudo -u postgres psql
	-echo "drop database kubernetes" | ssh "$(first).defn.ooo" sudo -u postgres psql

%-reboot:
	ssh "$(first).defn.ooo" sudo reboot &

%-mesh:
	$(first) cilium -n cilium clustermesh connect --context $(first) --destination-context $(second)
	$(first) cilium -n cilium clustermesh status --context $(first) --wait

%-connectivity:
	-$(first) delete ns cilium-test
	-$(second) delete ns cilium-test
	cilium -n cilium connectivity test --context $(first) --multi-cluster $(second)
	-$(first) delete ns cilium-test
	-$(second) delete ns cilium-test

secrets:
	-$(k) create ns cert-manager
	-pass CF_API_TOKEN | perl -pe 's{\s+$$}{}' | $(kc) create secret generic cert-manager-secret --from-file=CF_API_TOKEN=/dev/stdin
	-$(k) create ns traefik
	-pass CF_API_TOKEN | perl -pe 's{\s+$$}{}' | $(kt) create secret generic cloudflare --from-file=dns-token=/dev/stdin
	-pass SECRET | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-secret --from-file=SECRET=/dev/stdin
	-pass CLIENT_SECRET | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-client-secret --from-file=CLIENT_SECRET=/dev/stdin
	-pass CLIENT_ID | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-client-id --from-file=CLIENT_ID=/dev/stdin
	-pass COOKIE_DOMAINS | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-cookie-domains --from-file=COOKIE_DOMAINS=/dev/stdin
	-pass DOMAINS | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-domains --from-file=DOMAINS=/dev/stdin
	-pass AUTH_HOST | perl -pe 's{\s+$$}{}' | $(kt) create secret generic traefik-forward-auth-auth-host --from-file=AUTH_HOST=/dev/stdin

%-add:
	-argocd --core cluster rm https://$(first).defn.ooo:6443
	argocd --core cluster add -y $(first)

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
	m exec $(first) -- sudo apt install -y --install-recommends postgresql postgresql-contrib
	m restart $(first)

argocd-install:
	kustomize build https://github.com/letfn/katt-argocd/base | $(k) apply -f -
	kns argocd
	for deploy in dex-server redis repo-server server; \
		do $(ka) rollout status deploy/argocd-$${deploy}; done
	$(ka) rollout status statefulset/argocd-application-controller

boot-kind:
	-kind delete cluster --name=mean
	kind create cluster --config=etc/kind-mean.yaml --name=mean
	-kind delete cluster --name=kind
	kind create cluster --config=etc/kind-kind.yaml --name=kind
	$(MAKE) dev prefix=kind

boot-k3d:
	-k3d cluster delete mean
	-k3d cluster delete kind
	k3d cluster create mean --config etc/k3d-mean.yaml
	k3d cluster create kind --config etc/k3d-kind.yaml
	$(MAKE) dev prefix=k3d

boot-%:
	$(MAKE) $(second)-reset
	$(MAKE) $(second)-launch
	$(MAKE) $(second)-add

dev:
	$(MAKE) argocd-install
	$(MAKE) argocd-change-passwd
	argocd --core cluster add $(prefix)-kind --name kind --upsert --yes
	argocd --core cluster add $(prefix)-mean --name mean --upsert --yes
	$(MAKE) secrets
	$(MAKE) dev-deploy

deploy-%:
	$(k) apply -f https://raw.githubusercontent.com/amanibhavam/deploy/master/$(second).yaml

argocd-login:
	@echo y | argocd login localhost:8080 --insecure --username admin --password "$(shell $(ka) get -o json secret/argocd-initial-admin-secret | jq -r '.data.password | @base64d')"

argocd-passwd:
	$(ka) get -o json secret/argocd-initial-admin-secret | jq -r '.data.password | @base64d'

argocd-change-passwd:
	$(ka) patch secret argocd-secret -p \
		'{"stringData": { "admin.password": "$$2a$$10$$3sQFra.ZmAz88EhVIxtd6uKBgxcLNYjKBR2SoPGV2ifqiG6.oMiqm", "admin.passwordMtime": "2021-08-29T20:01:0" }}'
	#$(MAKE) argocd-port &
	#sleep 10
	#$(MAKE) argocd-login
	#@argocd account update-password --account admin --current-password "$(shell $(ka) get -o json secret/argocd-initial-admin-secret | jq -r '.data.password | @base64d')" --new-password adminadmin
	#-pkill -f 'argocd port-forward svc/argocd-server 8080:443'

argocd-ignore:
	argocd --core proj add-orphaned-ignore default cilium.io CiliumIdentity

argocd-port:
	$(ka) port-forward svc/argocd-server 8080:443

bash:
	curl -o bash -sSL https://github.com/robxu9/bash-static/releases/download/5.1.004-1.2.2/bash-linux-x86_64
	chmod 755 bash

kumactl:
	kumactl config control-planes add --name=katt --address=http://127.0.0.1:5681 --overwrite

kumactl-cli:
	curl -L https://kuma.io/installer.sh | sh -
	rsync -ia kuma-1.3.0/bin/* /usr/local/bin/
	rm -rf kuma-1.3.0

kuma-cp:
	- (sleep 10; kumactl config control-planes add --address http://127.0.0.1:5666 --name local --overwrite) & 
	env KUMA_MODE=zone KUMA_MULTIZONE_ZONE_NAME=defm KUMA_MULTIZONE_ZONE_GLOBAL_ADDRESS=grpcs://100.101.28.35:5685 KUMA_API_SERVER_HTTP_PORT=5666 kuma-cp run

kuma-dp:
	kumactl generate dataplane-token > .kuma-dp.token
	-(sleep 10; rm -vf .kuma-dp.token) &
	kuma-dp run --dataplane-file etc/kuma-dp.yaml --dataplane-token-file=.kuma-dp.token

cilium-cli:
	$(MAKE) cilium-cli-$(shell uname -s)
	$(MAKE) hubble-cli-$(shell uname -s)

cilium-cli-Linux:
	curl -sLLO https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
	sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
	rm cilium-linux-amd64.tar.gz

hubble-cli-Linux:
	curl -sSLO "https://github.com/cilium/hubble/releases/download/v0.8.2/hubble-linux-amd64.tar.gz"
	sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
	rm -f hubble-linux-amd64.tar.gz	

cilium-cli-Darwin:
	curl -sLLO https://github.com/cilium/cilium-cli/releases/latest/download/cilium-darwin-amd64.tar.gz
	sudo tar xzvfC cilium-darwin-amd64.tar.gz /usr/local/bin
	rm cilium-darwin-amd64.tar.gz

hubble-cli-Darwin:
	curl -sSLO "https://github.com/cilium/hubble/releases/download/v0.8.2/hubble-darwin-amd64.tar.gz"
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

images:
	docker exec $(name)-control-plane crictl images

images-save:
	cat etc/images.txt | grep -v ^IMAGE | awk '{print $$1 ":" $$2}' \
		| while read -r a; do \
			echo "$$a"; mkdir -p "load/$${a/://}"; \
			docker pull "$$a"; docker save "$$a" -o "load/$${a/://}/image"; \
		done

images-load:
	cat etc/images.txt | grep -v ^IMAGE | awk '{print $$1 ":" $$2}' \
		| while read -r a; do \
			echo "$$a"; \
			kind load image-archive "load/$${a/://}/image" --name $(name); \
		done
