_workers: [...int] | *[0]

kind:       "Cluster"
apiVersion: "kind.x-k8s.io/v1alpha4"

networking: {
	disableDefaultCNI: true
	podSubnet:         _networking.podSubnet
	serviceSubnet:     _networking.serviceSubnet
}

nodes: [
	for n in _workers {
		{
			if n == 0 {
				role: "control-plane"

				kubeadmConfigPatches: [
					"""
          kind: InitConfiguration
          nodeRegistration:
            kubeletExtraArgs:
              node-labels: \"index=\(n)\"

          """,
				]

				extraPortMappings: [
					{
						containerPort: 80
						hostPort:      80
						listenAddress: "169.254.32.1"
						protocol:      "TCP"
					},
					{
						containerPort: 443
						hostPort:      443
						listenAddress: "169.254.32.1"
						protocol:      "TCP"
					},
				]
			}
			if n > 0 {
				role: "worker"
				kubeadmConfigPatches: [
					"""
          kind: JoinConfiguration
          nodeRegistration:
            kubeletExtraArgs:
              node-labels: \"index=\(n)\"

          """,
				]
			}

			image: "kindest/node:v1.19.1@sha256:98cf5288864662e37115e362b23e4369c8c4a408f99cbc06e58ac30ddc721600"

			extraMounts: [{
				hostPath:      "/var/run/docker.sock"
				containerPath: "/var/run/docker.sock"
			}]

		}
	},
]

containerdConfigPatches: [
	"""
		[plugins."io.containerd.grpc.v1.cri".containerd]
		disable_snapshot_annotations = true

		[plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
		endpoint = ["http://169.254.32.1:5000"]
		""",
]

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
