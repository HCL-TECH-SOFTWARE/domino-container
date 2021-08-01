#!/bin/sh

# The permissions the local provisioner sets are more restictive in the current versions.
# The root of the volumes are always owned by root and only root as the owner has permissions.
# Usually a provisioner allows to use fgroup to specify the group owning the mounted volume.
# But this isn't inplemented in the simple local storage driver k3s uses.

# An alternate way would be an init container to change the permissions.


# Patch provioner's config map
kubectl get -n kube-system cm/local-path-config -o yaml | sed 's/mkdir -m 0700/mkdir -m 0777/g' | kubectl apply -f -

# Restart provisioner and get status
kubectl rollout restart deploy/local-path-provisioner -n kube-system
kubectl rollout status deploy/local-path-provisioner -n kube-system

