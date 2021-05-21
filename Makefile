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
kld := kubectl -n linkerd
kd := kubectl -n external-dns
ka := kubectl -n argocd
kn := kubectl -n

bridge := en0

cilium := 1.10.0

menu:
	@perl -ne 'printf("%20s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

vault-agent:
	helm repo add hashicorp https://helm.releases.hashicorp.com --force-update
	helm repo update
	helm install vault hashicorp/vault --values k/vault-agent/values.yaml

flagger:
	kustomize build https://github.com/fluxcd/flagger/kustomize/linkerd?ref=v1.6.2 | kubectl apply -f -

kruise:
	kustomize build k/kruise | $(k) apply -f -

gloo:
	#glooctl install knative -g
	glooctl install gateway --values k/gloo/values.yaml --with-admin-console
	kubectl patch settings -n gloo-system default -p '{"spec":{"linkerd":true}}' --type=merge
	curl -sSL https://raw.githubusercontent.com/solo-io/gloo/v1.2.9/example/petstore/petstore.yaml | linkerd inject - | $(k) apply -f -
	glooctl add route --path-exact /all-pets --dest-name default-petstore-8080 --prefix-rewrite /api/pets

external-secrets:
	$(kx) apply -f k/external-secrets/crds
	kustomize build --enable-alpha-plugins k/external-secrets | $(kx) apply -f -

home:
	kustomize build --enable-alpha-plugins k/home | $(k) apply -f -

registry: # Run a local registry
	k apply -f k/registry.yaml

wait:
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u | grep -v 'Succeeded false' | grep -v 'cilium-node-init' )" != "Running true" ]]; do \
		$(k) get --all-namespaces pods; sleep 5; echo; done

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

%-reset:
		ssh $(first).defn.in sudo /usr/local/bin/k3s-uninstall.sh

gojo todo toge:
	bin/cluster $(shell host $(first).defn.in | awk '{print $$NF}') defn $(first)
	$(first) $(MAKE) cilium wait
	$(first) $(MAKE) $(first)-inner

nue gyoku maki miwa:
	bin/cluster $(shell host $(first).defn.in | awk '{print $$NF}') ubuntu $(first)
	$(first) $(MAKE) cilium wait
	$(first) $(MAKE) $(first)-inner

ken:
	-k3s-uninstall.sh
	ssh-add -L | sudo tee ~root/.ssh/authorized_keys
	mkdir -p ~/.kube
	bin/cluster $(shell tailscale ip | grep ^100) root $(first)
	ln -nfs $@.conf ~/.kube/config
	sudo cp ~/.ssh/authorized_keys ~root/.ssh/authorized_keys
	$(first) $(MAKE) cilium
	$(first) $(MAKE) $(first)-inner

katt:
	$(MAKE) cert-manager wait
	$(MAKE) mp-linkerd wait
	$(MAKE) cluster-linkerd-lb wait
	$(MAKE) $(first)-traefik
	$(MAKE) $(first)-site

west:
	m delete --all --purge
	$(first) $(MAKE) $(first)-mp

east:
	$(MAKE) $(first)-mp

todo-% nue-%:
	$(first) linkerd multicluster link --cluster-name $(first) | $(second) $(k) apply -f -
	$(second) linkerd multicluster link --cluster-name $(second) | $(first) $(k) apply -f -
	$(first) $(MAKE) wait
	$(second) $(MAKE) wait
	$(first) linkerd mc check
	$(second) linkerd mc check

katt-nue:
	$(second) linkerd multicluster link --cluster-name $(second) | $(first) $(k) apply -f -
	$(first) $(MAKE) wait
	$(first) linkerd mc check

katt-curl:
	katt exec -ti -c hello "$$(katt k get pod -l app=hello --no-headers -o custom-columns=:.metadata.name | head -1)" -- /bin/sh -c "while true; do curl -s http://hello:8080; done" | grep --line-buffered Hostname

katt-curl-nue:
	katt exec -ti -c hello "$$(katt k get pod -l app=hello --no-headers -o custom-columns=:.metadata.name | head -1)" -- /bin/sh -c "curl -s http://hello-nue:8080" | grep Hostname

nue-stat:
	nue linkerd viz stat --from deploy/linkerd-gateway --from-namespace linkerd-multicluster deploy/hello

mp-join-test:
	west kn test exec -c nginx -it $$(west kn test get po -l app=frontend --no-headers -o custom-columns=:.metadata.name) -- /bin/sh -c "curl http://podinfo-east:9898"
	east kn test exec -c nginx -it $$(east kn test get po -l app=frontend --no-headers -o custom-columns=:.metadata.name) -- /bin/sh -c "curl http://podinfo-west:9898"

%-mp:
	-m delete --purge $(first)
	m launch -c 2 -d 20G -m 2048M -n $(first)
	ssh-add -L | m exec $(first) -- tee -a .ssh/authorized_keys
	m exec $(first) -- sudo mount bpffs -t bpf /sys/fs/bpf
	mkdir -p ~/.pasword-store/config/$(first)/tailscale
	sudo multipass mount $$HOME/.config/$(first)/tailscale $(first):/var/lib/tailscale
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | m exec $(first) -- sudo apt-key add -
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | m exec $(first) -- sudo tee /etc/apt/sources.list.d/tailscale.list
	m exec $(first) -- sudo apt-get update
	m exec $(first) -- sudo apt-get install tailscale
	m exec $(first) -- sudo tailscale up
	bin/m-install-k3s $(first) $(first)
	$(first) $(MAKE) $(first)-inner

%-inner:
	$(MAKE) argocd
	$(MAKE) argocd-init
	$(k) apply -f k/traefik/crds
	$(k) apply -f katt.yaml
	$(MAKE) linkerd
	$(MAKE) $(first)-site

%-site:
	-pass CF_API_TOKEN | perl -pe 's{\s+$$}{}' | $(kc) create secret generic cert-manager-secret --from-file=CF_API_TOKEN=/dev/stdin
	cd k/site && make $(first)-gen
	$(first) kustomize build k/site/$(first) | $(first) linkerd inject - | $(first) $(k) apply -f -

once:
	helm repo add cilium https://helm.cilium.io/ --force-update
	helm repo update

init:
	$(MAKE) linkerd-trust-anchor

linkerd-trust-anchor:
	step certificate create root.linkerd.cluster.local root.crt root.key \
  	--profile root-ca --no-password --insecure --force
	step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
		--profile intermediate-ca --not-after 8760h --no-password --insecure \
		--ca root.crt --ca-key root.key --force
	mkdir -p etc
	mv -f issuer.* root.* etc/

linkerd:
	$(MAKE) mp-linkerd
	$(MAKE) cluster-linkerd-lb
	$(MAKE) linkerd-viz

linkerd-viz:
	linkerd viz install | perl -pe 's{enforced-host=.*}{enforced-host=}' | $(k) apply -f -

mp-linkerd:
	linkerd check --pre
	linkerd install \
		--identity-trust-anchors-file etc/root.crt \
		--identity-issuer-certificate-file etc/issuer.crt \
  	--identity-issuer-key-file etc/issuer.key | $(k) apply -f -
	while true; do if linkerd check; then break; fi; sleep 10; done

cluster-linkerd-lb:
	linkerd multicluster install | $(k) apply -f -
	sleep 5
	-linkerd multicluster check
	$(MAKE) wait

cluster-linkerd-np:
	linkerd multicluster install --gateway-service-type NodePort | $(k) apply -f -
	-linkerd multicluster check
	$(MAKE) wait

cilium:
	$(MAKE) mp-cilium

mp-cilium:
	helm install cilium cilium/cilium --version $(cilium) \
   --namespace kube-system \
   --set nodeinit.enabled=true \
   --set kubeProxyReplacement=partial \
   --set hostServices.enabled=false \
   --set externalIPs.enabled=true \
   --set nodePort.enabled=true \
   --set hostPort.enabled=true \
   --set bpf.masquerade=false \
   --set image.pullPolicy=IfNotPresent \
   --set ipam.mode=kubernetes \
	 --set nodeinit.restartPods=true \
	 --set operator.replicas=1
	for deploy in cilium-operator; \
		do $(ks) rollout status deploy/$${deploy}; done
	helm upgrade cilium cilium/cilium --version $(cilium) \
   --namespace kube-system \
   --reuse-values \
   --set hubble.listenAddress=":4244" \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true
	for deploy in hubble-relay hubble-ui; \
		do $(ks) rollout status deploy/$${deploy}; done
	for deploy in coredns local-path-provisioner metrics-server; \
		do $(ks) rollout status deploy/$${deploy}; done

argocd:
	-$(k) create ns argocd
	kustomize build https://github.com/letfn/katt-argocd/base | $(ka) apply -f -
	for deploy in dex-server redis repo-server server; \
		do $(ka) rollout status deploy/argocd-$${deploy}; done
	$(ka) rollout status statefulset/argocd-application-controller

argocd-init:
	$(MAKE) argocd-port &
	sleep 10
	$(MAKE) argocd-login
	$(MAKE) argocd-passwd

argocd-login:
	@echo y | argocd login localhost:8080 --insecure --username admin --password "$(shell $(ka) get -o json secret/argocd-initial-admin-secret | jq -r '.data.password | @base64d')"

argocd-passwd:
	@argocd  account update-password --account admin --current-password "$(shell $(ka) get -o json secret/argocd-initial-admin-secret | jq -r '.data.password | @base64d')" --new-password admin

argocd-ignore:
	argocd proj add-orphaned-ignore default cilium.io CiliumIdentity

argocd-port:
	$(ka) port-forward svc/argocd-server 8080:443

sealed-secret-key:
	 @$(ks) get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml

sealed-secret-make:
	@$(kn) "$(ns)" create secret generic "$(secret)" --dry-run=client --from-file=$(name)=/dev/stdin -o json | kubeseal

bash:
	curl -o bash -sSL https://github.com/robxu9/bash-static/releases/download/5.1.004-1.2.2/bash-linux-x86_64
	chmod 755 bash
