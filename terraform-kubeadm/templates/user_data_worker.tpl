#!/bin/bash
set -e

# 기본 설정
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 필수 패키지
apt-get update && apt-get install -y \
  curl apt-transport-https gnupg2 software-properties-common git golang

# containerd 설치
apt-get install -y containerd
# containerd 설정 파일 생성 (CRI plugin 포함)
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
# CRI plugin이 비활성화된 경우를 대비해 disabled_plugins 제거
sed -i '/disabled_plugins/d' /etc/containerd/config.toml
# containerd 재시작
systemctl restart containerd
systemctl enable containerd

# Kubernetes 저장소 설정
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list

# Kubernetes 구성 요소 설치
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Calico CNI를 위한 sysctl 설정
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

# 클러스터 참여 (재시도 로직 포함)
JOIN_URL="http://${master_ip}:${nginx_port}/join.sh"
for i in {1..30}; do
  echo "[Worker] Attempting to join cluster... (try $i)"
  
  if curl -sf "$JOIN_URL" -o /tmp/join.sh; then
    chmod +x /tmp/join.sh
    if /tmp/join.sh; then
      echo "[Worker] Successfully joined cluster"
      break
    else
      echo "[Worker] join.sh 실행 실패"
    fi
  else
    echo "[Worker] curl 실패"
  fi

  sleep 10
done
