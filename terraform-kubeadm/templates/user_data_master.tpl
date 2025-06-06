#!/bin/bash
set -e

# 기본 설정
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 패키지 설치
apt-get update && apt-get install -y \
  curl apt-transport-https gnupg2 software-properties-common nginx golang

# containerd 설치
apt-get install -y containerd
# containerd 설정 파일 생성 (CRI plugin 포함)
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
# CRI plugin이 비활성화된 경우를 대비해 disabled_plugins 제거
sed -i '/disabled_plugins/d' /etc/containerd/config.toml
# cgroup 드라이버 설정 (systemd로 일치시킴)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
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

# Calico CNI 위한 sysctl 설정
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

# kubeadm 초기화
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$(hostname -i) \
  --cri-socket=unix:///var/run/containerd/containerd.sock

# kubeconfig 복사
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Calico CNI 적용
su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml"

# Nginx 포트 설정
sed -i "s/listen 80 default_server;/listen ${nginx_port};/" /etc/nginx/sites-available/default
sed -i "s|root /var/www/html;|root /var/www/html;|" /etc/nginx/sites-available/default
systemctl restart nginx

# join 명령 노출용 스크립트 생성
cat > /usr/local/bin/rotate-token.sh <<EOF
#!/bin/bash
set -e
TOKEN=\$(kubeadm token create --ttl 1h)
HASH=\$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \\
       openssl rsa -pubin -outform DER 2>/dev/null | \\
       openssl dgst -sha256 -hex | awk '{print \$2}')
JOIN_CMD="kubeadm join $(hostname -i):6443 --token \$TOKEN --discovery-token-ca-cert-hash sha256:\$HASH --cri-socket /var/run/containerd/containerd.sock"

echo "#!/bin/bash" > /var/www/html/join.sh
echo "\$JOIN_CMD" >> /var/www/html/join.sh
chmod +x /var/www/html/join.sh
EOF

chmod +x /usr/local/bin/rotate-token.sh
/usr/local/bin/rotate-token.sh

# crontab에 등록 (매 30분마다 재생성)
echo "*/30 * * * * root /usr/local/bin/rotate-token.sh" > /etc/cron.d/kubeadm-token-rotate
