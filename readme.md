> Important: If any commands require sudo privileges and your user don't have passwordless sudo enabled, copy the commands from makefile and run in your favorite shell.

> Important: This was setup as proof-of-concept of a production system. For local development purpose please use 1 control-plane and 2 worker node configuration and RAM usage will be under control (assuming the system has atleast 5gb ram available).

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

## Create KinD cluster

Create KinD cluster with 

```
make cluster-create
```

## Delete KinD cluster

Destroy KinD cluster with, (NFS storage contents won't be deleted)

```
delete-cluster
```

### Common Troubleshooting:

If cluster creation process is taking a long time at "Starting control-plane" step and exits with error similar to,

```
The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get "http://localhost:10248/healthz": dial tcp [::1]:10248: connect: connection refused.
```

It means you probably have some physical or virtual network settings that KinD is not working with. For example kvm bridge network requires you to use a bridge network and bridge slave network based on the physical network interface. KinD does not support this scenario. After reverting to default network connection based on physical network device it completed the setup process.

Kubernetes version 1.21 node images were used to setup this cluster. Provide your customized name in makefile commands for create and delete cluster section. Clusters with same name can't exist. 

If you need to use different version kubernetes node image, be aware of kubernetes feature gates and their default value according to version. If any feature gate default value is true, KinD config doesn't support setting it true again using cluster config yaml files. For example ```TTLAfterFinished``` is ```true``` by default in 1.21 but false in previous versions. So specifying it as ```true``` again for 1.21 cluster version in ```featureGates``` section in ```cluster/kind-config.yaml``` won't work.

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

## Delete cluster network

Delete Calico CNI with,

```
make cluster-network-delete
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

## Create NFS storage class and Metallb loadbalancer

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

Apply the manifest files using kustomization,

```
make cluster-config
```

## Delete NFS storage class and Metallb loadbalancer

Delete the manifest files using kustomization,

```
make cluster-config-delete
```

## Apply Elasticsearch-Fluentd-Kibana (EFK) log management system manifests

EFK stack is used without ssl configuration and custom index, filter, tag rewrite rules. This is to simulate logging scenario in production environment. Custom configration can be applied to fluentd daemonset using configmap. Maybe in future a generic config file will be included. Elasticsearch runs as statefulset and as long as they are not deleted using manifest files from cluster, they will retain data in NFS share location and persist between any pod restart or reschedule. Kibana runs on nodeport ```30003``` so make sure to enable the port from any control-plane node in KinD cluster config.

Apply manifests with,

```
make cluster-logging
```

## Delete Elasticsearch-Fluentd-Kibana (EFK)

Delete EFK with, (Persistant volume will be renamed with prefix ```archieved``` and data will not be available unless copied manually to new volumes)

```
make cluster-logging-delete
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

## Delete Prometheus-Grafana monitoring system

Delete prometheus, grafana, alertmanager and custom CRDs with,

```
make cluster-monitoring-delete
make cluster-monitoring-uninstall
```

## Service mesh

### TODO

## Docker image registry

### TODO

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