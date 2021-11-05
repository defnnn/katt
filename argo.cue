package katt

apiVersion: "argoproj.io/v1alpha1"
kind:       "Workflow"
metadata: generateName: "katt-kaniko-build-"

let layers = [ "base", "app", "ci", "aws", "terraform", "cdktf"]

spec: {
	arguments: parameters: [
		for p in [ "repo", "revision", "version", "variant"] {
			name: p
		},
		for l in layers for s in ["source", "destination", "dockerfile"] {
			name: "\(l)_\(s)"
		},
	]

	templates: [
		for ts in _builds for t in ts {t},
		for t in _templates {t},
	]

	_builds: [
		for l in layers {
			#Build & {"\(l)": {}}
		},
	]
}

spec: securityContext: runAsNonRoot: false

_templates: #Template & {"kaniko-build": {
	container: {
		image: "gcr.io/kaniko-project/executor"
		args: [
			"--context=/src",
			"--dockerfile={{inputs.parameters.dockerfile}}",
			"--destination={{inputs.parameters.destination}}",
			"--build-arg",
			"IMAGE={{inputs.parameters.source}}",
			"--reproducible",
			"--cache",
			"--cache-copy-layers",
			"--insecure",
			"{{inputs.parameters.insecure_pull}}",
		]
	}

	inputs: parameters: [
		for p in [ "repo", "revision", "source", "destination", "dockerfile"] {
			name: p
		},
		{
			name:  "insecure_pull"
			value: "--insecure-pull"
		},
	]
}}
