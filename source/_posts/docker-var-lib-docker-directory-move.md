title: Move the docker is /var/lib/docker directory
date: 2017-02-22
tags:
- docker
---

docker 默认的数据存储目录为：/var/lib/docker，主要的文件是/var/lib/docker/devicemapper/devicemapper/data,该文件存储docker的镜像文件，如果镜像过多经常会导致/var使用率100%，当然如果是生产环境你可能不会使用文件系统而是使用thinpool来存储镜像文件，而且一般生产上一台机器上的docker镜像和容器一般也会不过多。

下面我们分别介绍下修改thinpool和移动/var/lib/docker的基本操作：

# Docker config thin pool

about: [device-mapper-driver](https://docs.docker.com/engine/userguide/storagedriver/device-mapper-driver/)

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

# Move /var/lib/docker ( centos 7 )

```shell
systemctl stop docker
```

set in the `/etc/sysconfig/docker` file, add `-g`

```shell
OPTIONS='--selinux-enabled --log-driver=journald'
```
to 

```shell
OPTIONS='--selinux-enabled --log-driver=journald -g /data/docker/'
```

the `/data/docker/` is new docker directory

if `/var/lib/docker` have your images and want to save it. Move the data to `/data/docker` before start docker

```shell
systemctl start docker
```

link: 
[#3127](https://github.com/docker/docker/issues/3127)
[How do I change the Docker image installation directory](https://forums.docker.com/t/how-do-i-change-the-docker-image-installation-directory/1169/2)
