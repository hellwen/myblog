---
title: Docker Thin pool
date: 2017-01-18
tags:
- docker
---

Docker默认使用文件系统来存储image和container信息，container在运行的时候经常会访问文件系统，这会导致文件系统的性能影响到container的运行。Docker官方推荐一个更适合用于生产环境的thin pool方案。

详细介绍可以查看docker.com中的[device-mapper-driver](https://docs.docker.com/engine/userguide/storagedriver/device-mapper-driver/)

下面是thin pool的配置

## 停止docker

```
systemctl stop docker
```

## 删除原有docker配置文件

```
rm -rf /var/lib/docker
```

## 创建用于docker的vg

```
pvcreate /dev/vdb
vgcreate docker /dev/vdb
```

## 修改docker-storage-setup

```
cat << EOF > /etc/sysconfig/docker-storage-setup
STORAGE_DRIVER=devicemapper
VG=docker
EXTRA_DOCKER_STORAGE_OPTIONS=" --storage-opt dm.use_deferred_removal=true"
EOF
```

## 更新docker-storage配置

```
docker-storage-setup
```

## 重启docker

```
systemctl daemon-reload
systemctl start docker
```

配置完成后，使用lvs你可以看到有一个docker-pool的lv

Done
