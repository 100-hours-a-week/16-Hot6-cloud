#!/bin/bash
set -e

### ⛔ 시스템 기본 설정
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

### 📦 필수 패키지 설치
apt-get update && apt-get install -y \
    curl apt-transport-https gnupg2 software-properties-common nginx containerd

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

### 📦 kubeadm 설치
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
    tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

### 🏗 kubeadm init
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$(hostname -i) \
  --cri-socket=unix:///var/run/containerd/containerd.sock

### 🔐 kubeconfig 설정 (ubuntu 사용자 기준)
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

### 🌐 Flannel CNI 적용
su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"

### 🌐 nginx 설정 (포트 18080으로 join.sh 배포)
sed -i "s/listen 80 default_server;/listen ${nginx_port};/" /etc/nginx/sites-available/default
sed -i "s|root /var/www/html;|root /var/www/html;|" /etc/nginx/sites-available/default
systemctl restart nginx
systemctl enable nginx

### 🔁 토큰 생성 및 join.sh 배포 스크립트
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

### 🕒 crontab 등록 (30분마다 rotate)
echo "*/30 * * * * root /usr/local/bin/rotate-token.sh" > /etc/cron.d/kubeadm-token-rotate
