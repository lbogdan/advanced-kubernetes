#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SSH_PORT=33133
KUBERNETES_MINOR="1.27"
OS="xUbuntu_$(lsb_release -rs)"
KUBERNETES_VERSION="${KUBERNETES_MINOR}.6"
CRUN_VERSION="1.9"
# OCI_RUNTIME="crun"
OCI_RUNTIME="runc"
# CRI="containerd"
CRI="crio"

# TODO:
# _os_supported () {
#   return 0
# }

_update_packages () {
  echo "* updating packages"
  apt-get -q update
  apt-get -qy upgrade
  apt-get -qy install ipvsadm jq mc
}

_remove_unneeded_packages () {
  echo "* remove unneeded packages"
  apt-get -qy purge multipath-tools polkitd udisks2
  apt-get -qy autoremove
}

_install_kernel () {
  echo "* installing mainline kernel 6.5.3"
  local pwd="$PWD"
  mkdir -v ~/kernel
  cd ~/kernel
  curl -LOOOO https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.5.3/amd64/linux-headers-6.5.3-060503-generic_6.5.3-060503.202309130834_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.5.3/amd64/linux-headers-6.5.3-060503_6.5.3-060503.202309130834_all.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.5.3/amd64/linux-image-unsigned-6.5.3-060503-generic_6.5.3-060503.202309130834_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.5.3/amd64/linux-modules-6.5.3-060503-generic_6.5.3-060503.202309130834_amd64.deb
  # shellcheck disable=SC2251
  ! dpkg -i ./*.deb
  sed -Ei 's/libc6 \(>= 2\.38\)/libc6 (>= 2.35)/' /var/lib/dpkg/status
  apt-get -qf install
  cd "$pwd"
}

_get_public_interface () {
  ip ro | grep 'default via' | cut -d ' ' -f 5
}

_get_mac_address () {
  local interface="$1"
  ip add sh dev "$interface" | grep link/ether | tr -s ' ' | cut -d ' ' -f 3
}

_disable_ipv6 () {
  echo "* disabling ipv6"
  sed -Ei 's/GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 ipv6.disable=1"/' /etc/default/grub
  update-grub
  local mac_address
  mac_address="$(_get_mac_address "$(_get_public_interface)")"
  # echo "public interface mac address: $mac_address"
  cp -v /etc/netplan/50-cloud-init.yaml "/etc/netplan/50-cloud-init.yaml-$(date +%s).bak"
  cat <<EOT >/etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      match:
        macaddress: $mac_address
      set-name: eth0
EOT
}

_install_chrony () {
  echo "* installing chrony"
  apt-get -qy install chrony
}

_configure_ssh () {
  echo "* configuring ssh"
  cat <<EOT >/etc/ssh/sshd_config.d/01-port.conf
Port $SSH_PORT
EOT
}

_enable_bash_completion () {
  echo "* enabling bash completion"
  sed -i '35,41s/^#//' /etc/bash.bashrc
}

_add_k8s_repositories () {
  echo "* adding kubernetes repositories"
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/deb/ /" >/etc/apt/sources.list.d/kubernetes.list
  if [ "$CRI" = "crio" ] || [ "$CRI" = "cri-o" ]; then
    curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/Release.key | gpg --dearmor -o /etc/apt/keyrings/libcontainers-archive-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/ /" >/etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    echo "deb [signed-by=/etc/apt/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${KUBERNETES_MINOR}/${OS}/ /" >/etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:${KUBERNETES_MINOR}.list
  fi
  apt-get -q update
}

_install_k8s_packages () {
  local cri_package="cri-o"
  if [ "$CRI" != "crio" ] && [ "$CRI" != "cri-o" ]; then
    cri_package="containerd"
  fi
  echo "* installing kubernetes $KUBERNETES_VERSION packages and $cri_package"
  apt-get -qy install "kubeadm=${KUBERNETES_VERSION}-1.1" "kubectl=${KUBERNETES_VERSION}-1.1" "kubelet=${KUBERNETES_VERSION}-1.1" $cri_package runc
  apt-mark hold kubeadm kubectl kubelet $cri_package runc
  systemctl disable kubelet
  if [ "$cri_package" = "cri-o" ]; then
    curl -Lo /usr/sbin/crun https://github.com/containers/crun/releases/download/${CRUN_VERSION}/crun-${CRUN_VERSION}-linux-amd64
    chmod +x /usr/sbin/crun
  fi
  if [ "$cri_package" = "containerd" ]; then
    systemctl stop containerd
  fi
}

_configure_crio () {
  echo "* configuring cri-o"
  rm -v /etc/cni/net.d/*.conflist
  mkdir -v /var/lib/crio
  cat <<EOT >/etc/crio/crio.conf.d/01-crio-runc.conf
[crio.runtime.runtimes.runc]
runtime_path = "/usr/sbin/runc"
runtime_type = "oci"
runtime_root = "/run/runc"
EOT
  cat <<EOT >/etc/crio/crio.conf.d/02-crio-crun.conf
[crio.runtime.runtimes.crun]
runtime_path = "/usr/sbin/crun"
runtime_type = "oci"
runtime_root = "/run/crun"
EOT
  cat <<EOT >/etc/crio/crio.conf.d/10-crio-runtime.conf
[crio.runtime]
default_runtime = "$OCI_RUNTIME"
EOT
  systemctl enable crio
}

_configure_containerd () {
  echo "* configuring containerd"
  mkdir -v /etc/containerd
  containerd config default >/etc/containerd/config.toml
  sed -e 's/SystemdCgroup = false/SystemdCgroup = true/' -e 's/pause:3.8/pause:3.9/' -i /etc/containerd/config.toml
  cat <<EOT >/etc/crictl.yaml
runtime-endpoint: "unix:///run/containerd/containerd.sock"
timeout: 0
debug: false
EOT
}

_configure_kernel () {
  # rbd is needed, otherwise csi-rbdplugin fails to start with the following error:
  # csi-rbdplugin E1018 17:16:35.443611  259389 rbd_util.go:303] modprobe failed (an error (exit status 1) occurred while running modprobe args: [rbd]): "modprobe: ERROR: could not insert 'rbd': Exec format error\n"

  echo "* configuring kernel"
  cat <<EOF >/etc/modules-load.d/kubeadm.conf
br_netfilter
rbd
EOF
  cat <<EOF >/etc/sysctl.d/kubeadm.conf
net.ipv4.ip_forward = 1
EOF
}

_configure_user () {
  local username="$1"
  local name="$2"
  local ssh_public_key="$3"
  adduser --disabled-password --gecos "$name" "$username"
  mkdir "/home/$username/.ssh"
  chmod 0700 "/home/$username/.ssh"
  echo "$ssh_public_key" >"/home/$username/.ssh/authorized_keys"
  chmod 0600 "/home/$username/.ssh/authorized_keys"
  chown -R "$username:$username" "/home/$username/.ssh"
  usermod -a -G sudo "$username"
  sed -i '/^%sudo/c\%sudo\tALL=(ALL) NOPASSWD:ALL' /etc/sudoers
}

_zap_ceph_disk () {
  # see https://rook.io/docs/rook/v1.12/Getting-Started/ceph-teardown/#zapping-devices
  if [ -b /dev/sdb ]; then
    sgdisk --zap-all /dev/sdb
    dd if=/dev/zero of=/dev/sdb bs=1M count=100 oflag=direct,dsync
  fi
}

echo "$#"
echo "$@"

if [ $# -ne 3 ]; then
  echo "Usage: $0 USERNAME NAME SSH_PUBLIC_KEY" >&2
  exit 1
fi

_update_packages
_remove_unneeded_packages
_install_kernel
_disable_ipv6
_install_chrony
_configure_ssh
_enable_bash_completion
_add_k8s_repositories
_install_k8s_packages
if [ "$CRI" = "crio" ] || [ "$CRI" = "cri-o" ]; then
  _configure_crio
else
  _configure_containerd
fi
_configure_kernel
_configure_user "$@"
_zap_ceph_disk
