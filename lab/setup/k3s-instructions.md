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

## Install kubectrl on your local machine

Kubectrl is used to manage your Kubernetes environment remotely.  
The following curl commands download the binary automatically.  
You can also download via browser or follow the official instructions which might change over time.  


### Windows Install

If you have curl installed you can just use a single command (should be default on Windows 10).

```
mkdir c:\tmp\kube
cd /d c:\tmp\kube

curl -LO "https://dl.k8s.io/release/v1.22.0/bin/windows/amd64/kubectl.exe"
```

### Linux/Mac Install

On Linux and Mac the command can check for the current version automatically and download the latest version.  

```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl

chmod +x /usr/local/bin/kubectl
```

### Instructions:

https://kubernetes.io/docs/tasks/tools/install-kubectl/


## Download your kube config from your Linux box to your machine

Kubectrl needs a configuration file containing login information to your environment.  
To access the k3s environmen remotely the yaml configuration needs to be downloaded and updated with your server name.  

The file is located here  

```
 /etc/rancher/k3s/k3s.yaml
```

For example MobaXterm --> drag & drop to file explorer.  
Putty does not have a download option. There would be WinSCP.  
But you an also copy the text per copy & paste into a new file.



### Copy configuration to the standard location

Windows

```
mkdir %USERPROFILE%\.kube
copy k3s.yaml %USERPROFILE%\.kube\config
```

An example directory and file name would be `C:\Users\nsh\.kube\config`

Mac/Linux

```
mkdir ~/.kube
cp k3s.yaml ~/.kube/config
```

## Edit the file and change the hostname from 127.0.0.1 to your server FQDN like this:

```
https://master.domino-lab.net:6443

```

Windows

```
notepad %USERPROFILE%\.kube\config
```

Linux

```
vi ~/.kube/config
nano ~/.kube/config
mcedit ~/.kube/config
```


### OPTION: Environment Variable - if you already have a configuration

You can also keep it in the location where you downloaded it and export an environment variable and just export an environment variable.  

Example Windows

```
set KUBECONFIG=d:\k3s\kubeconfig.yml
```

Example Mac/Linux
```
export KUBECONFIG=/local/k3s.yaml
```


## Check configuration and connection


Windows

```
kubectl.exe version

kubectl.exe get node
```

Mac/Linux

```
kubectl version

kubectl get node
```


## Install graphical Dashboard on k3s

This needs a couple of more complex commands. But nobody types in those commands manually ..
Switch back to your Linux lab machine first.  

```
cd /local/github/domino-docker/lab/kubernetes/k3s/dashboard
```

### Installation command

```
./install.sh
```

Details:

```
GITHUB_URL=https://github.com/kubernetes/dashboard/releases
VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
k3s kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml
```

### Create admin user and role

Run the following commands to deply the YAML configuration

```
kubectl create -f dashboard.admin-user.yml
kubectl create -f dashboard.admin-user-role.yml
```

#### Reference - Configuration files

dashboard.admin-user.yml

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```

dashboard.admin-user-role.yml

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

### Get the authentication token on your local Windows machine

```
kubectl -n kubernetes-dashboard describe secret admin-user-token | findstr token
```

### Get the authentication token on Linux/Mac or your lab machine

```
kubectl -n kubernetes-dashboard describe secret admin-user-token |grep token
```

## Connect from your machine to k3s dashboard

The proxy command creates a tunnel between your local machine and your K8s server.  
Start in separate window and keep it open.  
The following is very confusing at first look. But you will see it will all make sense.  

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

### Create the registry pull secret

Create "secret" to authenticate with our remote registry.  
The command needs the hostname and user/password.

The following variables are already defined in your environment for your convenience  

- LAB_REGISTRY_HOST
- LAB_REGISTRY_USER
- LAB_REGISTRY_PASSWORD

You just need to run the following command to create the registry pull secret.  
The command uses the environment variables which you would normally to specify  

```
kubectl create secret docker-registry --namespace default regcred --docker-server=$LAB_REGISTRY_HOST --docker-username=$LAB_REGISTRY_USER --docker-password=$LAB_REGISTRY_PASSWORD
```

Check the secret

List all secrets

```
kubectl get secret
```

Describe the secret and look at it in different formats

```
kubectl describe secret/regcred
kubectl get secret/regcred -o yaml
kubectl get secret/regcred -o json
```

### Run your first Domino server on Kubernetes

Switch to the lab example files

```
cd  /local/github/domino-docker/lab/kubernetes/domino
```

### Edit domino12.yml and have a look

```
vi domino12.yml
cat domino12.yml
```

### Create storage for a new pod

Similar to `volumes` on Docker, we need `Persistent Storage` on Kubernetes.

Each Kubernetes environment comes with one or more storage drivers.  
In our case this is just the simple `local-path`

```
 kubectl get StorageClass

 kubectl describe storageclass/local-path
```

From the storage class we have to claim storage.  
This resource is called `PVC` -- `P`ersistent`V`olume`C`laim

Lets have a look and apply  

```
kubectl apply -f pvc_storage.yml
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

### Delete the existing pod and storage

```
kubectl delete -f domino12.yml
kubectl delete -f pvc_storage.yml
```

Or use delete command on the name of the resource  

```
kubectl delete pod/domino12
kubectl delete pvc/local-path-pvc
```

# Domino V12 One Touch Configuration

Recreate the PVC first as in the first example


* Full example with storage / volumes
* Domino V12 One Touch Setup
* Translog, DAOS, NIFNSF, ...
* Log-In Form, iNotes Redirect, iNet Password Lockout, TLS, ...
* Best practices & Tuning


### Create a secret containing the One Touch JSON configuration

Passing JSON with a new created secret.

Take a look at the JSON file first before creating a secret to pass as configuration.

```
cat auto_config_domino12.json
```


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
kubectl edit svc traefik -n kube-system
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

## Uninstall k3s

```
/usr/local/bin/k3s-uninstall.sh
```
