title: kuberntes rollout update
date: 2017-03-08
tags:
- kubernetes
- rollout
---

# “灰度”发布

这次聊聊“灰度”发布（也叫“滚动”发布）

因为互联网或者说网络的发展速度太快导致竞争力很大，各家公司为了保证为用户提供更好的体验就慢慢出现了“灰度”发布这种业务零中断的发布方式。

所谓的“灰度”发布是指为了让老版本更新成新版本，以及为了更充分测试老版本会让部署在生产环境的应用处于老版本和新版本共存，并逐渐过度到新版本的一种发布方式。

其实应用很容易支持“灰度”发布，因为它是无状态的。但是如果应用依赖了数据库那么它就可能变成“有状态”。这里的可能是指当需要变更数据库的时候它是有状态，如果不需要变更数据库它依然是无状态。

所以为了让应用可以支持“灰度”发布，就应该考虑好数据库的依赖问题，主要有两个方面：
1. 在对事务要求不高的应用上使用非关系数据库，如，mongo，hbase等这类弱模式的数据库。这样在进行应用变更时可以动态变更数据库的表结构（或者说无需变更表结构）
2. 在设计关系数据库时需要考虑好扩容问题，应避免因表结构变动影响到新老应用的兼容问题

在容器之前一般有两种办法进行“灰度发布”：
1. 最早采用手工一台一台应用进行发布
2. 采用部署工具，比如salt或者ansible等进行自动发布

不管采用哪种方式，其原理都是一样的：
1. 部署一台新的应用
2. 验证新应用是否正常
3. 正常后停掉一台老应用
4. 继续1-3步骤，直到所有应用升级完成

我们目前大部分应用采用的是kubernetes进行的容器化部署，kubernetes本身有一个“滚动”发布的功能用于进行“灰度”发布。下面我们来测试下kuberentes的“滚动”发布是如果玩的。

# 基础测试程序

这里准备了一个叫做testpage的简单应用，这个应用提供一个rest的访问接口返回自身ip和版本，如：I am: 172.1.62.11, the version is: 0.5

Dockerfile:
```shell
FROM python:2.7-alpine

ADD testpage.py /testpage.py

CMD ["python", "/testpage.py"]

EXPOSE 8080
```

testpage.py:
```python
#-*- coding:utf-8 -*-

#----------------------------------------------------------------------
import socket
import fcntl
import struct

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])

#----------------------------------------------------------------------
import BaseHTTPServer
import os


class RequestHandler(BaseHTTPServer.BaseHTTPRequestHandler):

    Page = 'I am: %s, the version is: %s\n' % (get_ip_address('eth0'), os.environ.get('VERSION'))

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(self.Page)))
        self.end_headers()
        self.wfile.write(self.Page)

#----------------------------------------------------------------------

if __name__ == '__main__':
    serverAddress = ('', 8080)
    server = BaseHTTPServer.HTTPServer(serverAddress, RequestHandler)
    server.serve_forever()
```

python脚本启动一个web服务，接受一个VERSION的操作系统环境变量，然后将自身的ip和version返回

build好上述镜像，取名testpage:[version]

# kubernetes的部署脚本（如果你不会写k8s的yaml需要自己去kubernetes.io脑补下）

service是为了让集群外的测试脚本可以访问到容器，不是必须

service.yaml
```yaml
kind: Service
apiVersion: v1
metadata:
  name: testpage
  namespace: default
  labels:
    type: testpage
spec:
  type: NodePort
  ports:
  - port: 8080
    nodePort: 21000
  selector:
    type: testpage
```

deployment.yaml
```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: testpage
  namespace: default
  labels:
    type: testpage
spec:
  replicas: 3
  revisionHistoryLimit: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        type: testpage
    spec:
      containers:
      - name: testpage
        image: dean/testpage:0.5
        imagePullPolicy: Always
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
        env:
        - name: VERSION
          value: "0.5"
        ports:
        - containerPort: 8080
        readinessProbe:
          tcpSocket:
            port: 8080
        livenessProbe:
          tcpSocket:
            port: 8080
```

deployment.yaml几个需要注意：
1. revisionHistoryLimit用于限制保留多少份历史版本，因为“滚动”发布每次发布都会最为一个版本来进行管理，默认所有历史版本都会保留，也提供你进行回退等操作
2. strategy这里制定了“滚动”发布的策略，maxSurge是最大的变动pod数量（这里主要是只新增pod个数）maxUnavailable指定允许最大的无效pod数量，这个值等于0的意义是我们在“滚动”发布的过程中必须保证有replicas个的pod在提供服务
3. livenessProbe和readinessProbe，这两个参数用于指定如何验证pod的“存活”和“可使用”。“滚动”发布主要使用readinessProbe进行验证。当“滚动”发布过程中一个新pod创建，那么kubernetes需要检查readinessProbe为ok（这里是验证端口8080是否可访问）才会删除老的pod

# 测试

## 部署testpage

部署testpage
```
$ kubectl create -f service.yaml
$ kubectl create -f deployment.yaml
$ kubectl get po -o wide -l type=testpage
NAME                       READY     STATUS    RESTARTS   AGE       IP            NODE
testpage-230767614-fm0m1   1/1       Running   0          4m        172.1.62.10   192.168.72.233
testpage-230767614-glvbz   1/1       Running   0          4m        172.1.60.5    192.168.72.2
testpage-230767614-hpx9s   1/1       Running   0          4m        172.1.14.7    192.168.72.128
```

## 测试脚本

这个脚本每一秒访问一次testpage服务，返回访问到的pod的ip和version
```
while true; do date; curl http://192.168.72.2:21000; sleep 1; done
```

监控testpage的pod变化情况
```
while true; do date; kubectl get po -l type=testpage -o wide; sleep 1; done
```

监控testpage的deployment“滚动”发布状态
```
while true; do date; kubectl rollout status deployment testpage; sleep 1; done
```

## 开始测试

我们模拟的testpage当前版本是0.8，这时我们需要将其升级到0.9

1. 根据上述dockerfile大家可以直接build出0.9的镜像: dean/testpage:0.9
2. 修改deployment.yaml（将镜像版本和VERSION变量修改成0.9）
```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: testpage
  namespace: default
  labels:
    type: testpage
spec:
  replicas: 3
  revisionHistoryLimit: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        type: testpage
    spec:
      containers:
      - name: testpage
        image: dean/testpage:0.9
        imagePullPolicy: Always
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
        env:
        - name: VERSION
          value: "0.9"
        ports:
        - containerPort: 8080
        readinessProbe:
          tcpSocket:
            port: 8080
        livenessProbe:
          tcpSocket:
            port: 8080
```
3. 执行测试脚本：
```
while true; do date; curl http://192.168.72.2:21000; sleep 1; done
```
该脚本持续返回：
```
Thu Mar  9 10:39:09 CST 2017
I am: 172.1.14.7, the version is: 0.8
Thu Mar  9 10:39:10 CST 2017
I am: 172.1.14.7, the version is: 0.8
Thu Mar  9 10:39:11 CST 2017
I am: 172.1.14.7, the version is: 0.8
Thu Mar  9 10:39:12 CST 2017
I am: 172.1.60.5, the version is: 0.8
Thu Mar  9 10:39:13 CST 2017
I am: 172.1.62.10, the version is: 0.8
```

从上面的输出我们可以看到总共有三个pod对应的ip地址

这里会返回三个ip，对应的三个pod，版本是0.5

4. 执行两个监控脚本
```
while true; do date; kubectl get po -l type=testpage -o wide; sleep 1; done
while true; do date; kubectl rollout status deployment testpage; sleep 1; done
```
5. 开始“滚动”发布
```
kubectl apply -f deployment.yaml
```
6. 观察测试脚本和监控脚本的变化（因为都是动态的就不录制视频了）：

rollout status结果如下
```
Thu Mar  9 10:42:24 CST 2017
deployment "testpage" successfully rolled out
Thu Mar  9 10:42:25 CST 2017
Waiting for deployment spec update to be observed...
Waiting for rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for rollout to finish: 1 old replicas are pending termination...
Waiting for rollout to finish: 1 old replicas are pending termination...
deployment "testpage" successfully rolled out
```
上述过程可以看到kuberentes的pod是一个一个更新的。直到最后老pod被清理掉。升级完成


kubectl get po输出, 这里可以直观看出整个过程，下列的输出我是截取了关键的变化点。

我在几个关键点后面写上（标注N）用于进行过程解释

标注1，因为配置文件中strategy的配置，不运行kuberentes进行同位替换，所有kuberentes创建了一个新pod
标注2，新pod创建成功，但是因为readinessProbe的配置kubernetes需要检测到8080端口的可访问才算是READY状态，所以状态READY为0/1（这里数字的原因是一个pod中可以有多个容器）
标注3，新pod创建成功，并且READY处于1/1（说明一个pod中的容器全部ready）这是该新pod会被添加到service中接受访问，我们结合testpage的访问数据可以看到在43:09时新pod被访问到
```
Thu Mar  9 10:43:09 CST 2017
I am: 172.1.65.4, the version is: 0.9
```
标注4，包括新pod因为有3个pod可以提供服务，所有这是kubernetes下令中止一个老pod
标注5，因老pod已被中止（这里是异步的），kuberentes下令开始再创建一个新pod用于进行下一个老pod的替换
循环这个过程直到所有老pod替换完成，升级结束

```
Thu Mar  9 10:42:39 CST 2017
NAME                       READY     STATUS              RESTARTS   AGE       IP            NODE
testpage-230767614-fm0m1   1/1       Running             0          7m        172.1.62.10   192.168.72.233
testpage-230767614-glvbz   1/1       Running             0          7m        172.1.60.5    192.168.72.2
testpage-230767614-hpx9s   1/1       Running             0          7m        172.1.14.7    192.168.72.128
testpage-515849216-059b0   0/1       ContainerCreating   0          14s       <none>        192.168.72.190   (标注1)
Thu Mar  9 10:42:40 CST 2017
NAME                       READY     STATUS    RESTARTS   AGE       IP            NODE
testpage-230767614-fm0m1   1/1       Running   0          7m        172.1.62.10   192.168.72.233
testpage-230767614-glvbz   1/1       Running   0          7m        172.1.60.5    192.168.72.2
testpage-230767614-hpx9s   1/1       Running   0          7m        172.1.14.7    192.168.72.128
testpage-515849216-059b0   0/1       Running   0          15s       172.1.65.4    192.168.72.190    (标注2)
...
Thu Mar  9 10:43:06 CST 2017
NAME                       READY     STATUS              RESTARTS   AGE       IP            NODE
testpage-230767614-fm0m1   1/1       Terminating         0          7m        172.1.62.10   192.168.72.233   (标注4)
testpage-230767614-glvbz   1/1       Running             0          7m        172.1.60.5    192.168.72.2
testpage-230767614-hpx9s   1/1       Running             0          7m        172.1.14.7    192.168.72.128
testpage-515849216-059b0   1/1       Running             0          41s       172.1.65.4    192.168.72.190   (标注3)
testpage-515849216-1sf6b   0/1       ContainerCreating   0          1s        <none>        192.168.72.233   (标注5)
...
Thu Mar  9 10:43:18 CST 2017
NAME                       READY     STATUS        RESTARTS   AGE       IP            NODE
testpage-230767614-fm0m1   1/1       Terminating   0          7m        172.1.62.10   192.168.72.233
testpage-230767614-glvbz   1/1       Running       0          7m        172.1.60.5    192.168.72.2
testpage-230767614-hpx9s   1/1       Running       0          7m        172.1.14.7    192.168.72.128
testpage-515849216-059b0   1/1       Running       0          53s       172.1.65.4    192.168.72.190
testpage-515849216-1sf6b   0/1       Running       0          13s       172.1.62.11   192.168.72.233
...
Thu Mar  9 10:43:36 CST 2017
NAME                       READY     STATUS              RESTARTS   AGE       IP            NODE
testpage-230767614-glvbz   1/1       Terminating         0          8m        172.1.60.5    192.168.72.2
testpage-230767614-hpx9s   1/1       Running             0          8m        172.1.14.7    192.168.72.128
testpage-515849216-059b0   1/1       Running             0          1m        172.1.65.4    192.168.72.190
testpage-515849216-1sf6b   1/1       Running             0          31s       172.1.62.11   192.168.72.233
testpage-515849216-5jfb5   0/1       ContainerCreating   0          0s        <none>        192.168.72.2
...
Thu Mar  9 10:43:49 CST 2017
NAME                       READY     STATUS        RESTARTS   AGE       IP            NODE
testpage-230767614-glvbz   1/1       Terminating   0          8m        172.1.60.5    192.168.72.2
testpage-230767614-hpx9s   1/1       Running       0          8m        172.1.14.7    192.168.72.128
testpage-515849216-059b0   1/1       Running       0          1m        172.1.65.4    192.168.72.190
testpage-515849216-1sf6b   1/1       Running       0          44s       172.1.62.11   192.168.72.233
testpage-515849216-5jfb5   0/1       Running       0          13s       172.1.60.11   192.168.72.2
...
Thu Mar  9 10:44:07 CST 2017
NAME                       READY     STATUS        RESTARTS   AGE       IP            NODE
testpage-230767614-hpx9s   1/1       Terminating   0          8m        172.1.14.7    192.168.72.128
testpage-515849216-059b0   1/1       Running       0          1m        172.1.65.4    192.168.72.190
testpage-515849216-1sf6b   1/1       Running       0          1m        172.1.62.11   192.168.72.233
testpage-515849216-5jfb5   1/1       Running       0          31s       172.1.60.11   192.168.72.2
...
Thu Mar  9 10:47:46 CST 2017
NAME                       READY     STATUS    RESTARTS   AGE       IP            NODE
testpage-515849216-059b0   1/1       Running   0          5m        172.1.65.4    192.168.72.190
testpage-515849216-1sf6b   1/1       Running   0          4m        172.1.62.11   192.168.72.233
testpage-515849216-5jfb5   1/1       Running   0          4m        172.1.60.11   192.168.72.2
```

# 总结

1. 策略配置让kubernetes必须先创建一个新pod去替换老pod（而不是删除老pod再创建新pod，这个策略可自行配置）
2. 每次仅替换一个pod，并进行业务的无缝切换
3. 整个过程readinessProbe非常重要，确定着业务是否会被中断（必须确保readinessProbe的验证是对业务的准确验证，因为测试这里仅进行端口验证）


# kubernetes支持其他rollout操作

Read the deployment history

```
kubectl rollout history deployment testpage
kubectl rollout history deployment testpage --revision 42
```

Rollback to the previous deployed version

```
kubectl rollout undo deployment testpage
kubectl rollout undo deployment testpage --to-revision 21
```

Pause and Resume

```
kubectl rollout pause deployment testpage
kubectl rollout resume deployment testpage
```

