# Generate files for a single controller lab setup
# Required env vars: CONTROLLER_IP, CONTROLLER_PUBLIC_IP, INTERNAL_IP, WORKER0_IP, WORKER1_IP
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
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -hostname=10.32.0.1,$CONTROLLER_IP,$CONTROLLER_PUBLIC_IP,127.0.0.1,localhost,kubernetes.default -profile=kubernetes /tmp/kubernetes-csr.json | cfssljson -bare kubernetes
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
#MOVE AND CHOWN FILES
cp /tmp/ca.pem /tmp/ca-key.pem /tmp/kubernetes.pem /tmp/kubernetes-key.pem /tmp/service-account.pem /tmp/service-account-key.pem /tmp/kube-controller-manager.kubeconfig /tmp/kube-scheduler.kubeconfig /tmp/admin.kubeconfig /tmp/encryption-config.yaml /home/cloud_user
chown cloud_user:cloud_user /home/cloud_user/*.pem /home/cloud_user/*.kubeconfig /home/cloud_user/encryption-config.yaml
