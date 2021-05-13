create:
	k create ns defn
	argocd app create guestbook --repo https://github.com/defn/katt.git --path apps --revision mp --dest-server https://kubernetes.default.svc --dest-namespace defn

sync:
	argocd app sync guestbook
