#!/bin/bash
# Tests creating a cluster with a registry,
# building a container in that cluster,
# then running that container.

set -exo pipefail

cd $(dirname $(realpath $0))
CLUSTER_NAME="kind-ctlptl-test-cluster"
ctlptl apply -f registry.yaml
ctlptl apply -f cluster.yaml

# The ko-builder runs in an image tagged with the host as visible from the local machine.
docker build -t localhost:5005/ko-builder .
docker push localhost:5005/ko-builder

# The ko-builder builds an image tagged with the host as visible from the cluster network.
HOST_FROM_CONTAINER_RUNTIME=$(ctlptl get cluster "$CLUSTER_NAME" -o template --template '{{.status.localRegistryHosting.host}}')
HOST_FROM_CLUSTER_NETWORK=$(ctlptl get cluster "$CLUSTER_NAME" -o template --template '{{.status.localRegistryHosting.hostFromClusterNetwork}}')
cat builder.yaml | \
    sed "s/HOST_FROM_CONTAINER_RUNTIME/$HOST_FROM_CONTAINER_RUNTIME/g" | \
    sed "s/HOST_FROM_CLUSTER_NETWORK/$HOST_FROM_CLUSTER_NETWORK/g" | \
    kubectl apply -f -
kubectl wait --for=condition=complete job/ko-builder --timeout=180s
cat simple-server.yaml | \
    sed "s/HOST_FROM_CONTAINER_RUNTIME/$HOST_FROM_CONTAINER_RUNTIME/g" | \
    sed "s/HOST_FROM_CLUSTER_NETWORK/$HOST_FROM_CLUSTER_NETWORK/g" | \
    kubectl apply -f -

# Check to see we started the right kubernetes version.
k8sVersion=$(ctlptl get cluster "$CLUSTER_NAME" -o go-template --template='{{.status.kubernetesVersion}}')

ctlptl delete -f cluster.yaml

if [[ "$k8sVersion" != "v1.22.15" ]]; then
    echo "Expected kubernetes version v1.22.15 but got $k8sVersion"
    exit 1
fi

echo "kind-cluster-network test passed!"
