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

katt-%:
	$(MAKE) reset-$(second)
	$(MAKE) launch-$(second)
	$(MAKE) install-cilium
	$(MAKE) install-argocd
	$(MAKE) add-$(second)

kitt-%:
	$(MAKE) reset-$(second)
	$(MAKE) launch-$(second)
	$(MAKE) add-$(second)

registry:
	-k3d registry create hub.defn.ooo --port 5000

immanent:
	k3d cluster delete $(first)
	k3d cluster create $(first) --config etc/k3d-$(first).yaml
	ktx mini
	-argocd --core cluster rm https://$(first).defn.ooo:6443 >/dev/null 2>&1
	argocd --core cluster add -y --name $(first) k3d-$(first)
	ktx k3d-$(first)
	$(MAKE) install-secrets

boot-dev-kind:
	-kind delete cluster --name=mean
	kind create cluster --config=etc/kind-mean.yaml --name=mean
	-kind delete cluster --name=kind
	kind create cluster --config=etc/kind-kind.yaml --name=kind
	$(MAKE) dev prefix=kind

install-cilium:
	kustomize build https://github.com/amanibhavam/spiral-$(shell uname -n | cut -d. -f1)/cilium | $(k) apply -f -

launch-%:
	bin/cluster \
		$(shell host $(second).defn.ooo | awk '{print $$NF}') \
		$(shell host $(second).defn.ooo | awk '{print $$NF}') \
		$(shell host $(second).defn.ooo | awk '{print $$NF}') \
		ubuntu $(second) $(second).defn.ooo \
		$(shell $(MAKE) -s $(second)-network)
	-(cd etc && $(second) ks create secret generic cilium-ca --from-file=./ca.crt --from-file=./ca.key)

%-launch:
	$(MAKE) launch-$(first)

%-launch-plain:
	bin/cluster-plain \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		$(shell host $(first).defn.ooo | awk '{print $$NF}') \
		ubuntu $(first) $(first).defn.ooo \
		$(shell $(MAKE) $(first)-network)
	-(cd etc && $(first) ks create secret generic cilium-ca --from-file=./ca.crt --from-file=./ca.key)

config-%:
	bin/config \
		$(shell host $(second).defn.ooo | awk '{print $$NF}') \
		$(shell host $(second).defn.ooo | awk '{print $$NF}') \
		$(shell host $(second).defn.ooo | awk '{print $$NF}') \
		ubuntu $(second) $(second).defn.ooo

%-join:
	bin/join \
		ubuntu $(shell host $(first).defn.ooo | awk '{print $$NF}') \
		ubuntu $(shell host $(second).defn.ooo | awk '{print $$NF}')

%-cilium:
	true

%-network:
	@echo 10.200.0.0/16 10.101.0.0/16

kitt-network:
	@echo 10.201.0.0/16 10.98.0.0/16

katt-network:
	@echo 10.201.0.0/16 10.99.0.0/16

mini-network:
	@echo 10.201.0.0/16 10.101.0.0/16

imac-network:
	@echo 10.202.0.0/16 10.102.0.0/16

mbpro-network:
	@echo 10.203.0.0/16 10.103.0.0/16

mbair-network:
	@echo 10.208.0.0/16 10.105.0.0/16

test-%:
	true

status-%:
	true

test-mbpro test-imac test-mini test-mbair test-katt test-kitt:
	-$(second) delete ns cilium-test
	$(second) cilium connectivity test
	-$(second) delete ns cilium-test

status-mbpro status-imac status-mini status-mbair status-katt status-kitt:
	$(second) cilium status

reset-%:
	-ssh "$(second).defn.ooo" /usr/local/bin/k3s-uninstall.sh
	-ssh "$(second).defn.ooo" sudo apt install -y postgresql postgresql-contrib
	-echo "alter role postgres with password 'postgres'" | ssh "$(second).defn.ooo" sudo -u postgres psql
	-echo "drop database kubernetes" | ssh "$(second).defn.ooo" sudo -u postgres psql

%-reset:
	$(MAKE) reset-$(first)

reboot-%:
	ssh "$(second).defn.ooo" sudo reboot

%-reboot:
	$(MAKE) reboot-$(second)

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

add-%:
	-argocd --core cluster rm https://$(second).defn.ooo:6443
	argocd --core cluster add -y $(second)

%-add:
	$(MAKE) add-$(first)

argocd-install:
	kustomize build https://github.com/letfn/katt-argocd/base | $(k) apply -f -
	kns argocd
	for deploy in dex-server redis repo-server server; \
		do $(ka) rollout status deploy/argocd-$${deploy}; done
	$(ka) rollout status statefulset/argocd-application-controller

reboot-%:
	$(MAKE) $(second)-reset
	-$(MAKE) $(second)-reboot &
	sleep 30
	ping $(second).defn.ooo

boot-%:
	$(MAKE) $(second)-reset
	$(MAKE) $(second)-launch
	$(MAKE) $(second)-add

boot-kitt boot-katt:
	$(MAKE) $(second)-reset
	$(MAKE) $(second)-launch-plain

boot:
	$(MAKE) boot-kitt
	$(MAKE) boot-katt
	ktx katt
	$(MAKE) dev

install-tools:
	-sudo apt install -y postgresql
	for a in kustomize kubectl kubectx k9s k3sup argo argocd; do \
		asdf plugin-add $$a || true; \
		asdf install $$a; done

install-argocd:
	$(MAKE) argocd-install
	$(MAKE) argocd-change-passwd

install-secrets:
	$(MAKE) secrets

argocd-passwd:
	$(ka) get -o json secret/argocd-initial-admin-secret | jq -r '.data.password | @base64d'

argocd-change-passwd:
	$(ka) patch secret argocd-secret -p \
		'{"stringData": { "admin.password": "$$2a$$10$$3sQFra.ZmAz88EhVIxtd6uKBgxcLNYjKBR2SoPGV2ifqiG6.oMiqm", "admin.passwordMtime": "2021-08-29T20:01:0" }}'

bash:
	curl -o bash -sSL https://github.com/robxu9/bash-static/releases/download/5.1.004-1.2.2/bash-linux-x86_64
	chmod 755 bash

kumactl:
	kumactl config control-planes add --name=katt --address=http://127.0.0.1:5681 --overwrite

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

fmt:
	black --quiet -c pyproject.toml $(shell git ls-files | grep 'py$$') app/Tiltfile
	isort --quiet $(shell git ls-files | grep 'py$$')
	git diff

first_ = $(word 1, $(subst _, ,$@))
second_ = $(word 2, $(subst _, ,$@))

warm:
	docker pull "$(shell cat params.yaml | yq -r .base_upstream_source)$(variant)"
	docker tag "$(shell cat params.yaml | yq -r .base_upstream_source)$(variant)" "$(shell cat params.yaml | yq -r .base_source)$(variant)"
	docker push "$(shell cat params.yaml | yq -r .base_source)$(variant)"

submit:
	$(MAKE) submit_base
	$(MAKE) submit_{app,ci}
	$(MAKE) submit_{aws,terraform,cdktf}

cue: o/argo.yaml
	#git diff o/argo.yaml

o/argo.yaml: argo.cue schema.cue
	cue eval --out yaml > o/argo.yaml

submit_%: o/argo.yaml
	argo submit --log -f params.yaml --entrypoint build-$(second_) o/argo.yaml

multipass-set:
	sudo multipass set local.driver=virtualbox
	sudo multipass set local.bridged-network=en0
	sudo multipass set local.privileged-mounts=true
	sudo multipass set client.gui.autostart=false

multipass-reload:
	$(MAKE) multipass-set
	-sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist
	sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist

multipass-reset:
	-multipass delete --all --purge
	$(MAKE) multipass-reload

multipass:
	multipass launch -c 4 -m 8G -d 200G -n primary --bridged
