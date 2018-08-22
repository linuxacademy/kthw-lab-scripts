# install cfssl and generate Kubernetes CA and certs
# Required env vars: CONTROLLER_IP, INTERNAL_IP, WORKER0_IP, WORKER1_IP
#GENERATE CERTS
wget -q --show-progress --https-only --timestamping https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
mv cfssl_linux-amd64 /usr/local/bin/cfssl
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
cat > /tmp/ca-config.json << EOF
{"signing": {"default": {"expiry": "8760h"},"profiles": {"kubernetes": {"usages": ["signing", "key encipherment", "server auth", "client auth"],"expiry": "8760h"}}}}
EOF
cat > /tmp/ca-csr.json << EOF
{"CN": "Kubernetes","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "Kubernetes","OU": "CA","ST": "Oregon"}]}
EOF
cat > /tmp/admin-csr.json << EOF
{"CN": "admin","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "system:masters","OU": "Kubernetes The Hard Way","ST": "Oregon"}]}
EOF
cat > /tmp/worker0.mylabserver.com-csr.json << EOF
{"CN": "system:node:worker0.mylabserver.com","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "system:nodes","OU": "Kubernetes The Hard Way","ST": "Oregon"}]}
EOF
cat > /tmp/worker1.mylabserver.com-csr.json << EOF
{"CN": "system:node:worker1.mylabserver.com","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "system:nodes","OU": "Kubernetes The Hard Way","ST": "Oregon"}]}
EOF
cat > /tmp/kube-controller-manager-csr.json << EOF
{"CN": "system:kube-controller-manager","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "system:kube-controller-manager","OU": "Kubernetes The Hard Way","ST": "Oregon"}]}
EOF
cat > /tmp/kube-proxy-csr.json << EOF
{"CN": "system:kube-proxy","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "system:node-proxier","OU": "Kubernetes The Hard Way","ST": "Oregon"}]}
EOF
cat > /tmp/kube-scheduler-csr.json << EOF
{"CN": "system:kube-scheduler","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "system:kube-scheduler","OU": "Kubernetes The Hard Way","ST": "Oregon"}]}
EOF
cat > /tmp/kubernetes-csr.json << EOF
{"CN": "kubernetes","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "Kubernetes","OU": "Kubernetes The Hard Way","ST": "Oregon"}]}
EOF
cat > /tmp/service-account-csr.json << EOF
{"CN": "service-accounts","key": {"algo": "rsa","size": 2048},"names": [{"C": "US","L": "Portland","O": "Kubernetes","OU": "Kubernetes The Hard Way","ST": "Oregon"}]}
EOF
cd /tmp
cfssl gencert -initca /tmp/ca-csr.json | cfssljson -bare ca
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/admin-csr.json | cfssljson -bare admin
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -hostname=$WORKER0_IP -profile=kubernetes /tmp/worker0.mylabserver.com-csr.json | cfssljson -bare worker0.mylabserver.com
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -hostname=$WORKER1_IP -profile=kubernetes /tmp/worker1.mylabserver.com-csr.json | cfssljson -bare worker1.mylabserver.com
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/kube-proxy-csr.json | cfssljson -bare kube-proxy
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/kube-scheduler-csr.json | cfssljson -bare kube-scheduler
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -hostname=10.32.0.1,$CONTROLLER_IP,,127.0.0.1,localhost,kubernetes.default -profile=kubernetes /tmp/kubernetes-csr.json | cfssljson -bare kubernetes
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/service-account-csr.json | cfssljson -bare service-account
#GENERATE KUBECONFIGS
wget https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://$CONTROLLER_IP:6443 --kubeconfig=worker0.mylabserver.com.kubeconfig
kubectl config set-credentials system:node:worker0.mylabserver.com --client-certificate=worker0.mylabserver.com.pem --client-key=worker0.mylabserver.com-key.pem --embed-certs=true --kubeconfig=worker0.mylabserver.com.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:node:worker0.mylabserver.com --kubeconfig=worker0.mylabserver.com.kubeconfig
kubectl config use-context default --kubeconfig=worker0.mylabserver.com.kubeconfig
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://$CONTROLLER_IP:6443 --kubeconfig=worker1.mylabserver.com.kubeconfig
kubectl config set-credentials system:node:worker1.mylabserver.com --client-certificate=worker1.mylabserver.com.pem --client-key=worker1.mylabserver.com-key.pem --embed-certs=true --kubeconfig=worker1.mylabserver.com.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:node:worker1.mylabserver.com --kubeconfig=worker1.mylabserver.com.kubeconfig
kubectl config use-context default --kubeconfig=worker1.mylabserver.com.kubeconfig
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://$CONTROLLER_IP:6443 --kubeconfig=kube-proxy.kubeconfig
kubectl config set-credentials system:kube-proxy --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=kube-proxy.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-proxy --kubeconfig=kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=kube-controller-manager.kubeconfig
kubectl config set-credentials system:kube-controller-manager --client-certificate=kube-controller-manager.pem --client-key=kube-controller-manager-key.pem --embed-certs=true --kubeconfig=kube-controller-manager.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-credentials system:kube-scheduler --client-certificate=kube-scheduler.pem --client-key=kube-scheduler-key.pem --embed-certs=true --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=admin.kubeconfig
kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem --embed-certs=true --kubeconfig=admin.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=admin --kubeconfig=admin.kubeconfig
kubectl config use-context default --kubeconfig=admin.kubeconfig
chown cloud_user:cloud_user /home/cloud_user/*.kubeconfig
#GENERATE ENCRYPTION CONFIG
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > /tmp/encryption-config.yaml << EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
#ETCD SETUP
wget -q --show-progress --https-only --timestamping "https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz"
tar -xvf etcd-v3.3.5-linux-amd64.tar.gz
mv etcd-v3.3.5-linux-amd64/etcd* /usr/local/bin/
mkdir -p /etc/etcd /var/lib/etcd
cp /home/cloud_user/ca.pem /home/cloud_user/kubernetes-key.pem /home/cloud_user/kubernetes.pem /etc/etcd/
cat << EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name controller0 \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller0=https://${CONTROLLER_IP}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
#CONTROL PLANE SETUP
mkdir -p /etc/kubernetes/config
cd /tmp
wget -q --show-progress --https-only --timestamping "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-apiserver" "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-controller-manager" "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-scheduler" "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl"
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
mkdir -p /var/lib/kubernetes/
cp /home/cloud_user/ca.pem /home/cloud_user/ca-key.pem /home/cloud_user/kubernetes-key.pem /home/cloud_user/kubernetes.pem /home/cloud_user/service-account-key.pem /home/cloud_user/service-account.pem /home/cloud_user/encryption-config.yaml /home/cloud_user/kube-controller-manager.kubeconfig /home/cloud_user/kube-scheduler.kubeconfig /var/lib/kubernetes/
cat << EOF | tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://${CONTROLLER_IP}:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2 \\
  --kubelet-preferred-address-types=InternalIP,InternalDNS,Hostname,ExternalIP,ExternalDNS
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cat << EOF | tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cat << EOF | tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
cat << EOF | tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-apiserver kube-controller-manager kube-scheduler
systemctl start kube-apiserver kube-controller-manager kube-scheduler
apt-get update
apt-get install -y nginx --fix-missing
cat > kubernetes.default.svc.cluster.local << EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
mv kubernetes.default.svc.cluster.local /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
systemctl restart nginx
systemctl enable nginx
cat << EOF | kubectl apply --kubeconfig /home/cloud_user/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
cat << EOF | kubectl apply --kubeconfig /home/cloud_user/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF