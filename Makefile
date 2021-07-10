update:
	git pull

install-docker:
	sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io
	sudo usermod -aG docker $$USER

install-kind:
	curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
	chmod +x ./kind
	mv ./kind /usr/local/bin
	which kind

cluster-create:
	kind create cluster --config cluster/kind-config.yaml --name gitops

kubectl-install:
	curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	kubectl version --client

kubectl-config:
	kind export kubeconfig --name gitops

cluster-network:
	sed -i 's/k8s,bgp"/k8s,bgp"\n            - name: IP_AUTODETECTION_METHOD\n              value: "interface=eth.*"/' cluster/calico.yaml
	kubectl apply -f cluster/calico.yaml

cluster-network-image:
	sed -i 's/image: docker.io/image: harbor.localdomain.com:9443\/kind/g' cluster/calico.yaml

cluster-network-custom: cluster-network-image cluster-network

cluster-network-delete:
	kubectl delete -f cluster/calico.yaml

install-nfs-server:
	sudo apt install nfs-kernel-server
	sudo vim /etc/exports

cluster-config:
	kubectl apply -k ./cluster

cluster-dashboard-image:
	sed -i 's/image: kubernetesui/image: harbor.localdomain.com:9443\/kind\/kubernetesui/g' cluster/dashboard.yaml

cluster-config-custom: cluster-dashboard-image cluster-config

cluster-config-delete:
	kubectl delete -k ./cluster

cluster-logging:
	kubectl apply -k ./efk

cluster-logging-delete:
	kubectl delete -k ./efk

cluster-monitoring-setup:
	kubectl apply -f prom/manifests/setup
	kubectl wait deploy/prometheus-operator -n monitoring --for condition=available

cluster-monitoring:
	kubectl apply -f prom/manifests

cluster-monitoring-delete:
	kubectl delete -f prom/manifests

cluster-monitoring-uninstall:
	kubectl delete -f prom/manifests/setup

cluster-istioctl-install:
	curl -L https://istio.io/downloadIstio | sh -
	mv istio-1.10.2 istio
	sudo cp istio/bin/istioctl /usr/local/bin

cluster-istio-install:
	kubectl create namespace istio-system
	istioctl install --set profile=demo -y

cluster-istio-addons:
	kubectl apply -f istio/samples/addons
	kubectl rollout status deployment/kiali -n istio-system

cluster-istio-delete:
	kubectl delete -f istio/samples/addons
	kubectl delete namespace istio-system

cluster-helm-install:
	curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

cluster-cilium-install:
	kubectl apply -f cilium-hubble/chaining.yaml
	helm repo add cilium https://helm.cilium.io/
	helm install cilium cilium/cilium --version 1.9.8 \
		--namespace=kube-system \
		--set cni.chainingMode=generic-veth \
		--set cni.customConf=true \
		--set cni.configMap=cni-configuration \
		--set tunnel=disabled \
		--set masquerade=false \
		--set enableIdentityMark=false

cluster-cilium-install-full:
	helm install cilium cilium/cilium --version 1.9.8 \
		--namespace kube-system \
		--set nodeinit.enabled=true \
		--set kubeProxyReplacement=partial \
		--set hostServices.enabled=false \
		--set externalIPs.enabled=true \
		--set nodePort.enabled=true \
		--set hostPort.enabled=true \
		--set bpf.masquerade=false \
		--set image.pullPolicy=IfNotPresent \
		--set ipam.mode=kubernetes

cluster-cilium-test:
	kubectl create ns cilium-test
	kubectl apply -n cilium-test -f https://raw.githubusercontent.com/cilium/cilium/v1.9/examples/kubernetes/connectivity-check/connectivity-check.yaml

cluster-cilium-test-delete:
	kubectl delete ns cilium-test

cluster-cilium-delete:
	helm uninstall cilium -n kube-system

delete-cluster:
	kind delete cluster --name gitops