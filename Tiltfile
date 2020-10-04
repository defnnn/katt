k8s_yaml(kustomize('./k/g2048'))

k8s_resource('g2048', port_forwards=8080)

home_yaml = local('kustomize build --enable_alpha_plugins k/home')
k8s_yaml(home_yaml)

watch_file('./k/home')
