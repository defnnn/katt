package katt

#Build: [NAME=string]: {
	name: "build-\(NAME)"
	steps: [[_build_step]]

	_build_step: {
		name:     "build-\(NAME)"
		template: "kaniko-build"
		arguments: parameters: _build_params
	}

	_build_params: [{
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
	}]
}

#Template: [NAME=string]: {
	name: NAME
	container: {...}
	inputs: artifacts: [ _git_source]
	inputs: parameters: [...]

	_git_source: {
		name: "source"
		path: "/src"
		git: {
			repo:     "{{inputs.parameters.repo}}"
			revision: "{{inputs.parameters.revision}}"
		}
	}
}
