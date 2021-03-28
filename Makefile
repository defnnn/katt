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

menu:
	@perl -ne 'printf("%20s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

tamago:
	ssh-keygen -f ~/.ssh/id_rsa -N ''
	mkdir -p ~/.kube
	k3sup install --cluster --local --no-extras --local-path ~/.kube/tamago.conf \
		--context tamago --tls-san tamago.defn.jp --host tamago.defn.jp \
		--k3s-extra-args "--node-taint CriticalAddonsOnly=true:NoExecute --disable=servicelb --disable=traefik --disable-network-policy --flannel-backend=none"
	perl -pe 's{127.0.0.1}{tamago.defn.jp}' -i ~/.kube/tamago.conf
	tamago $(MAKE) wait
	for a in tamago ya ki; do \
		cat ~/.ssh/id_rsa.pub | ssh $$a.defn.jp -o StrictHostKeyChecking=false tee -a .ssh/authorized_keys; \
		ssh $$a sudo mount bpffs /sys/fs/bpf -t bpf; \
		done
	$(MAKE) yaki

yaki:
	for a in ya ki; do \
		k3sup join --user app --host $$a.defn.jp --server-user app --server-host tamago.defn.jp; \
		done

katt: # Install all the goodies
	$(MAKE) linkerd wait
	$(MAKE) $(PET)-traefik wait
	$(MAKE) vault-agent gloo cert-manager flagger kruise wait
	$(MAKE) $(PET)-site

one:
	$(MAKE) linkerd-trust-anchor
	$(MAKE) tamago
	$(MAKE) -j 2 tatami ryokan
	ryokan linkerd multicluster link --cluster-name ryokan | tatami $(k) apply -f -
	tatami linkerd multicluster link --cluster-name tatami | ryokan $(k) apply -f -
	tatami $(k) apply -k "github.com/linkerd/website/multicluster/west/"
	ryokan $(k) apply -k "github.com/linkerd/website/multicluster/east/"
	for a in tatami ryokan; do \
		$$a $(MAKE) wait; \
		$$a $(k) label svc -n test podinfo mirror.linkerd.io/exported=true; \
		$$a $(k) label svc -n test frontend mirror.linkerd.io/exported=true; \
		$$a $(k) apply -f k/linkerd/$$a.yaml; \
		done

wait:
	sleep 5
	while [[ "$$($(k) get -o json --all-namespaces pods | jq -r '(.items//[])[].status | "\(.phase) \((.containerStatuses//[])[].ready)"' | sort -u | grep -v 'Succeeded false')" != "Running true" ]]; do \
		$(k) get --all-namespaces pods; sleep 5; echo; done

vault-agent:
	helm repo add hashicorp https://helm.releases.hashicorp.com --force-update
	helm repo update
	helm install vault hashicorp/vault --values k/vault-agent/values.yaml

linkerd-trust-anchor:
	step certificate create root.linkerd.cluster.local root.crt root.key \
  	--profile root-ca --no-password --insecure --force
	step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
		--profile intermediate-ca --not-after 8760h --no-password --insecure \
		--ca root.crt --ca-key root.key --force
	mkdir -p etc
	mv -f issuer.* root.* etc/

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

mp:
	$(MAKE) linkerd-trust-anchor
	ssh-keygen -y -f ~/.ssh/id_rsa -N ''
	m delete --all --purge
	$(MAKE) defn0 defn1
	defn0 linkerd multicluster link --cluster-name defn0 | defn1 $(k) apply -f -
	defn1 linkerd multicluster link --cluster-name defn1 | defn0 $(k) apply -f -
	defn0 $(k) apply -k "github.com/linkerd/website/multicluster/west/"
	defn1 $(k) apply -k "github.com/linkerd/website/multicluster/east/"
	for a in defn0 defn1; do \
		$$a $(MAKE) wait; \
		$$a linkerd mc check; \
		$$a $(k) label svc -n test podinfo mirror.linkerd.io/exported=true; \
		$$a $(k) label svc -n test frontend mirror.linkerd.io/exported=true; \
		done

mp-*:
	$(MAKE) $(first)
	bin/m-join-k3s $(first) defn0

once:
	helm repo add cilium https://helm.cilium.io/ --force-update
	helm  repo update

mp-linkerd:
	linkerd check --pre
	linkerd install \
		--identity-trust-anchors-file etc/root.crt \
		--identity-issuer-certificate-file etc/issuer.crt \
  	--identity-issuer-key-file etc/issuer.key | perl -pe 's{enforced-host=.*}{enforced-host=}' | $(k) apply -f -
	linkerd check
	linkerd multicluster install | $(k) apply -f -
	linkerd multicluster check
	$(MAKE) wait

mp-cilium:
	#kubectl create -f https://raw.githubusercontent.com/cilium/cilium/v1.9/install/kubernetes/quick-install.yaml
	helm install cilium cilium/cilium --version 1.9.5 \
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
	#kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.9/install/kubernetes/quick-hubble-install.yaml
	helm upgrade cilium cilium/cilium --version 1.9.5 \
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

defn0 defn1:
	-m delete --purge $@
	m launch -c 2 -d 50G -m 2048M --network en0 -n $@
	cat ~/.ssh/id_rsa.pub | m exec $@ -- tee -a .ssh/authorized_keys
	m exec $@ git clone https://github.com/amanibhavam/homedir
	m exec $@ homedir/bin/copy-homedir
	m exec $@ -- sudo mount bpffs -t bpf /sys/fs/bpf
	mkdir -p ~/.config/$@/tailscale
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
