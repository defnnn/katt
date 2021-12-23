package katt

import (
	// "strings"
	"tool/exec"
)

arg1: string @tag(arg1)
arg2: string @tag(arg2)
arg3: string @tag(arg3)
arg4: string @tag(arg4)
arg5: string @tag(arg5)
arg6: string @tag(arg6)
arg7: string @tag(arg7)
arg8: string @tag(arg8)
arg9: string @tag(arg9)

user: string @tag(user,var=username)

command: {
	install: {
		ensureConfig: exec.Run & {
			cmd: ["kubectl", "config", "set", "clusters.katttest.server", "https://1.2.3.4"]
		}
		for cfg in ["users", "clusters", "contexts"] {
			"unsetConfig\(cfg)": exec.Run & {
				cmd: ["kubectl", "config", "unset", "\(cfg).\(config.name)"]
				$after: ensureConfig
			}
		}
		deleteConfig: exec.Run & {
			cmd: ["kubectl", "config", "unset", "clusters.katttest"]
			$after: [install["unsetConfigusers"], install["unsetConfigclusters"], install["unsetConfigcontexts"]]
		}
		installK3S: exec.Run & {
			cmd: ["k3sup", "install",
				"--k3s-channel", config.channel,
				"--cluster",
				"--ip", config.ip,
				"--user", config.username,
				"--merge",
				"--context", config.name,
				"--local-path", config.kubeconfig,
				"--k3s-extra-args", "--disable traefik --node-ip=\(config.ip) --node-external-ip=\(config.ip) --advertise-address=\(config.ip) --cluster-cidr \(config.clusterCIDR) --service-cidr \(config.serviceCIDR) --tls-san \(config.fqdn) --datastore-endpoint postgres://",
			]
		}
		$after: deleteConfig
	}
	reset: {
		setPostgresPassword: exec.Run & {
			cmd: ["ssh", "-o", "StrictHostKeyChecking=false", config.fqdn, "sudo", "-u", "postgres", "psql", "-c", "\"alter role postgres with password 'postgres'\""]
		}
		uninstallK3S: exec.Run & {
			cmd: ["ssh", config.fqdn, "bash", "-c", "\"if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then /usr/local/bin/k3s-uninstall.sh; fi\""]
			$after: setPostgresPassword
		}
		dropKubernetes: exec.Run & {
			cmd: ["ssh", config.fqdn, "sudo", "-u", "postgres", "psql", "-c", "\"drop database if exists kubernetes\""]
			$after: uninstallK3S
		}
	}
}
