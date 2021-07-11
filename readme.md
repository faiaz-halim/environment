> Important: If any commands require sudo privileges and your user don't have passwordless sudo enabled, copy the commands from makefile and run in your favorite shell.

> Important: This was setup as proof-of-concept of a production system. For local development purpose please use 1 control-plane and 2 worker node configuration and RAM usage will be under control (assuming the system has atleast 5gb ram available).

> Important: For any custom configurations rename ```.env.template``` to ```.env``` and use it with ```Makefile```. Look for commands with ```custom``` name.

## Install Docker

Install Docker with

```
make install-docker
```

## Install KinD

Install KinD with

```
make install-kind
```

## Private image registry

If you are bootstrapping KinD cluster with more than 100 docker.io image pulls in a span of 6 hours, you'll hit docker pull limit (since image is being pulled anonymously so 200 pulls per logged in session won't apply). Another case is you may want to load custom images directly into cluster without going through a docker image registry. Note ```imagePullPolicy``` settings and it shouldn't be ```Always``` or images shouldn't use ```latest``` tag.

In this case easiest solution is pull all docker images to local pc and load into kind cluster with, 

```
kind load docker-image IMAGE_NAME:TAG
```

The longest and safest (I trust you to ```NOT``` use self signed cert and distribute them using ```kind-config.yaml``` in any kind of production environment) in long run is to host a private registry with Harbor and host all necessary images in it. If you have patience to upload all necessary images for your cluster to run in private registry then ```Congratulations!!``` you are one step closer to creating an air-gapped secure cluster. Add the domain name for Harbor setup against your ip (not localhost) in ```/etc/hosts``` file.

The commands are given in order from Harbor folder, please update with your own value if needed,

```
make harbor-cert
make harbor-download
make harbor-yml
make harbor-prepare
make harbor-install
```

Stop and start Harbor containers if needed,

```
make harbor-down
make harbor-up
```

Update ```private_repo``` variable in ```.env`` and run following command to pull, tag and push necessary docker images to your private registry,

```
make cluster-private-images
```

To use images from private image registry, look for commands with ```custom``` mode.

## Create KinD cluster

If you are not using private image registries like harbor, please delete following sections from ```cluster/kind-config.yaml```,

```
  extraMounts:
    - containerPath: /etc/ssl/certs
      hostPath: harbor/certs
```

```
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."harbor.localdomain.com:9443"]
    endpoint = ["https://harbor.localdomain.com:9443"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.localdomain.com".tls]
      cert_file = "/etc/ssl/certs/harbor.localdomain.com.cert"
      key_file  = "/etc/ssl/certs/harbor.localdomain.com.key"
```

Create KinD cluster with 

```
make cluster-create
```

For any custom settings, private image registry, run following first,

```
make custom-mode
```

Update ```custom/cluster/kind-config.yaml``` with your certificate and key name, mount point. Create cluster with,

```
make cluster-create-custom
```

## Delete KinD cluster

Destroy KinD cluster with, (NFS storage contents won't be deleted)

```
delete-cluster
```

## Regenerate kubeconfig

With every system reboot the exposed api server endpoint and certificate in kubeconfig will change. Regenerate kubeconfig of current cluster for kubectl with, 

> This will not work for HA settings. The haproxy loadbalancer container don't get certificate update this way. Copying api address ip and certificate over to loadbalancer docker container process is still ```TODO```. For HA KinD cluster you have to destroy cluster every time before shutdown and recreate it later.

```
make kubectl-config
```

### Common Troubleshooting:

If cluster creation process is taking a long time at "Starting control-plane" step and exits with error similar to,

```
The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get "http://localhost:10248/healthz": dial tcp [::1]:10248: connect: connection refused.
```

It means you probably have some physical or virtual network settings that KinD is not working with. For example kvm bridge network requires you to use a bridge network and bridge slave network based on the physical network interface. KinD does not support this scenario. After reverting to default network connection based on physical network device it completed the setup process.

Kubernetes version 1.21 node images were used to setup this cluster. Provide your customized name in makefile commands for create and delete cluster section. Clusters with same name can't exist. 

If you need to use different version kubernetes node image, be aware of kubernetes feature gates and their default value according to version. If any feature gate default value is true, KinD config doesn't support setting it true again using cluster config yaml files. For example ```TTLAfterFinished``` is ```true``` by default in 1.21 but false in previous versions. So specifying it as ```true``` again for 1.21 cluster version in ```featureGates``` section in ```cluster/kind-config.yaml``` won't work.

If docker restarts for any reason please look if loadbalancer container is autostarted. Otherwise you can't regenerate kubeconfig for kubectl in case it is unable to connect to kind cluster.

## Create cluster network

Create cluster network using CNI manifests,

```
make cluster-network
```

Here Calico manifest is used with BGP peering and pod CIDR ```192.168.0.0/16``` settings. For updated version or any change in manifest, download from,

```
curl https://docs.projectcalico.org/manifests/calico.yaml -O
```

All Calico pods must be running before installing other components in cluster. If you want to use different CNI, download the manifest and replace filename in makefile.

Run following command to let calico manifest pull from private registry,

```
make cluster-network-custom
```

If pod description shows error like ```x509: certificate signed by unknown authority``` make sure your domain and ca certificates are available inside KinD nodes (docker containers) and containerd CRI can access them.

If pod description shows error like ```liveness and readiness probes failed``` make sure any pod ip is not overlapping your LAN network ip range.

## Delete cluster network

Delete Calico CNI with,

```
make cluster-network-delete
```

On custom mode,

```
cluster-network-custom-delete
```

## Install NFS server

If NFS server isn't installed run command to install and configure NFS location,

```
make install-nfs-server
```

Add your location with this format in ```/etc/exports``` file,

```
YOUR_NFS_PATH *(rw,sync,no_root_squash,insecure,no_subtree_check)
```

Restart NFS server to apply changes,

```
sudo systemctl restart nfs-server.service
```

## Create NFS storage class, Metallb loadbalancer, dashboard, metric server, serviceaccount

```k8s-sigs.io/nfs-subdir-external-provisioner``` storage provisioner is used to better simulate production scenario where usually log, metric, data storage are centralized and retained even if containers get destroyed and rescheduled. 

Rename ```nfs-deploy.yaml.template``` to ```nfs-deploy.yaml``` and update following values with your own, (make sure folder write permission is present)

```
YOUR_NFS_SHARE_PATH
YOUR_NFS_SERVER_IP
```

Metallb loadbalancer is used to simulate production scenario where different services will be assigned ip addresses or domain names from cloud based loadbalancer services. On premises this is generally handled by a loadbalancer like haproxy which loadbalances and routes traffic to appropriate nodes. Metallb loadbalancer is not strictly required to run the stack, simple nodeport service will work for development purpose as well.

Rename ```metallb-config.yaml.template``` to ```metallb-config.yaml``` and update following values with your own,

```
IP_RANGE_START
IP_RANGE_END
```

Kubernetes dashboard, metrics server and cluster admin role serviceaccount manifests are added. Please don't use this serviceacount for anything remotely related to production systems.

Apply the manifest files using kustomization,

```
make cluster-config
```

For custom images, assuming you already pushed images with proper tags in your private registry, (make sure you made updates to ```custom``` folder files)

```
make cluster-config-custom
```

Access dashboard using proxy and service account token,

```
kubectl proxy
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
make get-token
```

## Delete NFS storage class, Metallb loadbalancer, dashboard, metric server, serviceaccount

Delete the manifest files using kustomization,

```
make cluster-config-delete
```

On custom mode,

```
make cluster-config-custom-delete
```

## Apply Elasticsearch-Fluentd-Kibana (EFK) log management system manifests

EFK stack is used without ssl configuration and custom index, filter, tag rewrite rules. This is to simulate logging scenario in production environment. Custom configration can be applied to fluentd daemonset using configmap. Maybe in future a generic config file will be included. Elasticsearch runs as statefulset and as long as they are not deleted using manifest files from cluster, they will retain data in NFS share location and persist between any pod restart or reschedule. Kibana runs on nodeport ```30003``` so make sure to enable the port from any control-plane node in KinD cluster config.

Apply manifests with,

```
make cluster-logging
```

On custom mode with private image registry

```
make cluster-logging-custom
```

## Delete Elasticsearch-Fluentd-Kibana (EFK)

Delete EFK with, (Persistant volume will be renamed with prefix ```archieved``` and data will not be available unless copied manually to new volumes)

```
make cluster-logging-delete
```

On custom mode,

```
make cluster-logging-custom-delete
```

## Apply Prometheus-Grafana monitoring system

Prometheus, grafana, alertmanager and custom CRDs associated with them are exactly taken as is from ```kube-prometheus``` project (```https://github.com/prometheus-operator/kube-prometheus```). Please note the kubernetes compatibility matrix and download appropriate release for your version. This system uses release-0.8. Before applying manifests, go to ```manifests/grafana-service.yaml``` and add nodeport to service. 

Rename ```pv.yaml.template``` to ```pv.yaml``` and update following values with your own, (make sure folder write permission is present)

```
YOUR_NFS_SHARE_PATH
YOUR_NFS_SERVER_IP
```

Create a new file with following contents ```manifests/grafana-credentials.yaml``` to have persistent ```admin:admin@123``` credentials applied if grafana pod is restarted.

```
apiVersion: v1
kind: Secret
metadata:
  name: grafana-credentials
  namespace: monitoring
data:
  user: YWRtaW4=
  password: YWRtaW5AMTIz
```

Add env in ```manifests/grafana-deployment.yaml``` to use persistent credentials,

```
        env:
        - name: GF_SECURITY_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: grafana-credentials
              key: user
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-credentials
              key: password
```

Replace following section in ```manifests/grafana-deployment.yaml``` with next one,

```
      - emptyDir: {}
        name: grafana-storage
```

```
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-storage-pv-claim
```

Apply setup prerequisites with,

```
make cluster-monitoring-setup
```

Apply manifests with,

```
make cluster-monitoring
```

For private image registry in custom mode,

```
make cluster-monitoring-setup-custom
make cluster-monitoring-custom
```

## Delete Prometheus-Grafana monitoring system

Delete prometheus, grafana, alertmanager and custom CRDs with,

```
make cluster-monitoring-delete
make cluster-monitoring-uninstall
```

For custom mode,

```
make cluster-monitoring-custom-delete
make cluster-monitoring-custom-uninstall
```

## Service mesh

Istio is used as service mesh. Install istioctl operator with,

```
make cluster-istioctl-install
```

Create istio-system namespace and install istio core components with demo profile. Modify ```istioctl install``` for enabling any other modules or configurations,

```
make cluster-istio-install
```

Install istio components with private image registry,

```
make cluster-istio-custom-install
```

### Optional: Enable addons

Apply grafana, prometheus, kiali, jaeger manifests to trace service communication and see service mesh metrics. Expose dashboards grafana and kiali dashboards to nodeport. In ```istio/samples/addons/grafana.yaml``` update grafana service with following,

```
spec:
  type: NodePort
  ports:
    - name: service
      port: 3000
      protocol: TCP
      targetPort: 3000
      nodePort: 30004
```

In ```istio/samples/addons/kiali.yaml``` update kiali service with following,

```
spec:
  type: NodePort
  ports:
  - name: http
    protocol: TCP
    port: 20001
    nodePort: 30005
  - name: http-metrics
    protocol: TCP
    port: 9090
```

Apply manifests with, (if any error comes up for first run, please run it again)

```
make cluster-istio-addons
```

For private image registries, apply the service port changes in files first, then run following,

```
make custom-mode
make cluster-istio-custom-addons
```

If any error comes up for first run, apply manifests again with,

```
make cluster-istio-custom-addons-apply
```

## Delete Prometheus-Grafana monitoring system

Delete istio components, addons and custom CRDs with,

```
make cluster-istio-delete
```

For custom mode,

```
make cluster-istio-custom-delete
```

## Helm install

To install Helm v3 run the following to install the operator and then run ```helm repo add repo_name repo_address``` to add repo and ```helm install name repo_name```,

```
make cluster-helm-install
```

## Gitlab

### TODO

## Jenkins

### TODO

## ArgoCD

### TODO

## Vault

### TODO

## Cluster backup, audit & security

### TODO

## SAST/DAST tool integration

### TODO

## Test automation

### TODO

## Full gitops pipeline

### TODO

## Cilium & Hubble

### Will be explored later as it conflicts with coredns pods in calico cni
