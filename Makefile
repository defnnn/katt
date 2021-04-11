SHELL := /bin/bash

first = $(word 1, $(subst -, ,$@))
second = $(word 2, $(subst -, ,$@))

k := kubectl
ks := kubectl -n kube-system
kt := kubectl -n traefik
kg := kubectl -n gloo-system
kx := kubectl -n external-secrets
kc := kubectl -n cert-manager
kld := kubectl -n linkerd
klm := kubectl -n linkerd-multicluster
kd := kubectl -n external-dns

bridge := en0

cilium := 1.10.0-rc0

menu:
	@perl -ne 'printf("%20s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

katt: # Install all the goodies
	$(MAKE) linkerd wait
	$(MAKE) $(PET)-traefik wait
	$(MAKE) vault-agent gloo cert-manager flagger kruise wait
	$(MAKE) $(PET)-site

vault-agent:
	helm repo add hashicorp https://helm.releases.hashicorp.com --force-update
	helm repo update
	helm install vault hashicorp/vault --values k/vault-agent/values.yaml

flagger:
	kustomize build https://github.com/fluxcd/flagger/kustomize/linkerd?ref=v1.6.2 | kubectl apply -f -

kruise:
	kustomize build k/kruise | $(k) apply -f -

%-traefik:
	cue export --out yaml c/.$(first).cue c/$(first).cue c/traefik.cue > k/traefik/config/traefik.yaml
	$(kt) apply -f k/traefik/crds
	kustomize build k/traefik | linkerd inject --ingress - | $(kt) apply -f -

gloo:
	#glooctl install knative -g
	glooctl install gateway --values k/gloo/values.yaml --with-admin-console
	kubectl patch settings -n gloo-system default -p '{"spec":{"linkerd":true}}' --type=merge
	curl -sSL https://raw.githubusercontent.com/solo-io/gloo/v1.2.9/example/petstore/petstore.yaml | linkerd inject - | $(k) apply -f -
	glooctl add route --path-exact /all-pets --dest-name default-petstore-8080 --prefix-rewrite /api/pets

external-secrets:
	$(kx) apply -f k/external-secrets/crds
	kustomize build --enable_alpha_plugins k/external-secrets | $(kx) apply -f -

cert-manager:
	kustomize build --enable_alpha_plugins k/cert-manager | $(k) apply -f -

home:
	kustomize build --enable_alpha_plugins k/home | $(k) apply -f -

%-site:
	kustomize build k/site | linkerd inject - | $(k) apply -f -
	$(k) apply -f k/site/$(first).yaml

registry: # Run a local registry
	k apply -f k/registry.yaml

wait:
	sleep 5
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u | grep -v 'Succeeded false')" != "Running true" ]]; do \
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

linkerd-trust-anchor:
	step certificate create root.linkerd.cluster.local root.crt root.key \
  	--profile root-ca --no-password --insecure --force
	step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
		--profile intermediate-ca --not-after 8760h --no-password --insecure \
		--ca root.crt --ca-key root.key --force
	mkdir -p etc
	mv -f issuer.* root.* etc/

mp:
	$(MAKE) linkerd-trust-anchor
	touch ~/.ssh/id_rsa
	ssh-keygen -y -f ~/.ssh/id_rsa -N ''
	m delete --all --purge
	$(MAKE) west

mpp:
	$(MAKE) east
	west linkerd multicluster link --cluster-name west | east $(k) apply -f -
	east linkerd multicluster link --cluster-name east | west $(k) apply -f -
	$(MAKE) mp-join

mp-join:
	west $(k) apply -k "github.com/linkerd/website/multicluster/west/"
	east $(k) apply -k "github.com/linkerd/website/multicluster/east/"
	for a in west east; do \
		$$a $(MAKE) wait; \
		$$a $(k) label svc -n test podinfo mirror.linkerd.io/exported=true; \
		$$a $(k) label svc -n test frontend mirror.linkerd.io/exported=true; \
		done

mp-join-test:
	west linkerd mc check
	east linkerd mc check
	west kn test exec -c nginx -it $$(west kn test get po -l app=frontend --no-headers -o custom-columns=:.metadata.name) -- /bin/sh -c "curl http://podinfo-east:9898"
	east kn test exec -c nginx -it $$(east kn test get po -l app=frontend --no-headers -o custom-columns=:.metadata.name) -- /bin/sh -c "curl http://podinfo-west:9898"

mp-*:
	$(MAKE) $(first)
	bin/m-join-k3s $(first) west

once:
	helm repo add cilium https://helm.cilium.io/ --force-update
	helm repo update

linkerd:
	$(MAKE) mp-linkerd

mp-linkerd:
	linkerd check --pre
	linkerd install \
		--identity-trust-anchors-file etc/root.crt \
		--identity-issuer-certificate-file etc/issuer.crt \
  	--identity-issuer-key-file etc/issuer.key | perl -pe 's{enforced-host=.*}{enforced-host=}' | $(k) apply -f -
	while true; do if linkerd check; then break; fi; sleep 10; done
	linkerd multicluster install | $(k) apply -f -
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
	helm upgrade cilium cilium/cilium --version $(cilium) \
   --namespace kube-system \
   --reuse-values \
   --set hubble.listenAddress=":4244" \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true
	-$(MAKE) wait
	sleep 30
	$(MAKE) wait

mp-cilium-test:
	kubectl create ns cilium-test
	kubectl apply -n cilium-test -f https://raw.githubusercontent.com/cilium/cilium/v1.9/examples/kubernetes/connectivity-check/connectivity-check.yaml

mp-hubble-ui:
	kubectl port-forward -n kube-system svc/hubble-ui --address 0.0.0.0 --address :: 12000:80

mp-hubble-relay:
	kubectl port-forward -n kube-system svc/hubble-relay --address 0.0.0.0 --address :: 4245:80

mp-hubble-status:
	hubble --server localhost:4245 status

mp-hubble-observe:
	hubble --server localhost:4245 observe -f

west east:
	-m delete --purge $@
	m launch -c 2 -d 20G -m 2048M --network $(bridge) -n $@
	cat ~/.ssh/id_rsa.pub | m exec $@ -- tee -a .ssh/authorized_keys
	m exec $@ git clone https://github.com/amanibhavam/homedir
	m exec $@ homedir/bin/copy-homedir
	m exec $@ -- sudo mount bpffs -t bpf /sys/fs/bpf
	mkdir -p ~/.pasword-store/config/$@/tailscale
	sudo multipass mount $$HOME/.config/$@/tailscale $@:/var/lib/tailscale
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | m exec $@ -- sudo apt-key add -
	curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | m exec $@ -- sudo tee /etc/apt/sources.list.d/tailscale.list
	m exec $@ -- sudo apt-get update
	m exec $@ -- sudo apt-get install tailscale
	m exec $@ -- sudo tailscale up
	bin/m-install-k3s $@ $@
	$@ $(MAKE) mp-cilium
	$@ $(MAKE) mp-linkerd
	$@ k apply -f nginx.yaml
