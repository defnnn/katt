_workers: [...int] | *[0]

kind:       "Cluster"
apiVersion: "kind.x-k8s.io/v1alpha4"

featureGates: RemoveSelfLink: false 
featureGates: EphemeralContainers: true

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

			image: "kindest/node:v1.20.2@sha256:8f7ea6e7642c0da54f04a7ee10431549c0257315b3a634f6ef2fecaaedb19bab"

			extraMounts: [
				{
					hostPath:      "/sys/fs/bpf",
					containerPath: "/sys/fs/bpf"
				},
				{
					hostPath:      "/var/run/docker.sock"
					containerPath: "/var/run/docker.sock"
				},
				{
					hostPath:      "/tmp/mnt"
					containerPath: "/mnt"
				},
			]
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
