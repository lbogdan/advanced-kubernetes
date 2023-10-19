# Useful Helm Commands

Install:

```sh
# make sure you 
curl -Lo /tmp/helm.tar.gz https://get.helm.sh/helm-v3.13.1-linux-amd64.tar.gz
sudo tar xzf /tmp/helm.tar.gz -C /usr/local/bin --strip-components 1 linux-amd64/helm
sudo chown root: /usr/local/bin/helm
unlink /tmp/helm.tar.gz
```

Enable `bash` completion:

```sh
source <(helm completion bash)
# to make it permanent, add it to ~/.bashrc or similar
```

Add repository:

```sh
helm repo add $REPO_NAME $REPO_URL
# e.g.
helm repo add bitnami https://charts.bitnami.com/bitnami
```

List repositories:

```sh
helm repo ls
# output:
# NAME                            URL
# ingress-nginx                   https://kubernetes.github.io/ingress-nginx
```

Search for helm chart:

```sh
helm search repo $CHART_NAME
# e.g.
helm search repo metrics-server
# output:
# NAME                    CHART VERSION   APP VERSION     DESCRIPTION
# bitnami/metrics-server  6.5.5           0.6.4           Metrics Server aggregates resource usage data, ...
```

Get a helm chart's default values:

```sh
helm show values $REPO_NAME/$CHART_NAME [--version $CHART_VERSION]
# e.g.
helm show values bitnami/metrics-server --version 6.5.5 >metrics-server-values-orig.yaml
```

Install a plugin:

```sh
helm plugin install $PLUGIN_URL
# e.g. install the helm diff plugin
helm plugin install https://github.com/databus23/helm-diff
```

Install or upgrade a helm chart:

```sh
helm upgrade --install [--namespace $NAMESPACE] [--values $VALUES_FILE] [--version $CHART_VERSION] $RELEASE_NAME $CHART_SPEC
# e.g.
helm update --install --namespace kube-system --values metrics-server-values.yaml --version 6.5.5 metrics-server bitnami/metrics-server
```

> **Note**
>
> `$CHART_SPEC` can be either
> - a remote chart inside a repository - `$REPO_NAME/$CHART_NAME`, e.g. `bitnami/metrics-server`, or
>
> - a local folder, e.g. `./deploy/chart`

List existing releases in a cluster:

```sh
helm ls [-A / --namespace $NAMESPACE]
e.g.
helm ls -A
# output:
# NAME            NAMESPACE       REVISION        UPDATED                                         STATUS          CHART                              APP VERSION
# metrics-server  kube-system     4               2023-10-13 15:39:30.177251569 +0000 UTC         deployed        metrics-server-6.5.5
```

Show release status:

```sh
helm status [--namespace $NAMESPACE] $RELEASE_NAME
# e.g.
helm status --namespace kube-system metrics-server
# output:
# NAME: metrics-server
# LAST DEPLOYED: Fri Oct 13 15:39:30 2023
# NAMESPACE: kube-system
# STATUS: deployed
# REVISION: 4
# TEST SUITE: None
# NOTES:
# CHART NAME: metrics-server
# CHART VERSION: 6.5.5
# APP VERSION: 0.6.4

# ** Please be patient while the chart is being deployed **

# The metric server has been deployed.
# In a few minutes you should be able to list metrics using the following
# command:

#   kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

Show release history / revisions:

```sh
helm history [--namespace $NAMESPACE] $RELEASE_NAME
# e.g.
helm history --namespace kube-system metrics-server
# output:
# REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION
# 1               Fri Oct 13 15:11:45 2023        superseded      metrics-server-6.5.5    0.6.4           Install complete
# 2               Fri Oct 13 15:22:46 2023        superseded      metrics-server-6.5.5    0.6.4           Upgrade complete
# 3               Fri Oct 13 15:33:32 2023        superseded      metrics-server-6.5.5    0.6.4           Upgrade complete
# 4               Fri Oct 13 15:39:30 2023        deployed        metrics-server-6.5.5    0.6.4           Upgrade complete
```

List all resources created by release:

```sh
helm get manifest [--namespace $NAMESPACE] $RELEASE_NAME | kubectl get -f - -o name
# e.g.
helm get manifest --namespace kube-system metrics-server | kubectl get -f - -o name
# output:
# serviceaccount/metrics-server
# clusterrole.rbac.authorization.k8s.io/metrics-server-kube-system
# clusterrole.rbac.authorization.k8s.io/metrics-server-kube-system-view
# clusterrolebinding.rbac.authorization.k8s.io/metrics-server-kube-system-auth-delegator
# clusterrolebinding.rbac.authorization.k8s.io/metrics-server-kube-system
# rolebinding.rbac.authorization.k8s.io/metrics-server-kube-system-auth-reader
# service/metrics-server
# deployment.apps/metrics-server
# apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io
```

More details [here](https://helm.sh/docs/helm/helm/).
