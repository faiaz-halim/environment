include .env

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

custom-mode:
	mkdir -p custom
	cp -r cluster custom/
	cp -r efk custom/
	cp -r prom custom/
	cp -r istio custom/
	cp -r jenkins custom/

cluster-create-custom:
	kind create cluster --config custom/cluster/kind-config.yaml --name gitops

kubectl-install:
	curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	kubectl version --client

kubectl-config:
	kind export kubeconfig --name gitops

cluster-private-images:
	./utilities/upload_images.sh ${private_repo}

cluster-network:
	sed -i 's/k8s,bgp"/k8s,bgp"\n            - name: IP_AUTODETECTION_METHOD\n              value: "interface=eth.*"/' cluster/calico.yaml
	kubectl apply -f cluster/calico.yaml

cluster-network-custom:
	sed -i 's/image: docker.io/image: ${ip_or_domain}:${port}\/${project}/g' custom/cluster/calico.yaml
	sed -i 's/k8s,bgp"/k8s,bgp"\n            - name: IP_AUTODETECTION_METHOD\n              value: "interface=eth.*"/' custom/cluster/calico.yaml
	kubectl apply -f custom/cluster/calico.yaml

cluster-network-delete:
	kubectl delete -f cluster/calico.yaml

cluster-network-custom-delete:
	kubectl delete -f custom/cluster/calico.yaml

install-nfs-server:
	sudo apt install nfs-kernel-server
	sudo vim /etc/exports

cluster-config:
	kubectl apply -k ./cluster

cluster-kustomization-image:
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/cluster/dashboard.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/cluster/nfs-deploy.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/cluster/metallb.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/cluster/metrics.yaml
	kubectl apply -k ./custom/cluster

get-dashboard-token:
	kubectl -n kubernetes-dashboard get secret $$(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"

cluster-config-custom: cluster-kustomization-image get-dashboard-token

cluster-config-delete:
	kubectl delete -k ./cluster

cluster-config-custom-delete:
	kubectl delete -k ./custom/cluster

cluster-logging:
	kubectl apply -k ./efk

cluster-logging-custom:
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/efk/elasticsearch_statefulset.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/efk/fluentd.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/efk/kibana.yaml
	kubectl apply -k ./custom/efk

cluster-logging-delete:
	kubectl delete -k ./efk

cluster-logging-custom-delete:
	kubectl delete -k ./custom/efk

cluster-monitoring-setup:
	mkdir -p nfs/grafana && chmod -R 777 nfs/grafana
	kubectl apply -f prom/manifests/setup
	kubectl wait deploy/prometheus-operator -n monitoring --for condition=available

cluster-monitoring-setup-custom:
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/setup/prometheus-operator-deployment.yaml
	sed -i 's/--prometheus-config-reloader=/--prometheus-config-reloader=${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/setup/prometheus-operator-deployment.yaml
	kubectl apply -f custom/prom/manifests/setup
	kubectl wait deploy/prometheus-operator -n monitoring --for condition=available

cluster-monitoring:
	kubectl apply -f prom/manifests

cluster-monitoring-custom:
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/alertmanager-alertmanager.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/blackbox-exporter-deployment.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/grafana-deployment.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/kube-state-metrics-deployment.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/node-exporter-daemonset.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/prometheus-adapter-deployment.yaml
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/prom/manifests/prometheus-prometheus.yaml
	kubectl apply -f custom/prom/manifests

cluster-monitoring-delete:
	kubectl delete -f prom/manifests

cluster-monitoring-uninstall:
	kubectl delete -f prom/manifests/setup

cluster-monitoring-custom-delete:
	kubectl delete -f custom/prom/manifests

cluster-monitoring-custom-uninstall:
	kubectl delete -f custom/prom/manifests/setup

cluster-istioctl-install:
	curl -L https://istio.io/downloadIstio | sh -
	mv istio-1.10.2 istio
	sudo cp istio/bin/istioctl /usr/local/bin

cluster-istio-install:
	kubectl create namespace istio-system
	istioctl install --set profile=demo -y

cluster-istio-custom-install:
	kubectl create namespace istio-system
	istioctl install --set profile=demo --set hub=${ip_or_domain}:${port}/${project}/istio -y

cluster-istio-addons:
	kubectl apply -f istio/samples/addons
	kubectl rollout status deployment/kiali -n istio-system

cluster-istio-custom-addons-manifest:
	sed -i 's/image: "/image: "${ip_or_domain}:${port}\/${project}\//g' custom/istio/samples/addons/grafana.yaml
	sed -i 's/image: "docker.io/image: "${ip_or_domain}:${port}\/${project}/g' custom/istio/samples/addons/jaeger.yaml
	sed -i 's/image: "/image: "${ip_or_domain}:${port}\/${project}\//g' custom/istio/samples/addons/kiali.yaml
	sed -i 's/image: "/image: "${ip_or_domain}:${port}\/${project}\//g' custom/istio/samples/addons/prometheus.yaml

cluster-istio-custom-addons-apply:
	kubectl apply -f custom/istio/samples/addons
	kubectl rollout status deployment/kiali -n istio-system

cluster-istio-custom-addons: cluster-istio-custom-addons-manifest cluster-istio-custom-addons-apply

cluster-istio-delete:
	kubectl delete -f istio/samples/addons
	kubectl delete namespace istio-system

cluster-istio-custom-delete:
	kubectl delete -f custom/istio/samples/addons
	kubectl delete namespace istio-system

cluster-jenkins:
	mkdir -p nfs/jenkins && chmod -R 777 nfs/jenkins
	kubectl create namespace jenkins
	kubectl apply -k ./jenkins

cluster-jenkins-custom:
	mkdir -p nfs/jenkins && chmod -R 777 nfs/jenkins
	sed -i 's/image: /image: ${ip_or_domain}:${port}\/${project}\//g' custom/jenkins/jenkins-deploy.yaml
	kubectl create namespace jenkins
	kubectl apply -k ./custom/jenkins

cluster-jenkins-delete:
	kubectl delete -k ./jenkins
	kubectl delete namespace jenkins

cluster-jenkins-custom-delete:
	kubectl delete -k ./custom/jenkins
	kubectl delete namespace jenkins

get-jenkins-token:
	kubectl exec -ti -n jenkins $$(kubectl get pods -n jenkins | grep jenkins | awk '{print $$1}') -- cat /var/jenkins_home/secrets/initialAdminPassword

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

all-custom: cluster-private-images cluster-create-custom custom-mode cluster-network-custom cluster-config-custom cluster-logging-custom cluster-monitoring-setup-custom cluster-monitoring-custom cluster-istio-custom-install cluster-istio-custom-addons cluster-istio-custom-addons-apply


