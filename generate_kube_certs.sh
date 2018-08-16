# install cfssl and generate Kubernetes CA and certs
# Required env vars: CONTROLLER0_IP, CONTROLLER1_IP
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
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -hostname=172.34.1.0,worker0.mylabserver.com -profile=kubernetes /tmp/worker0.mylabserver.com-csr.json | cfssljson -bare worker0.mylabserver.com
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -hostname=172.34.1.1,worker1.mylabserver.com -profile=kubernetes /tmp/worker1.mylabserver.com-csr.json | cfssljson -bare worker1.mylabserver.com
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/kube-proxy-csr.json | cfssljson -bare kube-proxy
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/kube-scheduler-csr.json | cfssljson -bare kube-scheduler
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -hostname=10.32.0.1,$CONTROLLER0_IP,controller0.mylabserver.com,$CONTROLLER1_IP,controller1.mylabserver.com,172.34.2.0,kubernetes.mylabserver.com,127.0.0.1,localhost,kubernetes.default -profile=kubernetes /tmp/kubernetes-csr.json | cfssljson -bare kubernetes
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=kubernetes /tmp/service-account-csr.json | cfssljson -bare service-account