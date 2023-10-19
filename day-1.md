## Environment

You will each have access to two servers, one for the control plane, and one for the worker node. They have all Kubernetes prerequisites (`cri-o` container runtime, `kubeadm`, `kubelet`, `kubectl`, other required packages and kernel configurations etc.), but Kubernetes is not yet initialized. So the first step will be to initialize it on the control plane node, and then join the worker node.

## Task #1

Initialize Kubernetes on the control plane node using [`kubeadm init`](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/).

SSH into the control plane server as your user:

```sh
ssh $USERNAME@$CP_IP -p 33133
# e.g.
ssh lbogdan@37.27.0.62 -p 33133
```

> **Note**
>
> I'll be using `lbogdan` as the username throughout this document, you should replace it with your username if copy-pasting commands.

You can also define aliases for the control plane and worker nodes by adding the following to `$HOME/.ssh/config`:

```
Host lbogdan-cp-0
  HostName 37.27.0.62
  User lbogdan
  Port 33133
Host lbogdan-node-0
  HostName 95.217.186.230
  User lbogdan
  Port 33133
```

and then run

```sh
ssh lbogdan-cp-0
```

Most of the commands below need administrative (`root`) privileges, so we'll run them using `sudo`, as your user has `sudo` access without entering your password:

```sh
lbogdan@lbogdan-cp-0:~$ sudo id
uid=0(root) gid=0(root) groups=0(root)
```

The [`kubeadm` config file](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/) is in `/etc/kubernetes/kubeadm/config.yaml`, take a minute to go over it:

```sh
sudo cat /etc/kubernetes/kubeadm/config.yaml
```

Now run a preflight check, to make sure all the prerequisites are met. This will also pull the container images for the control plane components, so it will take a bit of time:

```sh
sudo kubeadm init --config /etc/kubernetes/kubeadm/config.yaml phase preflight
# output:
# [preflight] Running pre-flight checks
# [preflight] Pulling images required for setting up a Kubernetes cluster
# [preflight] This might take a minute or two, depending on the speed of your internet connection
# [preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
```

We can now go ahead and initialize Kubernetes. We'll save the output to `kubeadm-init.log`, as we'll need it later to join the worker node:

```sh
sudo kubeadm init --config /etc/kubernetes/kubeadm/config.yaml | tee kubeadm-init.log
# [init] Using Kubernetes version: v1.27.6
# [preflight] Running pre-flight checks
# [...]
# Then you can join any number of worker nodes by running the following on each as root:
#
# kubeadm join 37.27.0.62:6443 --token [redacted] \
#         --discovery-token-ca-cert-hash sha256:b8f9baeae37cba30d81da8639a60c12e1bddcea43579ff4b3de3becc469f91b8
ls
# kubeadm-init.log
```

To be able to run `kubectl` commands on our new cluster we need an admin config file. This is placed by `kubeadm init` in `/etc/kubernetes/admin.conf`. As it's only accessible by `root`, we'll copy it in our home folder, in `$HOME/.kube/config`, which is the default config file that `kubectl` reads, and change the owner to our user:

```sh
mkdir .kube
sudo cp /etc/kubernetes/admin.conf .kube/config
sudo chown $USER: .kube/config
kubectl get pods -A
# NAMESPACE     NAME                                   READY   STATUS    RESTARTS   AGE
# kube-system   coredns-5d78c9869d-dttcz               0/1     Pending   0          9m4s
# kube-system   coredns-5d78c9869d-wqfhw               0/1     Pending   0          9m4s
# kube-system   etcd-lbogdan-cp-0                      1/1     Running   0          9m19s
# kube-system   kube-apiserver-lbogdan-cp-0            1/1     Running   0          9m20s
# kube-system   kube-controller-manager-lbogdan-cp-0   1/1     Running   0          9m19s
# kube-system   kube-proxy-4glkr                       1/1     Running   0          9m4s
# kube-system   kube-scheduler-lbogdan-cp-0            1/1     Running   0          9m19s
```

Investigate why the `coredns` pods' status is `Pending`. Why are all the other pods `Running`?

Before we go further, we have to manually approve the `kubelet` serving certificate request; we'll come back to this in a bit, but for now just run:

```sh
for csr in $(kubectl get csr -o name); do kubectl certificate approve $csr; done
# certificatesigningrequest.certificates.k8s.io/csr-598jk approved
# certificatesigningrequest.certificates.k8s.io/csr-chlq8 approved
```

See [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/) and [The Kubernetes network model](https://kubernetes.io/docs/concepts/services-networking/#the-kubernetes-network-model).

We'll [install](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less) the Calico CNI network plugin / add-on:

```sh
# download the manifest locally:
curl -Lo calico.yaml curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.3/manifests/calico.yaml -O
# take a minute to go over it and then apply it:
less calico.yaml
kubectl apply -f calico.yaml
# poddisruptionbudget.policy/calico-kube-controllers created
# serviceaccount/calico-kube-controllers created
# [...]
# deployment.apps/calico-kube-controllers created
#
# watch the pods:
kubectl get pods -A -o wide -w
```

All pods should be `Running` now. Let's quickly create a test pod, expose it using a service, and check we can access the pod directly or through the service. We'll use the [`inanimate/echo-server` image](https://hub.docker.com/r/inanimate/echo-server), which by default listens on port `8080`:

```sh
kubectl create deployment test --image inanimate/echo-server
kubectl get pods
# NAME                    READY   STATUS    RESTARTS   AGE
# test-79f55f5bcd-bs8ff   0/1     Pending   0          5s
```

Why does it remain in pending?

Remove the taint from the control plane:

```sh
kubectl taint node lbogdan-cp-0 node-role.kubernetes.io/control-plane:NoSchedule-
# node/lbogdan-cp-0 untainted
#
# now the pod should be running:
kubectl get pods -o wide
# NAME                    READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
# test-5fbc7f6fbb-fjmjp   1/1     Running   0          7s    192.168.53.133   lbogdan-cp-0   <none>           <none>
```

Let's also expose it using a service:

```sh
kubectl expose deployment test --port 80 --target-port 8080
# service/test exposed
kubectl get services -o wide
# NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
# kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   49m   <none>
# test         ClusterIP   10.103.209.237   <none>        80/TCP    7s    app=test
```

Now let's check that we can access the pod, directly and through the service (from the control plane node):

```sh
curl http://192.168.53.133:8080/
curl http://10.103.209.237/
```

Let's also check we can access it from another pod. We'll use the [`nicolaka/netshoot` image](https://hub.docker.com/r/nicolaka/netshoot), which is useful for troubleshooting:

```sh
# create a pod and get a shell:
kubectl run -it --rm test-client --image nicolaka/netshoot:v0.11 --command -- /bin/zsh
# run from the pod:
curl http://192.168.53.133:8080/
curl http://10.103.209.237/
# also check DNS
curl http://test/
curl http://test.default/
curl http://test.default.svc.cluster.local/
# Ctrl-d to exit the shell and delete the pod
```

One last check, change the service to `type: NodePort`, and check that you can access it from your local machine:

```sh
kubectl patch service test --patch '{"spec":{"type":"NodePort"}}'
# service/test patched
kubectl get services -o wide
# NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE   SELECTOR
# kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP        98m   <none>
# test         NodePort    10.103.209.237   <none>        80:32052/TCP   48m   app=test
```

You should now be able to open `http://$CP_IP:$SERVICE_NODEPORT/` (e.g. `http://37.27.0.62:32052/`) from your browser.

Finally, let's clean up and restore the control plane taint:

```sh
kubectl delete deploy test
# deployment.apps "test" deleted
kubectl delete service test
# service "test" deleted
kubectl taint node lbogdan-cp-0 node-role.kubernetes.io/control-plane:NoSchedule
# node/lbogdan-cp-0 tainted
```

## Task 2

Add the worker node.

SSH into the worker node and run the `kubeadm join` command from `kubeadm init`'s output, prefixed by `sudo`:

```sh
sudo kubeadm join 37.27.0.62:6443 --token [redacted] \
        --discovery-token-ca-cert-hash sha256:b8f9baeae37cba30d81da8639a60c12e1bddcea43579ff4b3de3becc469f91b8
# [preflight] Running pre-flight checks
# [preflight] Reading configuration from the cluster...
# [preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
# [kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
# [kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
# [kubelet-start] Starting the kubelet
# [kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...
#
# This node has joined the cluster:
# * Certificate signing request was sent to apiserver and a response was received.
# * The Kubelet was informed of the new secure connection details.
#
# Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

Back on the control plane node, you should see the new node with `Ready` status; this will take a bit of time, until Calico initializes:

```sh
# on the control plane:
kubectl get no -o wide
# NAME             STATUS   ROLES           AGE    VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
# lbogdan-cp-0     Ready    control-plane   112m   v1.27.6   37.27.0.62       <none>        Ubuntu 22.04.3 LTS   6.5.3-060503-generic   cri-o://1.27.1
# lbogdan-node-0   Ready    <none>          4m1s   v1.27.6   95.217.186.230   <none>        Ubuntu 22.04.3 LTS   6.5.3-060503-generic   cri-o://1.27.1
```

We can now log out of the worker node, as we don't need to run any more commands on it.

## Task 3

Rerun all network checks, with the test pod now running on the worker node; cleanup after.

[Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

## Task 4

- create a `cluster-admin` service account in the `kube-system` namespace;
- bind it to the `cluster-admin` `ClusterRole`;
- [create a `Secret` containing a long-lived API token](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#manually-create-a-long-lived-api-token-for-a-serviceaccount) for it;
- replace the client certificate auth with token auth in your `kubectl` config (`.kube/config`);
- check that the new auth method works.

```sh
# from manifests/cluster-admin.yaml
kubectl apply -f cluster-admin.yaml
# serviceaccount/cluster-admin created
# clusterrolebinding.rbac.authorization.k8s.io/cluster-admin-2 created
# secret/cluster-admin created
#
export ADMIN_TOKEN="$(kubectl -n kube-system get secret cluster-admin -o jsonpath={.data.token} | base64 -d)" && echo "cluster-admin token: $ADMIN_TOKEN"
# cluster-admin token: eyJhbGci[...]
kubectl config view
kubectl auth whoami
# ATTRIBUTE   VALUE
# Username    kubernetes-admin
# Groups      [system:masters system:authenticated]
#
# remove current user:
kubectl config delete-user kubernetes-admin
# deleted user kubernetes-admin from /home/lbogdan/.kube/config
#
# re-add the user with token auth:
kubectl config set-credentials kubernetes-admin --token "$ADMIN_TOKEN"
# User "kubernetes-admin" set.
#
# check:
kubectl config view
kubectl auth whoami
# ATTRIBUTE   VALUE
# Username    system:serviceaccount:kube-system:cluster-admin
# UID         1f706a91-f780-4e0f-9e71-4a2c6983d6f6
# Groups      [system:serviceaccounts system:serviceaccounts:kube-system system:authenticated]
```

We can now copy `.kube/config` locally, logout from the control plane node, and only interact with the cluster through the Kubernetes API server from now on.

```sh
# run this locally:
# (make sure you don't already have a config, as it will be overwritten)
scp lbogdan-cp-0:.kube/config ~/.kube/config
# check that it works; you need to have kubectl in PATH locally:
kubectl auth whoami
```

Getting back to the [`kubelet` serving certificate](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/#kubelet-serving-certs), we'll install [`kubelet-csr-approver`](https://github.com/postfinance/kubelet-csr-approver) next, which will automatically approve `kubelet` CSRs.

## Task #5

Install `kubelet-csr-approver` from the [Helm chart](https://github.com/postfinance/kubelet-csr-approver#helm-install) into the `kube-system` namespace, using the values from `manifests/helm/kubelet-csr-approver-values.yaml`.

First, let's try to get the logs of a pod running on the worker-node:

```sh
kubectl -n kube-system get pods --field-selector spec.nodeName=lbogdan-node-0
# NAME                READY   STATUS    RESTARTS   AGE
# calico-node-4gz4s   1/1     Running   0          175m
# kube-proxy-ld7c5    1/1     Running   0          175m
kubectl -n kube-system logs kube-proxy-ld7c5
# Error from server: Get "https://95.217.186.230:10250/containerLogs/kube-system/kube-proxy-ld7c5/kube-proxy": remote error: tls: internal error
```

```sh
# add repository:
helm repo add kubelet-csr-approver https://postfinance.github.io/kubelet-csr-approver
# show the latest version:
helm search repo kubelet-csr-approver
# show all versions:
helm search repo kubelet-csr-approver -l
# show the default values:
helm show values kubelet-csr-approver/kubelet-csr-approver >kubelet-csr-approver-values-orig.yaml
# check what will get installed (with default values):
helm diff upgrade --install --namespace kube-system kubelet-csr-approver kubelet-csr-approver/kubelet-csr-approver
# install (with default values):
helm upgrade --install --namespace kube-system kubelet-csr-approver kubelet-csr-approver/kubelet-csr-approver
# check the pods logs, you should see some errors related to DNS
#
# show diff when using values:
helm diff upgrade --install --namespace kube-system --values kubelet-csr-approver-values.yaml kubelet-csr-approver kubelet-csr-approver/kubelet-csr-approver
# apply the values:
helm upgrade --install --namespace kube-system --values kubelet-csr-approver-values.yaml kubelet-csr-approver kubelet-csr-approver/kubelet-csr-approver
# we should see an approved CSR for the worker node shortly:
kubectl get csr | grep Approved
# csr-tf2sp   93s     kubernetes.io/kubelet-serving   system:node:lbogdan-node-0   <none>              Approved,Issued
#
# and manage to get the logs:
kubectl -n kube-system logs kube-proxy-ld7c5
# I1018 09:41:54.460985       1 node.go:141] Successfully retrieved node IP: 95.217.186.230
# [...]
```

Next thing we'll install is [`metrics-server`](https://github.com/kubernetes-sigs/metrics-server), see [https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/](Resource metrics pipeline).

## Task #5

Install `metrics-server` from the [Helm chart](https://artifacthub.io/packages/helm/metrics-server/metrics-server) into the `kube-system` namespace, using the default values.

First, let's try to show node CPU and memory stats:

```sh
kubectl top nodes
# error: Metrics API not available
```

Install the chart:

```sh
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server
# wait for the metrics-server pod to become ready
kubectl -n kube-system wait pods --for condition=Ready -l app.kubernetes.io/name=metrics-server
```

Now stats should work:

```sh
kubectl top nodes
# NAME             CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# lbogdan-cp-0     130m         4%     1306Mi          35%
# lbogdan-node-0   81m          2%     656Mi           17%
kubectl top pods -A
# NAMESPACE     NAME                                       CPU(cores)   MEMORY(bytes)
# kube-system   calico-kube-controllers-6ff746f7c5-g449k   2m           12Mi
# [...]
```

Next, we will install `ingress-nginx`.

First, install the app, defined as a [`Kustomize` overlay](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) in `manifests/test`:

```sh
# clone the repository locally
cd $REPO_PATH/manifests/test
# edit ingress-patch.json and replace $HOST with test.$CP_IP.nip.io, e.g. test.37.27.0.62.nip.io
# check the manifests:
kubectl kustomize . | less
# and apply them:
kubectl apply -k .
# check the ingress:
kubectl describe ing test
# Name:             test
# Labels:           app=test
# Namespace:        default
# Address:          
# Ingress Class:    nginx
# Default backend:  <default>
# Rules:
#   Host                    Path  Backends
#   ----                    ----  --------
#   test.37.27.0.62.nip.io  
#                           /   test:http (192.168.238.9:8080)
# Annotations:              <none>
# Events:                   <none>
#
# try to access it:
curl http://test.37.27.0.62.nip.io/
# curl: (7) Failed to connect to test.37.27.0.62.nip.io port 80 after 250 ms: Couldn't connect to server
```

That's expected, as we don't have any ingress controller running in the cluster yet.

## Task 6

Install `ingress-nginx` from the [Helm chart](https://kubernetes.github.io/ingress-nginx/deploy/#quick-start) into a new `ingress-nginx` namespace, using the values from `manifests/helm/ingress-nginx-values.yaml`.

> **Warning**
>
> You need to replace $CP_IP in the values file with your control plane IP address.

After the `ingress-nginx-controller` pod becomes `Ready`, we should see the ingress updated:

```sh
kubectl describe ing test
# Name:             test
# Labels:           app=test
# Namespace:        default
# Address:          37.27.0.62
# Ingress Class:    nginx
# Default backend:  <default>
# Rules:
#   Host                    Path  Backends
#   ----                    ----  --------
#   test.37.27.0.62.nip.io  
#                           /   test:http (192.168.238.9:8080)
# Annotations:              <none>
# Events:
#   Type    Reason  Age                From                      Message
#   ----    ------  ----               ----                      -------
#   Normal  Sync    38s (x2 over 38s)  nginx-ingress-controller  Scheduled for sync
#
# and we should be able to access it (also from a browser):
curl http://test.37.27.0.62.nip.io/
# <!doctype html>
# [...]
```

Let's now enable TLS for our ingress; in the `manifests/test` folder do the following:

- edit `base/ingress.yaml` and uncomment all commented lines;

- edit `ingress-patch-tls.json` and replace all `$HOST` occurrences with `test.$CP_IP.nip.io`;

- edit `kustomization` and replace `path: ingress-patch.json` with `path: ingress-patch-tls.json`;

- check (`kubectl diff -k .`) and apply (`kubectl apply -k .`).

If we now refresh the browser, we'll get redirected to the `https://` URL, but we'll get a `NET::ERR_CERT_AUTHORITY_INVALID` (or similar) error. That's because the `test.37.27.0.62.nip.io-tls` secret doesn't exit, so our ingress controller uses uses its default, self-signed certificate.

In order to fix this, let's next install [`cert-manager`](https://cert-manager.io/), which will auto-generate (and renew) valid certificates using [Let's Encrypt](https://letsencrypt.org/).

## Task 7

Install `cert-manager` from the [Helm chart](https://cert-manager.io/docs/installation/helm/) into a new `cert-manager` namespace, using the values from `manifests/helm/cert-manager-values.yaml`.

For now it still won't work, investigate why.

Edit `manifests/clusterissuer.yaml`, replace `$EMAIL` with your email address, and apply it to the cluster.

To force the certificate regeneration, we can delete the certificate:

```sh
kubectl get cert
# NAME                         READY   SECRET                       AGE
# test.37.27.0.62.nip.io-tls   False   test.37.27.0.62.nip.io-tls   7m47s
kubectl delete cert test.37.27.0.62.nip.io-tls
# certificate.cert-manager.io "test.37.27.0.62.nip.io-tls" deleted
#
# wait for the certificate to become ready:
kubectl get cert
# NAME                         READY   SECRET                       AGE
# test.37.27.0.62.nip.io-tls   True    test.37.27.0.62.nip.io-tls   32s
```

Now you if we refresh, we should be able to access the application over HTTPS.

The only thing we still need to have a functional cluster is storage, so let's add that next! We'll use [Rook](https://rook.io/), which is a Kubernetes operator for the distributed storage system [Ceph](https://ceph.io/en/) and a CSI storage plugin.

## Task 8

First, install the `rook-ceph` operator from the [Helm chart](https://rook.io/docs/rook/v1.12/Helm-Charts/operator-chart/) into a new `rook-ceph` namespace, using the values from `manifests/helm/rook-ceph-values.yaml`.

Check that you have a `/dev/sdb` 10GB disk on your control plane node:

```sh
ssh lbogdan-cp-0 lsblk
# NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
# [...]
# sdb       8:16   0   10G  0 disk
# sr0      11:0    1    2K  0 rom
```

Now edit `manifests/rook-ceph/cephcluster.yaml` and under `nodes` replace `name: $CP_NAME` with your control plane name (⚠️VERY IMPORTANT⚠️), apply it, and watch the `rook-ceph-operator` pod's logs and the `rook-ceph` namespace for new pods. Wait until the cluster is `Ready`:

```sh
kubectl -n rook-ceph get cephcluster
# NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE   MESSAGE                        HEALTH      EXTERNAL   FSID
# rook-ceph   /var/lib/rook     1          18m   Ready   Cluster created successfully   HEALTH_OK              4160253f-dba1-4ada-91bd-2dd5b1a2d640
```

We can also apply `manifests/rook-ceph/toolbox.yaml`, which will create a debug pod where you can run `ceph` commands on the Ceph cluster:

```sh
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
  # cluster:
  #   id:     4160253f-dba1-4ada-91bd-2dd5b1a2d640
  #   health: HEALTH_OK
 
  # services:
  #   mon: 1 daemons, quorum a (age 18m)
  #   mgr: a(active, since 4m)
  #   osd: 1 osds: 1 up (since 5m), 1 in (since 5m)
 
  # data:
  #   pools:   1 pools, 1 pgs
  #   objects: 2 objects, 577 KiB
  #   usage:   27 MiB used, 10 GiB / 10 GiB avail
  #   pgs:     1 active+clean
```

Now we'll create a Ceph storage pool and a `StorageClass` that uses it by applying `manifests/rook-ceph/storageclass.yaml`. We should now have an auto-provisioning default `StorageClass`:

```sh
kubectl -n rook-ceph get cephblockpool
# NAME         PHASE
# ceph-block   Ready
#
kubectl get storageclasses
# NAME                   PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
# ceph-block (default)   rook-ceph.rbd.csi.ceph.com   Retain          Immediate           true                   5m46s
```

To test it, uncomment the PVC resource in `manifests/test/kustomization.yaml` and the volume and mount in `manifests/test/base/deployment.yaml`. Reapply the `test` app and check that the PVC is bound and the pod starts successfully with the volume mounted:

```sh
kubectl get pvc
# NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# test   Bound    pvc-caa380b4-6cf4-41a2-8838-8d8d043397bd   100Mi      RWO            ceph-block     3m34s
kubectl exec deploy/test -- mount | grep data
# /dev/rbd0 on /data type ext4 (rw,relatime,stripe=64)
#
# write a file:
kubectl exec deploy/test -- dd if=/dev/random of=/data/random.bin bs=1M count=1
# 1+0 records in
# 1+0 records out
```

Check that you can access the file at `https://test.37.27.0.62.nip.io/fs/data/random.bin`.

Restart the pod and check that the file is persisted.

## Task 9

Create an ingress to expose the Ceph dashboard service `rook-ceph/rook-ceph-mgr-dashboard`. To login, see [Login Credentials](https://rook.io/docs/rook/v1.12/Storage-Configuration/Monitoring/ceph-dashboard/?h=dashboard#login-credentials).
