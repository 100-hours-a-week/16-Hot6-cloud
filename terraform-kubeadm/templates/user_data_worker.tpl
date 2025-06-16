#!/bin/bash
set -e

### ⛔ 스왑 끄기
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

### 📦 패키지 설치
apt-get update && apt-get install -y \
  curl apt-transport-https gnupg2 software-properties-common containerd

### 🔧 containerd 설정
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i '/disabled_plugins/d' /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

### 🔧 sysctl 설정
modprobe br_netfilter
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

### 📦 Kubernetes 바이너리 설치
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

### ✅ 마스터에서 생성한 join.sh 실행
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

### kubelet 서비스 항상 활성화
systemctl enable kubelet && systemctl start kubelet
