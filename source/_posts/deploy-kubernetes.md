title: Deploy kubernetes by manual on centos 7
date: 2017-01-18 15:00:00
tags:
- docker
- kubernetes
---



# 环境信息

|ip|role|hostname|
|--|----|--------|
|10.10.0.1|master&minion|k8s-master-1|
|10.10.0.2|minion|k8s-node-1|
|10.10.0.3|minion|k8s-node-2|

# on all machine

*Note: 部署的时候最好关闭selinux，否则像 nfs会挂载失败(nfs用于使用pv，不是必须的)*

## 修改hostname

用户名建议使用中横杠，因为后面在进行kubernetes配置的时候可以直接使用hostname作为节点名称

```shell
echo "k8s-node-xx" > /etc/hostname
```

## 基本配置

关闭防火墙
安装ntp

```shell
sudo systemctl stop firewalld
sudo systemctl disable firewalld

sudo yum -y install ntp
sudo systemctl start ntpd
sudo systemctl enable ntpd
sudo systemctl status ntpd
```

创建k8s帐号和sudo

```
sudo useradd -u 1008 k8s -m && sudo passwd k8s

sudo echo "" >> /etc/sudoers
sudo echo "#add k8s user" >> /etc/sudoers
sudo echo "k8s ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
```

从下面开始所以操作都是在k8s这个用户下进行

# on master

## etcd

### Download && Install etcd

etcd是类似与zookeeper的分布式配置存储解决方案，特意加了“配置”两个字是因为它的设计目标主要是用来存储配置文件

下载地址：[etcd v3.0.9](https://github.com/coreos/etcd/releases/download/v3.0.9/etcd-v3.0.9-linux-amd64.tar.gz)

```shell
wget https://github.com/coreos/etcd/releases/download/v3.0.9/etcd-v3.0.9-linux-amd64.tar.gz
tar -zxf etcd-v3.0.9-linux-amd64.tar.gz
ln -s etcd-v3.0.9-linux-amd64 etcd
```

### 启动配置脚本

因为这是实验环境，所以这里的etcd只使用一个节点，如果你是用于生产环境建议配置3个以上的etcd节点

```
cd ~/etcd
cat <<EOF > etcd-start.sh
#! /bin/sh

THIS_IP=10.10.0.1

./etcd \
--name=infra1 \
--advertise-client-urls http://${THIS_IP}:2379 \
--listen-client-urls http://${THIS_IP}:2379,http://127.0.0.1:2379 \
--data-dir=data  \
1> etcd.log 2>&1
EOF
chmod a+x etcd-start.sh
```

### 使用配置脚本启动etcd

```
./etcd-start.sh
```

### 测试etcd

```
./etcdctl ls
```

如果上述命令成功，那么etcd处于正常运行中

### 添加flannel的网络地址范围到etcd中

```
cd ~/etcd
./etcdctl mk /flannel/network/config '{"Network":"172.1.0.0/16"}'
```

其中 /flannel/network/config这个地址是可以自己指定的，需要配置到flannel中

## Kubernetes

### 下载并配置kubernetes

kubernetes因为发布节奏很快，所以各种仓库都不会及时更新，所以本文采用手动安装方式，安装包可以直接在github上下载

下载地址：[kubernetes v1.4.6](https://github.com/kubernetes/kubernetes/releases/download/v1.4.6/kubernetes.tar.gz)

这里需要注意，kubernetes v1.5以后不再提供bin文件，所以你如果下载1.5以后的版本需要另外下载bin文件

```shell
wget https://github.com/kubernetes/kubernetes/releases/download/v1.4.6/kubernetes.tar.gz
tar zxf kubernetes.tar.gz
cd kubernetes/server
tar zxf kubernetes-server-linux-amd64.tar.gz
cd kubernetes/server/bin
mkdir -p ~/kubernetes-master/log
cp kube-apiserver kube-controller-manager kubectl kube-dns kube-scheduler ~/kubernetes-master/

# 将bin添加到path中
echo "export PATH=~/kubernetes-master:\$PATH" >> ~/.bash_profile

source ~/.bash_profile
```

### init配置文件

```
cd ~/kubernetes-master
cat <<EOF > init.sh
#! /bin/sh

KUBE_MASTER=10.10.0.1

# Change to root auth
sudo chown root.root kube-dns
sudo chmod u+s kube-dns
EOF
chmod a+x init.sh
./init.sh
```

kube-dns需要使用root权限

### api启动配置文件

```
cd ~/kubernetes-master
cat <<EOF > start_k8s_api.sh
#! /bin/sh

# start the main server of k8s master
sudo ./kube-apiserver \
    --bind-address=0.0.0.0 \
    --insecure-bind-address=0.0.0.0 \
    --insecure-port=8080 \
    --etcd_servers=http://10.10.0.1:2379 \
    --allow-privileged=true \
    --service-cluster-ip-range=182.1.0.0/16 \
    --log-dir="log" \
1> k8s-api.log 2>&1
EOF
chmod a+x start_k8s_api.sh
```

### controller-manager配置文件

```
cd ~/kubernetes-master
cat <<EOF > start_k8s_cm.sh
#! /bin/sh

./kube-controller-manager \
    --master="http://127.0.0.1:8080" \
    --log-dir="log" \
1> k8s-cm.log 2>&1
EOF
chmod a+x start_k8s_cm.sh
```

### dns配置文件

```
cd ~/kubernetes-master
cat <<EOF > start_k8s_dns.sh
#! /bin/sh

KUBE_DOMAIN="cluster.local"

sudo ./kube-dns \
    --domain=${KUBE_DOMAIN} \
    --kube-master-url="http://127.0.0.1:8080" \
    --dns-port=53 \
    --log-dir="log" \
1> k8s-dns.log 2>&1
EOF
chmod a+x start_k8s_dns.sh
```

### scheduler配置文件

```
cd ~/kubernetes-master
cat <<EOF > start_k8s_scd.sh
#! /bin/sh

./kube-scheduler \
    --master="http://127.0.0.1:8080" \
    --log-dir="log" \
1> k8s-scd.log 2>&1
EOF
chmod a+x start_k8s_scd.sh
```

### start master

```shell
cd ~/etcd
./start_etcd.sh

cd ~/kubernetes-master
./start_k8s_api.sh
./start_k8s_dns.sh
./start_k8s_cm.sh
./start_k8s_scd.sh
```

# on minions

minion需要部署所有机器上
master上也需要部署minion

## flannel

### Download && Install flannel

[flannel v0.6.1](https://github.com/coreos/flannel/releases/download/v0.6.1/flannel-v0.6.1-linux-amd64.tar.gz)

```shell
cd ~
wget https://github.com/coreos/flannel/releases/download/v0.6.1/flannel-v0.6.1-linux-amd64.tar.gz
tar -zxf flannel-v0.6.1-linux-amd64.tar.gz
mkdir flannel
mv flannel-v0.6.1-linux-amd64.tar.gz flannel
cd ~/flannel/
tar -zxf flannel-v0.6.1-linux-amd64.tar.gz
```

### 启动配置脚本

```
cd ~/flannel
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
    --etcd-endpoints=http://10.10.0.1:2379 \
    --etcd-prefix=$ETCD_PREFIX > flanneld.log 2>&1
EOF
chmod a+x flanneld-start.sh
```
## kubernetes

```shell
wget https://github.com/kubernetes/kubernetes/releases/download/v1.4.6/kubernetes.tar.gz
tar zxf kubernetes.tar.gz
cd kubernetes/server
tar zxf kubernetes-server-linux-amd64.tar.gz
cd kubernetes/server/bin
mkdir -p ~/kubernetes/log
mkdir -p ~/kubernetes/cert
mv kubelet kube-proxy ~/kubernetes/
```

### kubeconfig配置文件

```
cat << EOF > /home/k8s/kubernetes/kubeconfig
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://10.10.0.1:8080
  name: k8s-cluster
contexts:
- context:
    cluster: k8s-cluster
    namespace: default
  name: dft
- context:
    cluster: k8s-cluster
    namespace: kube-system
  name: sys
current-context: dft
kind: Config
preferences: {}
EOF
```

### kubelet配置文件

NODE_IP分别指定两台minion机器，分别是10.10.0.2和10.10.0.3

```
cd ~/kubernetes
cat <<EOF > k8s-let-start.sh
#! /bin/sh

KUBE_MASTER=10.10.0.1
NODE_IP=10.10.0.1
CLUSTER_DOMAIN=cluster.local

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
    --log-dir="log" \
1> k8s-let.log 2>&1
EOF
chmod a+x k8s-let-start.sh
```

### kube-proxy配置文件

```
cd ~/kubernetes
cat <<EOF > k8s-proxy-start.sh
#! /bin/sh

NODE_IP=10.10.0.1

sudo ./kube-proxy \
    --kubeconfig="/home/k8s/kubernetes/kubeconfig" \
    --hostname_override=$NODE_IP \
    --proxy-mode=iptables \
    --log-dir="log" \
1> k8s-proxy.log 2>&1
EOF
chmod a+x k8s-proxy-start.sh
```

## Init & Start minion

### 配置flannel和docker0

启动flannel

```shell
cd ~/flannel
./start_flanneld.sh
```

如果是第一次启动需要进行docker的ip配置

```
sudo ./mk-docker-opts.sh -f ./run/subnet.env -d ./run/docker.env
cat ./run/docker.env | grep -i DOCKER_OPTS
```

记录下上面命令输出的内容，内容大概如下：

```
--bip=172.17.95.1/24 --mtu=1472
```

编辑docker-network，并修改DOCKER_NETWORK_OPTIONS参数，填入上面输出的内容

类似与下面的结果：

```
sudo vi /etc/sysconfig/docker-network
DOCKER_NETWORK_OPTIONS=" --bip=172.17.95.1/24 --mtu=1472"
```

上述步骤是用于配置docker0中可分配的网段，如果使用yum install flannel在启动时会自动配置

重新启动docker

```
sudo systemctl restart docker
```

通过ip a确定docker0和flannel0是在同一个网段

```shell
ip a
```

### start kubelet

```shell
cd ~/kubernetes
./start_k8s_let.sh
./start_k8s_proxy.sh
```

相同的步骤配置10.10.0.2和10.10.0.3
配置完成后三个节点都会加入到集群中

# 验证

登录到10.10.0.1上

```
kubectl get no
```

检查上个节点是否已配置完成

Done
