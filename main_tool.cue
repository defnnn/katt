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

command: {
	reset: {
		setPostgresPassword: exec.Run & {
			cmd: ["ssh", config.fqdn, "sudo", "-u", "postgres", "psql", "-c", "\"alter role postgres with password 'postgres'\""]
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
