title: Harbor Deploy
date: 2017-04-19
tags:
- kubernetes
- harbor
- registry
---

Harbor 是企业级的docker registry版本，实际上它主要对docker registry封装了两个功能：
1.权限管理
2.同步功能

这篇文章主要介绍下harbor的部署，另外也会结合Kubernetes介绍如何在访问需要帐号的docker registry

# 环境

Centos 7
Harbor v1.1.0
Kubernetes 1.5

# 安装docker和docker-compose

harbor 官方文档使用docker-compose进行部署，当然现在也增加了部署在kubernetes上，这里选择使用docker-compose进行部署，以后有机会再研究下Kuberentes部署方式


安装docker
```
yum install docker -y

systemctl enable docker
systemctl start docker
```

安装docker-compose
```
yum install python-pip -y
pip install docker-compose
```

# 配置harbor

直接在Harbor的github上下载online安装文件：[https://github.com/vmware/harbor/releases](https://github.com/vmware/harbor/releases)

```
wget https://github.com/vmware/harbor/releases/download/v1.1.0/harbor-online-installer-v1.1.0.tgz
tar -zxf harbor-online-installer-v1.1.0.tgz
```

## 配置ssl

`/data`用于harbor的数据存储，最好挂载在存储上

```
mkdir -p /data/cert/
```

生成ssl keys
这里需要注意的是生成key过程中的Common Name填入你要使用的域名，如:reg.local.com

```
cd /data/cert/
$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 365 -out ca.crt
Generating a 4096 bit RSA private key
...........................................................................................................................................................................................................................................................................................................................................................................................++
..++
writing new private key to 'ca.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:
State or Province Name (full name) []:
Locality Name (eg, city) [Default City]:
Organization Name (eg, company) [Default Company Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (eg, your name or your server's hostname) []:reg.local.com
Email Address []:

$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout server.key -out server.csr
Generating a 4096 bit RSA private key
..........................................................................................................................................................................++
...................................................................................++
writing new private key to 'server.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:
State or Province Name (full name) []:
Locality Name (eg, city) [Default City]:
Organization Name (eg, company) [Default Company Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (eg, your name or your server's hostname) []:reg.local.com
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
 
$ openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt
Signature ok
subject=/C=XX/L=Default City/O=Default Company Ltd/CN=reg.local.com
Getting CA Private Key
```

这里不详细介绍这几个key的原理了，大家可以自行baidu，ssl key还是建议大家去研究下，毕竟很多产品部署都会用到

## 修改配置文件：harbor.cfg

- hostname 如果是域名访问则设置成域名，否则使用IP，本文使用：reg.local.com
- db_password MySQL的数据库密码
- harbor_admin_password Harbor默认的管理员admin的密码

其他参数可以不修改，但需要注意默认的ssl key配置的路径和文件名和我们生成的是一样的，如果不一样需要修改对应的配置

## Install

```
./install.sh
```

这里会执行一堆检查，然后启动docker-compose来拉去harbor使用的几个docker，执行时间主要依赖你的网络拉去镜像的速度。

如果这一步没有报错harbor就部署完成了。

查看harbor启动情况
```
# docker ps
CONTAINER ID        IMAGE                              COMMAND                  CREATED             STATUS              PORTS                                                              NAMES
15452d1c314e        vmware/nginx:1.11.5-patched        "nginx -g 'daemon off"   20 hours ago        Up 20 hours         0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 0.0.0.0:4443->4443/tcp   nginx
252065f73780        vmware/harbor-jobservice:v1.1.0    "/harbor/harbor_jobse"   20 hours ago        Up 20 hours                                                                            harbor-jobservice
281a82e4373c        vmware/harbor-ui:v1.1.0            "/harbor/harbor_ui"      20 hours ago        Up 20 hours                                                                            harbor-ui
644245ba9fbf        vmware/harbor-adminserver:v1.1.0   "/harbor/harbor_admin"   21 hours ago        Up 20 hours                                                                            harbor-adminserver
02900a2759b6        vmware/harbor-db:v1.1.0            "docker-entrypoint.sh"   21 hours ago        Up 20 hours         3306/tcp                                                           harbor-db
814b2c0df893        vmware/registry:photon-2.6.0       "/entrypoint.sh serve"   21 hours ago        Up 20 hours         5000/tcp                                                           registry
ee32489ccee9        vmware/harbor-log:v1.1.0           "/bin/sh -c 'crond &&"   21 hours ago        Up 20 hours         127.0.0.1:1514->514/tcp                                            harbor-log
```

接下来将域名reg.local.com配置指向Harbor部署的机器，就可以通过浏览器访问：https://reg.local.com
帐号为admin, 密码在harbor.cfg的harbor_admin_password配置的：Harbor12345

# harbor 基本维护操作

```
cd ~/harbor
docker-compose down
docker-compose start
```

# docker 使用

docker 要连接harbor需要两个条件
1. ca证书
2. 帐号密码

ca证书就是我们刚才生成的文件ca.crt证书，该证书需要放置在要访问harbor的机器的`/etc/docker/certs.d`目录

创建证书目录，证书目录使用域名作为目录名称
```
mkdir -p /etc/docker/certs.d/reg.local.com
```

将ca.crt放置在上述目录
```
mv ca.crt /etc/docker/certs.d/reg.local.com
```

登录harbor
```
$ docker login reg.local.com
Username (test): test
Password: 
WARNING: login credentials saved in /home/docker/.docker/config.json
Login Succeeded
```

登录的帐号可以是admin，也可以是其他你通过web上创建的帐号

注意上面的WARNING，它告诉我们auth key放置在文件`/home/docker/.docker/config.json`中（我发现在archlinux如果你用非root帐号执行，这个key也是会放到`/home/root/.docker/config.json`中）

这个auth key在结合其他产品的时候会用到，如kubernetes、drone等

push镜像
```
$ docker tag busybox reg.local.com/test/busybox
$ docker push reg.local.com/test/busybox
The push refers to a repository [reg.local.com/test/busybox]
c0de73ac9968: Layer already exists 
latest: digest: sha256:92b7c19467bf868e52949d7e5404e309486ba9ee7eb4b88b882747ee1522d3cd size: 505
```

# kubernetes连接harbor

需要几个东西
1. docker 的 auth key
2. ca.crt证书
3. 帐号的secret

获取k8s所有node的ip
```
$ nodes=$(kubectl get nodes -o jsonpath='{range.items[*].status.addresses[?(@.type=="InternalIP")]}{.address} {end}')
$ echo $nodes
192.168.1.1 192.168.1.2 192.168.1.3
```

使用`docker login reg.local.com`生成auth key

这里默认为`~/.docker/config.json`

```
$ cat ~/.docker/config.json
{
        "auths": {
                "reg.local.com": {
                        "auth": "dGVzdDpEWFEefMTIzNDU=",
                        "email": "test@local.com"
                }
        }
}
```

复制auth key到所有节点
```
$ for n in $nodes; do ssh root@$n mkdir -p /root/.docker; scp ~/.docker/config.json root@$n:/root/.docker/config.json; done
```

复制ca.crt到所有节点
```
$ cert_path="/etc/docker/certs.d/reg.local.com"
for n in $nodes; do ssh root@$n mkdir -p $cert_path; scp $cert_path/ca.crt root@$n:$cert_path/ca.crt; done
```

创建帐号secret
```
kubectl create secret docker-registry myregistrykey --docker-server=reg.local.com --docker-username=test --docker-password=Test12345 --docker-email=test@local.com
```

pod配置中增加`imagePullSecrets`
```
apiVersion: v1
kind: Pod
metadata:
  name: busybox
spec:
  containers:
  - image: reg.local.com/test/busybox
    imagePullPolicy: IfNotPresent
    name: busybox
    command:
      - sleep
      - "3600"
  restartPolicy: Always
  imagePullSecrets:
    - name: myregistrykey
```

# 总结

到这里docker和kubernetes都可以访问harbor

下次有机会介绍下几个内容：
- harbor的ha方案，基于它自己提供的复制功能
- harbor部署在kubernetes上
