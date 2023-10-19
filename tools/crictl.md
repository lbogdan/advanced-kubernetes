# Useful crictl Commands

Get container runtime version:

```sh
crictl version
# Version:  0.1.0
# RuntimeName:  cri-o
# RuntimeVersion:  1.27.1
# RuntimeApiVersion:  v1
```

Get container runtime status:

```sh
crictl info
# {
#   "status": {
#     "conditions": [
#       {
#         "type": "RuntimeReady",
#         "status": true,
#         "reason": "",
#         "message": ""
#       },
#       {
#         "type": "NetworkReady",
#         "status": true,
#         "reason": "",
#         "message": ""
#       }
#     ]
#   },
#   "config": {
#     "sandboxImage": "registry.k8s.io/pause:3.9"
#   }
# }
```

List images:

```sh
crictl images
```

List pods:

```sh
crictl pods [--no-trunc] [--name $NAME]
```

List containers:

```sh
crictl ps [--no-trunc]
```

List pod's containers:

```sh
crictl ps --pod $POD_ID
```

Get container's logs:

```sh
crictl logs [-f] [-p] [--tail $NUMBER] [--timestamps] $CONTAINER_ID
```

Exec into container:

```sh
crictl exec [-it] $CONTAINER_ID $COMMAND [$ARG...]
```

Show pods stats (CPU, memory):

```sh
crictl statsp
# POD                                                     POD ID              CPU %               MEM
# kube-controller-manager-lbogdan-cp-0                    0ba89a5b548fa       0.75                54.6MB
# calico-node-p9c2w                                       0ede42acc1928       0.76                70.89MB
# [...]
```

Show containers stats (CPU, memory, disk, inodes):

```sh
crictl stats
# CONTAINER           NAME                      CPU %               MEM                 DISK                INODES
# 069d1041b5110       osd                       2.48                46.96MB             0B                  17
# 0ac0c354640f2       calico-node               0.84                70.71MB             9.309kB             104
# [...]
```

More details [here](https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/).
