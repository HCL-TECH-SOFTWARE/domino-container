# Kubernetes Lab Instructions

Preparation

* All software is already part of the Git repository
* located in ``/local/github/domino-docker/lab``
* We can focus on installation and configuration


## Install k3s

```
curl -sfL https://get.k3s.io | sh -
```

## Check installation

```
k3s kubectl get node
```

## Install kubectrl on your machine

Instructions:

https://kubernetes.io/docs/tasks/tools/install-kubectl/


### Windows Install -- if you have curl ;-)

```
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.19.0/bin/windows/amd64/kubectl.exe
```

Or just download via browser ..

### Download your kube config from your Linux box to your machine

```
 /etc/rancher/k3s/k3s.yaml
```

For example MobaXterm --> drag & drop to file explorer.  
You an also copy the text per copy & paste into a new file.

## Export your configuration on Windows

```
set KUBECONFIG=d:\k3s\kubeconfig.yml
```

### Or use the following on Mac/Linux

```

 On Linux copy file to:

 ~/.kube/config 
 
 or 
 
 export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

## Edit the file and change the hostname from 127.0.0.1 to your server FQDN like this:

```
https://master.domino-lab.net:6443

```

## Check configuration and connection

```
kubectl.exe version

kubectl.exe get node
```

## Install Dashboard on Linux Server

This needs a couple of more complex commands

```
cd /local/github/domino-docker/lab/k3s/dashboard
```

Run the script:

```
./install.sh
```

It does the following, which you don't want to type in ;-)

```
GITHUB_URL=https://github.com/kubernetes/dashboard/releases
VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
k3s kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml
```

## Run the deploy script

```
./deploy.sh
```

It does the following:

```
k3s kubectl create -f dashboard.admin-user.yml -f dashboard.admin-user-role.ym
```


### Get the authentication token on Windows

```
kubectl -n kubernetes-dashboard describe secret admin-user-token | findstr token
```

### Get the authentication token on Linux/Mac

```
kubectl -n kubernetes-dashboard describe secret admin-user-token |grep token
```

## Connect from your machine to k3s dashboard

The proxy command creates a tunnel between your local machine and your K8s server

```
kubectl proxy
```

## Launch the Dashboard in your local browser

Yes you have to use exactly this URL on your local browser!  

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

```

This completes the K3s setup


## Now let's install Domino again on K8s

But where to do we get it from?

We have a registry to download images prepared

### First write a new secret for accessing our Docker registry 


The following is an example. The lab environment has a prepared shell script for your convenience.

Example:

```
kubectl create secret docker-registry regcred --docker-server=registry.domino-lab.net:5000 --docker-username=guest --docker-password=***

```

### Switch to the lab example files


```
cd  /local/github/domino-docker/lab/kubernetes/domino
```

### Create the registry pull secret

The following variables are already defined in your environment for your convenience

- LAB_REGISTRY_HOST
- LAB_REGISTRY_USER
- LAB_REGISTRY_PASSWORD

You just need to run the following command to create the registry pull secret


```
cd  /local/github/domino-docker/lab/kubernetes/domino
```

### Edit domino12.yml and have a look

```
vi domino12.yml
"cat domino12.yml"
```

### Create your first Pod

```
kubectl apply -f domino12.yml
```

### Show details of a pod

```
kubectl describe pod/domino12
```

### Run a bash into a pod

```
kubectl exec pod/domino12 -it -- bash
```

### Delete the existing pod

```
kubectl delete -f domino12.yml
```


# Domino V12 One Touch Configuration

* Full example with storage / volumes
* Domino V12 One Touch Setup
* Translog, DAOS, NIFNSF, ...
* Log-In Form, iNotes Redirect, iNet Password Lockout, TLS, ...
* Best practices & Tuning
  
### Create storage for a new pod

```
kubectl apply -f pvc_storage.yml
```

### Create a secret containing the One Touch JSON configuration

Passing JSON with a new created secret.

```
kubectl create secret generic domino12-cfg --from-file=auto_config.json=./auto_config_domino12.json
```

### Finally create new pod 

```
kubectl apply -f domino12_auto_config.yml
```

The names for the pod are the same. All previous commands apply.


## Expose services outside K8s

By default pods only have internal IP addresses and need to be exposed via services and ingresses.  
Here are some simple examples for HTTP, HTTPS and NRPC to start with.

### Change listening Load Balancer from 443 to 444

Edit the existing configuration

```
/local/github/domino-docker/lab/kubernetes/k3s/edit_traefik.sh
```

### Create services and an ingress for HTTP

```
kubectl apply -f service_http.yml
kubectl apply -f ingress_http.yml
```

### Create a directly exposed service for HTTPS and NRPC

```
kubectl apply -f service_https.yml
kubectl apply -f service_nrpc.yml
```

