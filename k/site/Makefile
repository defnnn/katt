SHELL := /bin/bash

first = $(word 1, $(subst -, ,$@))
second = $(word 2, $(subst -, ,$@))

%-gen:
	mkdir -p $(first)
	cue export --out yaml data/$(first).cue cue/kustomization.cue > $(first)/kustomization.yaml
	cue export --out yaml data/$(first).cue cue/patch-certificate.cue | tail -n +2 > $(first)/patch-certificate.yaml
	cue export --out yaml data/$(first).cue cue/patch-cluster-issuer.cue | tail -n +2 > $(first)/patch-cluster-issuer.yaml

