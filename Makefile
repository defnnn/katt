SHELL := /bin/bash

.PHONY: cutout

menu:
	@perl -ne 'printf("%10s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

cutout:
	rm -rf cutout
	cookiecutter --no-input --directory t/python gh:defn/cutouts \
		organization="Cuong Chi Nghiem" \
		project_name="katt" \
		repo="defn/katt" \
		repo_cache="defn/cache"
	rsync -ia cutout/. .
	rm -rf cutout
	git difftool --tool=vimdiff -y
