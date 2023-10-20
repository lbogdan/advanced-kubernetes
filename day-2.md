## Task 11

Install `kube-prometheus-stack` from the [Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#kube-prometheus-stack) into a new `monitoring` namespace, using the values from `manifests/helm/kube-prometheus-stack-values.yaml`.

This will take some time to install, as it creates a lot of resources. Wait for all the pods in the `monitoring` namespace to become `Ready`.

This chart installs three components: [Prometheus](https://prometheus.io/), [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) and [Grafana](https://grafana.com/).

- Port-forward the `monitoring/alertmanager-operated` and `monitoring/prometheus-operated` services locally and access them from a browser;

  - There should be an alert active, resolve it;

- Edit the values file to configure the Prometheus metrics retention time to 2 days;

- Edit the values file so that it creates an ingress for Grafana (don't enable TLS, to not hit the certificate rate-limit issue);

- Edit the values file to change the Grafana admin password;

- Login into Grafana and browse the available dashboards.

## Task 12

Install [Grafana Loki](https://grafana.com/oss/loki/) from the [Helm chart](https://grafana.com/docs/loki/latest/setup/install/helm/install-monolithic/#install-the-monolithic-helm-chart) into a new `logging` namespace, using the values from `manifests/helm/grafana-loki-values.yaml`.

The `loki-gateway` pod will fail to start (why?), we need to edit the `logging/loki-gateway` `ConfigMap` and comment out the following line:

```yaml
# from
    listen             [::]:8080;
# to
    # listen             [::]:8080;
```

Make sure the pod starts. If it doesn't, try deleting it.

Try to add the Loki data source in Grafana: go to Connections, search for Loki, click "Add new data source"; the URL is `http://loki-gateway.logging`, and if we click "Save & test", we should get the error "Data source connected, but no labels were received. Verify that Loki and Promtail are correctly configured.". That's OK, as we don't have any logs yet.

## Task 13

Install the [Promtail agent](https://grafana.com/docs/loki/latest/send-data/promtail/) from the [Helm chart](https://grafana.com/docs/loki/latest/send-data/promtail/installation/#install-using-helm) into the `logging` namespace with the default values.

Wait for the `promtail` pods to start, and check their logs for any errors.

If we go back to Grafana and click "Save & test" again, we should see "Data source successfully connected.".

## Task 14

Install [kubernetes-event-exporter](https://github.com/resmoio/kubernetes-event-exporter) from the [Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/kubernetes-event-exporter/) into the `logging` namespace, using the values from `manifests/helm/kubernetes-event-exporter-values.yaml`.

## Task 15

Install [Sealed Secrets](https://sealed-secrets.netlify.app/) from the [Helm chart](https://github.com/bitnami-labs/sealed-secrets#helm-chart) into the `kube-system` namespace, using the values from `manifests/helm/sealed-secrets-values.yaml`.

Download the `kubeseal` CLI binary from [here](https://github.com/bitnami-labs/sealed-secrets/releases).

Check that it can communicate to the cluster:

```sh
kubeseal --fetch-cert
# -----BEGIN CERTIFICATE-----
# MIIEzDCCArSgAwIBAgIQMYBh8hSC3zWcqqMgSZZ1NDANBgkqhkiG9w0BAQsFADAA
# [...]
# -----END CERTIFICATE-----
```

Now let's create a simple secret:

```sh
kubectl create secret generic test --from-literal username=root --from-literal password=topsecret --dry-run=client -o yaml >secret.yaml
cat secret.yaml 
# apiVersion: v1
# data:
#   password: dG9wc2VjcmV0
#   username: cm9vdA==
# kind: Secret
# metadata:
#   creationTimestamp: null
#   name: test
```

and encrypt it with `kubeseal`:

```sh
kubeseal -o yaml <secret.yaml >sealedsecret.yaml
cat sealedsecret.yaml 
# apiVersion: bitnami.com/v1alpha1
# kind: SealedSecret
# metadata:
#   creationTimestamp: null
#   name: test
#   namespace: default
# spec:
#   encryptedData:
#     password: AgCHxGLa0XbkekqxX50SYqpqRUgiIwFywpUgXwOXAwH2krcf02Ni5SnwnCpNfN3+RfL6JD9tE3XquZhOWCSTJCW00lnPToYxjk7Qkyke2mf9XFm4QkYqHCEQBzXNXJfBxMDoHNIbdJ6wIOkLoQD0ZrGdJx5m/q8SL6+aWo3I6+Aol+UrmetlrmthgTJy7jDhnKRNPHZ2v3K4UGIQMG8CAI6l+iNwd6nNsXEeJjZ7J3rFO0mM54XDn1/YhvgQmfvoFSORoJe+JPZjwKzc2hvnJ/S+rn0cuNzz1d7mabVyDDsDjkry6F0v/pXwhVdWXC4005vAM9cVTYrDpVeRIdTgYqseadW4yK3ym5zY4LMnuLgF3gZsrXlxBqN/6dOUMooXYYNVlDEdktMPEKsNynJwju7vufoAFQp+kwl2qDHzkYSbjpUkpV1Qp02stlvCMCGKuAADLEHMlseE9lqJtR5RTVCCHa0ImNIf46EFf47EyRlAYXReQTwjwg1oJinqanhWaYUoqm3FZbUqbXhWGArqUJl+ZDEf3DtP+iVjicajNUZPegdgknb0yScjPXOb3hVtVBGu3FF73s1w6mOEkBZKB3rZPmC7Tx+FsYxcxuzfc6NEbdDiAk4evVYdXNaHn34Onuzo45oZ3HTTuLX+tlqXkgojetn8nfi6tYbqbyLTYbFMEcT2Cw3XoLTNSr7uBBnfDsrd/02xT3Az9Dw=
#     username: AgBC6TqbykJdQKzlGWEGZINkFjyarecwZJvlOpYN/nGt3xVNPb3YgAvpPQPJXgw/I1hvgD5W0FzLvf3yRubfk5+3g5iGUNpMcXDjGloQY1UxroTL/LBg8Bp/8TIn3EveHNyDOBCdcdElEiWjVv2KbSO0CjLRZI3N9dhm/+T/C+ikKgyUafgjQlk6kn7A94zjBVnBEYt2JBI80ugYJsepHnpk7NNJgaNJZfiw8d0vVTrkVg1mHJwFMG6BZrDJuIim68NCXss/PQIMK1ZPHVqtC8XItTSLij84hDDiQOoXct+GUNCjAOGdBvq7nzORjiiWV3WiCdgV6O7/XyA5l5sqZjuWyj5YJg66dM3Wuob0zP4k3pUbqK9ffha0vbvoexUWteGoZr6rYo7XPkAznpErNALG/5xS8uuAHQpHUBHn4jRRbzDisI/XiBy8T/583Mai6CjXNDQ6EUjZriiPfizuuNRFBApB34DxffI3G6zVmDNp9UazDPQNd7snwiV1uYuY60N3NMIuhiQJzTVozdCRuI6uzUsKXrBuPkVin/DzIr3pedBUPMPJvdrbANeCSnclDCJOexpDjuKK0g357flzpS/Fs3VnJBK6dKouzhaFxFXbwqFmw+Je2VEtY7jWpZs543tUSaMcGCIL/f0Y/HncTQKi5XLPxomaLjXs374OmzB256fhtw8uNHaOApP3fPfj0UDGn3wB
#   template:
#     metadata:
#       creationTimestamp: null
#       name: test
#       namespace: default
```

Now let's apply it and check that the secret is created:

```sh
kubectl apply -f sealedsecret.yaml
kubectl describe sealedsecret test
# [...]
# Events:
#   Type    Reason    Age   From            Message
#   ----    ------    ----  ----            -------
#   Normal  Unsealed  22s   sealed-secrets  SealedSecret unsealed successfully
kubectl describe secret test
kubectl get secret test
# NAME   TYPE     DATA   AGE
# test   Opaque   2      78s
kubectl get secret test -o jsonpath={.data.password} | base64 -d; echo
# topsecret
```

Lastly, clean up:

```sh
kubectl delete sealedsecret test
# sealedsecret.bitnami.com "test" deleted
kubectl get secret test
# Error from server (NotFound): secrets "test" not found
```

## Task 16

Install [CloudNativePG](https://cloudnative-pg.io/) from the [Helm chart](https://github.com/cloudnative-pg/charts) into a new `cnpg-system` namespace with the default values.

Wait for the operator to be ready, and create a test cluster:

```sh
cat <<EOT >test-pg.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: test-pg
spec:
  instances: 3
  storage:
    size: 500Mi
EOT
```

Wait for the cluster to start - we created the cluster in the `default` namespace, so we should watch the pods there.

Connect to the database from a test pod (the username and password are stored in the `test-pg-app` secret):

```sh
kubectl run --rm -it pg-client --image ghcr.io/cloudnative-pg/postgresql:15.3 --command -- /bin/sh
# If you don't see a command prompt, try pressing enter.

# $
psql -h $SERVICE_NAME -U $USERNAME
# Password for user app: 
# psql (15.3 (Debian 15.3-1.pgdg110+1))
# SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
# Type "help" for help.

# app=>
CREATE TABLE test (id serial PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL);
# CREATE TABLE
INSERT INTO test (username) VALUES ('admin'), ('user');
# INSERT 0 2
SELECT * FROM test;
#  id | username 
# ----+----------
#   1 | admin
#   2 | user
# (2 rows)
```

Delete the cluster, and check that all the pods (and PVCs) are cleaned up.

```sh
kubectl delete cluster test-pg
# wait a bit
kubectl get pods
# No resources found in default namespace.
kubectl get pvc
# No resources found in default namespace.
```

## Task 17

Install [ArgoCD](https://argoproj.github.io/cd/) from the [Helm chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd#installing-the-chart) in a new `argocd` namespace, with the values from `manifests/helm/argocd-values.yaml`.

Expose it using an ingress (replace `$HOST` with your hostname):

```sh
cat <<EOT >argocd-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    # cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
  - host: $HOST
    http: 
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              name: https
  tls:
  - hosts:
    - $HOST
    secretName: argocd-ingress-http
EOT
kubectl apply -f argocd-ingress.yaml
```

Download the `argocd` CLI binary from [here](https://github.com/argoproj/argo-cd/releases/tag/v2.8.4).

Login from the CLI:

```sh
argocd login --grpc-web --insecure --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) $HOST
# 'admin:login' logged in successfully
# Context 'argocd.37.27.0.62.nip.io' updated
```

Manually create some application resources (make sure to replace `$CP_IP` with your control plane IP address):

```sh
cat <<EOT >metrics-server-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: metrics-server
  namespace: argocd
spec:
  destination:
    namespace: kube-system
    server: https://kubernetes.default.svc
  project: default
  source:
    chart: metrics-server
    repoURL: https://kubernetes-sigs.github.io/metrics-server/
    targetRevision: 3.11.0
EOT
kubectl apply -f metrics-server-app.yaml
```

```sh
cat <<EOT >ingress-nginx-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ingress-nginx
  namespace: argocd
spec:
  destination:
    namespace: ingress-nginx
    server: https://kubernetes.default.svc
  project: default
  source:
    chart: ingress-nginx
    helm:
      values: |
        controller:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: node-role.kubernetes.io/control-plane
                    operator: Exists
          extraArgs:
            publish-status-address: $CP_IP
          hostPort:
            enabled: true
          kind: DaemonSet
          priorityClassName: system-cluster-critical
          service:
            enabled: false
          tolerations:
          - effect: NoSchedule
            key: node-role.kubernetes.io/control-plane
            operator: Exists
    repoURL: https://kubernetes.github.io/ingress-nginx
    targetRevision: 4.8.2
EOT
kubectl apply -f ingress-nginx-app.yaml
```

List the apps:

```sh
kubectl -n argocd get app
# NAME             SYNC STATUS   HEALTH STATUS
# ingress-nginx    OutOfSync     Healthy
# metrics-server   OutOfSync     Healthy
argocd app list
# NAME                   CLUSTER                         NAMESPACE      PROJECT  STATUS     HEALTH   SYNCPOLICY  CONDITIONS  REPO                                               PATH  TARGET
# argocd/ingress-nginx   https://kubernetes.default.svc  ingress-nginx  default  OutOfSync  Healthy  <none>      <none>      https://kubernetes.github.io/ingress-nginx               4.8.2
# argocd/metrics-server  https://kubernetes.default.svc  kube-system    default  OutOfSync     Healthy  <none>      <none>      https://kubernetes-sigs.github.io/metrics-server/        3.11.0
```

They are out of sync, look at the diffs:

```sh
argocd app diff metrics-server
#
# ===== /Service kube-system/metrics-server ======
# 11a12
# >     argocd.argoproj.io/instance: metrics-server
#
# ===== /ServiceAccount kube-system/metrics-server ======
# 11a12
# >     argocd.argoproj.io/instance: metrics-server
# [...]
```

Let's sync them:

```sh
argocd app sync metrics-server
# TIMESTAMP                  GROUP                            KIND           NAMESPACE                   NAME                       STATUS    HEALTH        HOOK  MESSAGE
# 2023-10-20T13:16:31+03:00                                Service          kube-system        metrics-server                     OutOfSync  Healthy
# [...]
# Message:            successfully synced (all tasks run)
# [...]
```

List the apps again, they should now be synced:

```sh
kubectl -n argocd get app
# NAME             SYNC STATUS   HEALTH STATUS
# ingress-nginx    OutOfSync     Healthy
# metrics-server   Synced        Healthy
argocd app list
# NAME                   CLUSTER                         NAMESPACE      PROJECT  STATUS     HEALTH   SYNCPOLICY  CONDITIONS  REPO                                               PATH  TARGET
# argocd/ingress-nginx   https://kubernetes.default.svc  ingress-nginx  default  Synced  Healthy  <none>      <none>      https://kubernetes.github.io/ingress-nginx               4.8.2
# argocd/metrics-server  https://kubernetes.default.svc  kube-system    default  Synced     Healthy  <none>      <none>      https://kubernetes-sigs.github.io/metrics-server/        3.11.0
```

Now let's version all this inside a git repository.

Create a GitHub (or similar) git repository. Create an `infra` folder at the root, and inside it, three files:

```
infra
  - kustomization.yaml
  - metrics-server-app.yaml
  - ingress-nginx-app-yaml
```

The `kustomization.yaml` contents should be:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- metrics-server-app.yaml
- ingress-nginx-app.yaml
```

Add your repository to ArgoCD (⚠️replace `$GIT_REPO_URL` with your repository URL):

```sh
argocd repo add $GIT_REPO_URL
# Repository 'https://github.com/lbogdan/gitops-test.git' added
```

Now we create an application from that folder (⚠️again, make sure to replace `$GIT_REPO_URL` with your repository):

```sh
cat <<EOT >infra-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infra
  namespace: argocd
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: default
  source:
    path: infra
    repoURL: $GIT_REPO_URL
EOT
kubectl apply -f infra-app.yaml
```

Go to the UI and sync it.

## Task 18

Define all the components that we installed in the cluster so far in the git repository, and sync them to the cluster.
