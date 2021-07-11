#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Input repository address in ip_or_domain:port/project format"
  exit 1
fi

repo_address=$1

# Copy whole image name from manifest files and paste here 

docker_images=(
    kubernetesui/dashboard:v2.3.1
    quay.io/metallb/speaker:v0.10.2
    quay.io/metallb/controller:v0.10.2
    k8s.gcr.io/metrics-server/metrics-server:v0.5.0
    calico/node:v3.19.1
    calico/pod2daemon-flexvol:v3.19.1
    calico/cni:v3.19.1
    calico/kube-controllers:v3.19.1
    k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
    kubernetesui/metrics-scraper:v1.0.6
)

# Docker pull, tag and push to new private repository

for image in ${docker_images[@]}; do
    sh -c "docker pull $image"
    image_id=$(docker images $image --format {{.ID}})
    sh -c "docker tag $image_id $repo_address/$image"
    sh -c "docker push $repo_address/$image"
done