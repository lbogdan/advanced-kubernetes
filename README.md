# Advanced Kubernetes Workshop / DB / 19, 20, 23 October 2023

## Schedule

- starts at 10:00
- ~10m breaks every 1h-1h30m
- 1h lunch break at 12:30-13:00
- ends at ~17:45

## Format

- I go over the theory
- I solve a task
- you solve the task
- we go over and solve any encountered issue together so that everyone finishes the task

## Agenda

Pod lifecycle, probes, init containers, ephemeral containers, pod and node (anti-)affinities, taints and tolerations, disruptions

Networking model, CNI (Container Network Interface) plugins, services, DNS, ingress, network policies

- CNI case study: Calico

Persistent storage, CSI (Container Storage Interface), storage classes, persistent volumes, persistent volume claims

- CSI case study: Rook / Ceph

Managing stateful applications, CRDs (Custom Resource Definition) and Kubernetes operators

- Case study: CloudNativePG

Security - RBAC, pod security standards, third-party policy engines, secret management, TLS certificate management

- Case study: Kyverno, Sealed Secrets and cert-manager

GitOps and CI/CD workflows

- Case study: Helm, kustomize and ArgoCD

Observability - monitoring, logging and alerting

- Case study: kube-prometheus-stack, Fluent Bit and Grafana Loki

Autoscaling - horizontal pod autoscaler, vertical pod autoscaler and cluster autoscaler

Application development workflows

- Case study: Okteto

Troubleshooting infrastructure and Kubernetes issues

What we won't cover, as either I don't have enough production experience with, or they are too niche / specific:

- OpenShift specific concepts

- Cloud provider specific concepts (e.g. GKE networking)

- Service meshes, e.g. Istio

## Getting To Know Each Other

Hello, I'm Bogdan!

- I've been programming and sysadmining for the past ~25 years
- sysadmin & networking
- backend - PHP, Node.js
- frontend - Vue.js
- Vue.js, Docker & Kubernetes instructor @[JSLeague](https://www.jsleague.ro/)
- dev&ops @[CodeSandbox.io](https://codesandbox.io/)

## [Day 1](day-1.md)

## [Day 2](day-2.md)

## [Day 3](day-3.md)
