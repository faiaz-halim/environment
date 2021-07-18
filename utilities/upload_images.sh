#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Input repository address in ip_or_domain:port/project format"
  exit 1
fi

repo_address=$1

# Copy whole image name from manifest files and paste here 

docker_images=(
    calico/node:v3.19.1
    calico/pod2daemon-flexvol:v3.19.1
    calico/cni:v3.19.1
    calico/kube-controllers:v3.19.1
    k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
    quay.io/metallb/speaker:v0.10.2
    quay.io/metallb/controller:v0.10.2
    k8s.gcr.io/metrics-server/metrics-server:v0.5.0
    kubernetesui/dashboard:v2.3.1
    kubernetesui/metrics-scraper:v1.0.6
    docker.elastic.co/elasticsearch/elasticsearch:7.13.3
    busybox
    fluent/fluentd-kubernetes-daemonset:v1.13-debian-elasticsearch7-3
    docker.elastic.co/kibana/kibana:7.13.3
    quay.io/prometheus-operator/prometheus-operator:v0.47.0
    quay.io/brancz/kube-rbac-proxy:v0.8.0
    quay.io/prometheus/alertmanager:v0.21.0
    quay.io/prometheus/blackbox-exporter:v0.18.0
    jimmidyson/configmap-reload:v0.5.0
    grafana/grafana:7.5.4
    k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.0.0
    quay.io/prometheus/node-exporter:v1.1.2
    directxman12/k8s-prometheus-adapter:v0.8.4
    quay.io/prometheus/prometheus:v2.26.0
    quay.io/prometheus-operator/prometheus-config-reloader:v0.47.0
    grafana/grafana:7.4.3
    jaegertracing/all-in-one:1.20
    quay.io/kiali/kiali:v1.34
    jimmidyson/configmap-reload:v0.5.0
    prom/prometheus:v2.24.0
    istio/install-cni:1.10.2
    istio/operator:1.10.2
    istio/pilot:1.10.2
    istio/proxyv2:1.10.2
    istio/base:1.10-dev.2
    jenkins/jenkins:lts
    gitlab/gitlab-ce:latest
    minio/console:v0.7.5
    minio/operator:v4.1.3
    minio/minio:RELEASE.2021-06-17T00-10-46Z
)

# Docker pull, tag and push to new private repository

for image in ${docker_images[@]}; do
    sh -c "docker pull $image"
    image_id=$(docker images $image --format {{.ID}})
    sh -c "docker tag $image_id $repo_address/$image"
    sh -c "docker push $repo_address/$image"
done