---
title: kuberntes heapster cannot write to influxdb
date: 2017-02-06
tags:
- kubernetes
- heapster
---

kubernetes 1.5
heapster 1.2
influxdb 1.2

heapster启动后自动在influxdb中创建了k8s的数据库，但是没有任何数据写入

heapster未见任何错误日志

influxdb日志如下：

```
[httpd] 192.168.56.207 - root [20/Jan/2017:20:44:05 +0000] "POST /write?consistency=&db=k8s&precision=&rp=default HTTP/1.1" 500 72 "-" "heapster/v1.3.0-beta.0" 2ece120b-df51-11e6-808e-000000000000 15630
[httpd] 192.168.56.207 - root [20/Jan/2017:20:44:05 +0000] "GET /ping HTTP/1.1" 204 0 "-" "heapster/v1.3.0-beta.0" 2ed087a5-df51-11e6-808f-000000000000 14
```

该问题为heapster和influxdb版本不兼容导致，

heapster在创建k8s后默认使用default 的retention，因为influxdb1.2默认retention是autogen导致heapster无法使用到default导致数据写入失败

解决办法：
在k8s库下面创建default的retention

```
create retention policy "default" on "k8s" duration 0d replication 1 default
```

link: 
[heapster issues 1474](https://github.com/kubernetes/heapster/issues/1474)
