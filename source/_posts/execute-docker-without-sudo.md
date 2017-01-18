title: 使用docker命令时需要sudo问题
date: 2017-01-18 16:00:00
tags:
- docker
---

默认安装完docker后，在使用如docker ps等命令的时候要么使用root帐号，要么需要sudo docker ps。这是因为docker在设计的时候并未考虑安全问题，所以docker理论上需要在root环境下才能运行。

这里介绍一个使用非root用户执行docker命令不需要sudo的方法，该方法是利用docker这个用户组来进行配置：

创建docker用户组
```
sudo groupadd docker
```

把当前用户添加到docker组中
```
sudo usermod -aG docker $(whoami)
```

重启docker
```
sudo systemctl restart docker
```

重新登录即可
```
docker ps
```

Done
