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
		for t in _builds {t},
		for t in _templates {t},
	]

	securityContext: runAsNonRoot: false
}

for l in layers {
	_builds: "\(l)": {}
}

_builds: [NAME=string]: {
	name: "build-\(NAME)"
	steps: [[_build_step]]

	_build_step: {
		name:     "build-\(NAME)"
		template: "kaniko-build"
		arguments: parameters: _build_params
	}

	_build_params: [
		{
			name:  "repo"
			value: "{{workflow.parameters.repo}}"
		}, {
			name:  "revision"
			value: "{{workflow.parameters.revision}}"
		}, {
			name:  "source"
			value: "{{workflow.parameters.\(NAME)_source}}{{workflow.parameters.variant}}\(_source_suffix)"

			_source_suffix: string | *"-{{workflow.parameters.version}}"
			if NAME == "base" {
				_source_suffix: ""
			}
		}, {
			name:  "destination"
			value: "{{workflow.parameters.\(NAME)_destination}}{{workflow.parameters.variant}}-{{workflow.parameters.version}}"
		}, {
			name:  "dockerfile"
			value: "{{workflow.parameters.\(NAME)_dockerfile}}"
		},
	]
}

_templates: "kaniko-build": {
	name: "kaniko-build"
	inputs: parameters: _params
	inputs: artifacts: [ _git_source]
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

	_params: [
		for p in [ "repo", "revision", "source", "destination", "dockerfile"] {
			name: p
		},
		{
			name:  "insecure_pull"
			value: "--insecure-pull"
		}]

	_git_source: {
		name: "source"
		path: "/src"
		git: {
			repo:     "{{inputs.parameters.repo}}"
			revision: "{{inputs.parameters.revision}}"
		}
	}
}
