kind:       "Cluster"
apiVersion: "kind.x-k8s.io/v1alpha4"

networking: {
	disableDefaultCNI: true
	podSubnet:         _networking.podSubnet
	serviceSubnet:     _networking.serviceSubnet
}

nodes: [{
	role:  "control-plane"
	image: "kindest/node:v1.19.1@sha256:98cf5288864662e37115e362b23e4369c8c4a408f99cbc06e58ac30ddc721600"
	extraMounts: [{
		hostPath:      "/var/run/docker.sock"
		containerPath: "/var/run/docker.sock"
	}]
}]

kubeadmConfigPatches: [
	"""
		kind: ClusterConfiguration
		metadata:
		  name: config
		apiServer:
		  certSANs:
		  - localhost
		  - 127.0.0.1
		  - kubernetes
		  - kubernetes.default.svc
		  - kubernetes.default.svc.cluster.local
		  - kind

		""",
]
