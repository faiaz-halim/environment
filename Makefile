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

cluster-network:
	kubectl apply -f cluster/calico.yaml

cluster-network-delete:
	kubectl delete -f cluster/calico.yaml

install-nfs-server:
	sudo apt install nfs-kernel-server
	sudo vim /etc/exports

cluster-config:
	kubectl apply -k ./cluster

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

delete-cluster:
	kind delete cluster --name gitops