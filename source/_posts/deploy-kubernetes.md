title: Deploy kubernetes by manual
date: 2017-01-18 15:00:00
tags:
- docker
- kubernetes
---


# Docker no need root

```shell
sudo groupadd docker
sudo usermod -aG docker $(whoami)
sudo systemctl restart docker

Logout
Login
```

# Docker config thin pool

about: https://docs.docker.com/engine/userguide/storagedriver/device-mapper-driver/

```shell
systemctl stop docker
rm -rf /var/lib/docker

pvcreate /dev/vdb
vgcreate docker /dev/vdb

cat << EOF > /etc/sysconfig/docker-storage-setup
STORAGE_DRIVER=devicemapper
VG=docker
EXTRA_DOCKER_STORAGE_OPTIONS=" --storage-opt dm.use_deferred_removal=true"
EOF

docker-storage-setup

systemctl daemon-reload
systemctl start docker
```
# Docker logs

Modify the docker logs from journald to json-file on centos 7

```shell
vi /etc/sysconfig/docker

# replice
OPTIONS='--selinux-enabled --log-driver=journald'
# to
OPTIONS='--selinux-enabled --log-driver=json-file'

systemctl restart docker
```

# Install by Tarballs

*Note: 部署的时候最好关闭selinux，否则像 nfs会挂载失败*

修改hostname

```shell
echo "k8s_nX.kubernetes.com" > /etc/hostname
```

### on all machine

```shell
sudo systemctl stop firewalld
sudo systemctl disable firewalld

sudo yum -y install ntp
sudo systemctl start ntpd
sudo systemctl enable ntpd
sudo systemctl status ntpd

sudo useradd -u 1008 k8s -m && sudo passwd k8s
```

add k8s user
```shell
sudo echo "" >> /etc/sudoers
sudo echo "#add k8s user" >> /etc/sudoers
sudo echo "k8s ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
```

### on master

etcd download from: https://github.com/coreos/etcd/releases

```shell
tar -zxf etcd-v3.0.9-linux-amd64.tar.gz
ln -s etcd-v3.0.9-linux-amd64 etcd
cd etcd
cat <<EOF > etcd-start.sh
#! /bin/sh

THIS_IP=10.10.10.214

export ETCD_NAME="k8s_node_1"
export ETCD_INITIAL_CLUSTER="k8s_master_1=http://10.10.10.93:2380,k8s_node_1=http://10.10.10.214:2380"
export ETCD_INITIAL_CLUSTER_STATE="existing"

./etcd \
--data-dir=data \
--initial-advertise-peer-urls http://${THIS_IP}:2380 \
--listen-peer-urls http://${THIS_IP}:2380 \
--advertise-client-urls http://${THIS_IP}:2379 \
--listen-client-urls http://${THIS_IP}:2379,http://127.0.0.1:2379 > etcd.log 2>&1
EOF
chmod a+x etcd-start.sh
./etcd-start.sh

./etcdctl mk /flannel/network/config '{"Network":"172.1.0.0/16"}'
```

kubernetes download from: https://github.com/kubernetes/kubernetes/releases

```shell
tar zxf kubernetes.tar.gz
cd kubernetes/server
tar zxf kubernetes-server-linux-amd64.tar.gz
cd kubernetes/server/bin
mkdir -p ~/kubernetes-master/log
cp kube-apiserver kube-controller-manager kubectl kube-dns kube-scheduler ~/kubernetes-master/

echo "export PATH=~/kubernetes-master:\$PATH" >> ~/.bash_profile
# relogin

cd ~/kubernetes-master
cat <<EOF > init.sh
#! /bin/sh

KUBE_MASTER=192.168.72.128

# Change to root auth
sudo chown root.root kube-dns
sudo chmod u+s kube-dns

mkdir -p ~/kubernetes-master/log

# generate kubernetes keys
mkdir -p ~/kubernetes-master/certs
cd ~/kubernetes-master/certs
rm -rf ~/kubernetes-master/certs/*

openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=${KUBE_MASTER}" -days 10000 -out ca.crt

openssl genrsa -out apiserver.key 2048
openssl req -new -key apiserver.key -subj "/CN=${KUBE_MASTER}" -out apiserver.csr
openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver.crt -days 10000

openssl genrsa -out cs_client.key 2048
openssl req -new -key cs_client.key -subj "/CN=${KUBE_MASTER}" -out cs_client.csr
openssl x509 -req -in cs_client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out cs_client.crt -days 10000

openssl genrsa -out kubelet_client.key 2048
openssl req -new -key kubelet_client.key -subj "/CN=192.168.1.129" -out kubelet_client.csr
openssl x509 -req -in kubelet_client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kubelet_client.crt -days 10000

> abac.csv
# user
# readonly
# kind: pods, events
# namespace
echo '{"user":"dean"}' >> abac.csv
echo '{"user":"kubelet"}' >> abac.csv

> basic_auth.csv
echo "dean.wu,dean,dean" >> basic_auth.csv
echo "kubelet.wu,kubelet,kubelet" >> basic_auth.csv

# Generate kubeconfig
CLUSTER_NICK="k8s-zeusis-qcloud"
CONTEXT_NAME="kzq"
USER_ID="dean"
USER="dean"
PASSWORD="dean.wu"

cd ~/kubernetes-master
## create kubeconfig entry
./kubectl config set-cluster $CLUSTER_NICK \
    --server=https://$KUBE_MASTER:6450 \
    --insecure-skip-tls-verify=true \
    --kubeconfig=/home/k8s/.kube/config

## create user entry
./kubectl config set-credentials $USER_ID \
    --username=$USER \
    --password=$PASSWORD \
    --kubeconfig=/home/k8s/.kube/config

## create context entry
./kubectl config set-context $CONTEXT_NAME \
    --cluster=$CLUSTER_NICK \
    --user=$USER_ID \
    --kubeconfig=/home/k8s/.kube/config

./kubectl config use-context $CONTEXT_NAME \
    --kubeconfig=/home/k8s/.kube/config
EOF
chmod a+x init.sh
./init.sh

cat <<EOF > start_k8s_api.sh
#! /bin/sh

# start the main server of k8s master
sudo ./kube-apiserver \
    --insecure-bind-address=0.0.0.0 \
    --insecure-port=6550 \
    --bind-address=0.0.0.0 \
    --secure-port=6450 \
    --etcd_servers=http://192.168.72.128:2379,http://192.168.72.63:2379,http://192.168.72.233:2379 \
    --client-ca-file="certs/ca.crt" \
    --tls-cert-file="certs/apiserver.crt" \
    --tls-private-key-file="certs/apiserver.key" \
    --allow-privileged=true \
    --basic_auth_file="certs/basic_auth.csv" \
    --authorization_mode=ABAC \
    --authorization_policy_file="certs/abac.csv" \
    --service-cluster-ip-range=182.1.0.0/16 \
    --log-dir="log" \
> k8s-api.log 2>&1
EOF
chmod a+x start_k8s_api.sh

cat <<EOF > start_k8s_cm.sh
#! /bin/sh

./kube-controller-manager \
    --master="http://127.0.0.1:6550" \
    --log-dir="log" \
> k8s-cm.log 2>&1
EOF
chmod a+x start_k8s_cm.sh

cat <<EOF > start_k8s_dns.sh
#! /bin/sh

KUBE_DOMAIN="zeusis.local"

sudo ./kube-dns \
    --domain=${KUBE_DOMAIN} \
    --kube-master-url="http://127.0.0.1:6550" \
    --dns-port=53 \
    --log-dir="log" \
> k8s-dns.log 2>&1
EOF
chmod a+x start_k8s_dns.sh

cat <<EOF > start_k8s_scd.sh
#! /bin/sh

./kube-scheduler \
    --master="http://127.0.0.1:6550" \
    --log-dir="log" \
> k8s-scd.log 2>&1
EOF
chmod a+x start_k8s_scd.sh
```

start master

```shell
cd ~/etcd
./start_etcd.sh

cd ~/kubernetes
./start_k8s_api.sh
./start_k8s_dns.sh
./start_k8s_cm.sh
./start_k8s_scd.sh
```

### on minions

flannel download from: https://github.com/coreos/flannel/releases

```shell
tar -zxf flannel-v0.6.1-linux-amd64.tar.gz
mkdir flannel
mv flannel-v0.6.1-linux-amd64.tar.gz flannel
cd ~/flannel/
tar -zxf flannel-v0.6.1-linux-amd64.tar.gz

cat <<EOF > flanneld-start.sh
#! /bin/sh

ETCD_PREFIX=/flannel/network

# delete docker0. it will recreate in docker starting
rc=0
ip link show docker0 >/dev/null 2>&1 || rc="$?"
if [[ "$rc" -eq "0" ]]; then
  sudo ip link set dev docker0 down
  sudo ip link delete docker0
fi

sudo ./flanneld \
    --ip-masq \
    --subnet-file="run/subnet.env" \
    --etcd-endpoints=http://192.168.72.128:2379,http://192.168.72.63:2379,http://192.168.72.233:2379 \
    --etcd-prefix=$ETCD_PREFIX > flanneld.log 2>&1
EOF
chmod a+x flanneld-start.sh
```

kubernetes

```shell
tar zxf kubernetes.tar.gz
cd kubernetes/server
tar zxf kubernetes-server-linux-amd64.tar.gz
cd kubernetes/server/bin
mkdir -p ~/kubernetes/log
mkdir -p ~/kubernetes/cert
mv kubelet kube-proxy ~/kubernetes/

cd ~/kubernetes

cat <<EOF > k8s-let-start.sh
#! /bin/sh

KUBE_MASTER=192.168.72.128
NODE_IP=192.168.72.128
CLUSTER_DOMAIN=zeusis.local

sudo ./kubelet \
    --address=0.0.0.0 \
    --port=10250 \
    --hostname_override=$NODE_IP \
    --require-kubeconfig=true \
    --kubeconfig="/home/k8s/kubernetes/kubeconfig" \
    --cni-bin-dir=cni/bin \
    --cni-conf-dir=cni/net.d \
    --logtostderr=false \
    --allow-privileged=true \
    --pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest \
    --cluster-dns=$KUBE_MASTER \
    --cluster-domain=$CLUSTER_DOMAIN \
    --pod-manifest-path="manifests" \
    --log-dir="log" > k8s-let.log 2>&1
EOF
chmod a+x k8s-let-start.sh

cat <<EOF > k8s-proxy-start.sh
#! /bin/sh

NODE_IP=192.168.72.128

sudo ./kube-proxy \
    --kubeconfig="/home/k8s/kubernetes/kubeconfig" \
    --hostname_override=$NODE_IP \
    --proxy-mode=iptables \
    --log-dir="log" > k8s-proxy.log 2>&1
EOF
chmod a+x k8s-proxy-start.sh
```

init & start minion

```shell
cd ~/flannel
./start_flanneld.sh

# only by first start
sudo ./mk-docker-opts.sh -f ./run/subnet.env -d ./run/docker.env
cat ./run/docker.env | grep -i DOCKER_OPTS
# copy DOCKER_OPTS values write into sudo vi /etc/sysconfig/docker-network
DOCKER_NETWORK_OPTIONS=" --bip=172.17.95.1/24 --mtu=1472"

sudo systemctl restart docker
```

ensure the docker0 and flannel0 in the same subnet

```shell
ip a | grep -i 172
```

start kubelet

```shell
cd ~/kubernetes
./start_k8s_let.sh
./start_k8s_proxy.sh
```

## config dashboard

1. first: init a flannel and start the docker on master. Bacause the master need to access dashboard pod on node.
2. second:
kubectl create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
https://10.0.12.203/ui

# [Private Registry](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/registry)

disable selinux, it will block nfs to mount

config nfs to export a registry images' directory

create pv, pvc, and deployment

default, the private registry is use http

config docker

```shell
# using domain
ssh root@192.168.72.63 mkdir -p /etc/docker/certs.d/k8s-registry.zeusis.com:32000
scp domain-crt root@192.168.72.63:/etc/docker/certs.d/k8s-registry.zeusis.com:32000/ca.crt

# using ip
sudo vi /etc/sysconfig/docker
modified the "INSECURE_REGISTRY='--insecure-registry'" to "INSECURE_REGISTRY='--insecure-registry 119.29.43.190:32000'"

# restart & test
sudo systemctl restart docker
docker tag ubuntu:16.10 119.29.43.190:32000/ubuntu:16.10
docker push 119.29.43.190:32000/ubuntu:16.10
```

# static pod

1. create the directory
```shell
mkdir /etc/kubernetes.d
```

2. copy static pod yaml to the directory
```shell
cp etcd.yaml /etc/kubernetes.d
```

3. start kubelet with --config to point the directory
```shell
kubelet --config=/etc/kubelet.d/
```

# kubernetes ha

## clustering etcd

1. use etcd discovery
```
curl https://discovery.etcd.io/new?size=3
https://discovery.etcd.io/547ded311f3698c8b1f4c97043fea03c
```

2. config statis pod on each node
    - you should substitute the token url you got above for ${DISCOVERY_TOKEN}
    - setting the ${NODE_NAME} and ${NODE_IP}

3. validating cluster

You can validate on master

```shell
kubectl exec < pod_name > etcdctl member list
kubectl exec < pod_name > etcdctl cluster-health
```
