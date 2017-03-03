title: Ingress Controller with Traefik on Kubernetes
date: 2017-03-03
tags:
- traefik
- kubernetes
---

# Kubernetes [Ingress](https://kubernetes.io/docs/user-guide/ingress/)

kubernetes典型的访问是通过网络直接访问Service，由Service分发到pod上:

```
    internet
        |
  ------------
  [ Services ]
```

如果增加Ingress:

```
    internet
        |
   [ Ingress ]
   --|-----|--
   [ Services ]
```

Ingress部署在Service前面进行域名的解析和分发

# Ingress Controller

上文提到的Ingress对象实际上只是kubernetes中的一些配置文件，真正实现Ingress功能的实际是Ingress Controller。

Ingress Controller的功能主要有：
- 访问kubernetes api，来感知Service的变化和Ingress的配置
- 当感知到Service变化时，将配置应用的本身的配置文件中
- Reload配置，实现分发

目前Kubernetes官方提供gce和nginx的Controller，相见：[Ingress](https://github.com/kubernetes/ingress/tree/master/controllers)

# [Traefik](https://github.com/containous/traefik)

traefik是一个为容器而生的反向代理和负载均衡服务，很轻量，采用go语言。可以支持很多容器相关架构，如：Consul, Etcd, Docker, Kubernetes, Messos等等

另外，traefik支持Let\'s Encrypt

# Traefik deploy on Kubernetes

## traefik deployment

```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    nodePort: 80
  selector:
    k8s-app: traefik-ingress-controller
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-controller
spec:
  replicas: 2
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-controller
        name: traefik-ingress-controller
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - image: traefik:v1.1.2-alpine
        name: traefik-ingress-controller
        resources:
          limits:
            cpu: 200m
            memory: 30Mi
          requests:
            cpu: 100m
            memory: 20Mi
        ports:
        - name: http
          containerPort: 80
        - name: admin
          containerPort: 8081
        args:
        - -d
        - --web
        - --web.address=:8081
        - --kubernetes
        - --kubernetes.endpoint=http://139.119.3.113:6550/
```

`web.address=:8081`指示启动traefik的web端口
`kubernetes.endpoint`指向kubernetes的api地址（apiserver）

这里部署了2个traefik，是为了在集群中作为HA

service采用nodePort方式，在所有node上映射80端口（因为域名通常不需要端口，如果你指定了其他端口那么域名增加相应的端口即可）。为了指定80端口需要开发kubernetes api的限制，配置参数：`--service-node-port-range=1-65535`

## deploy traefik ui

```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  ports:
  - name: web
    port: 80
    targetPort: 8081
  selector:
    k8s-app: traefik-ingress-controller
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  rules:
  - host: traefik-ui.local.io
    http:
      paths:
      - path: /
        backend:
          serviceName: traefik-web-ui
          servicePort: web
```

第一部分是traefik ui的service，ingress需要转发到service上
第二部分创建ingress，如果访问的是指定域名traefik-ui.local.io，那么重定向到traefik-web-ui这个service的web端口上

## 验证traefik ui

如果是实际环境只需要将域名配置执行集群中的node的ip即可，默认是80端口

使用curl验证地址

```
curl -H "Host: traefik-ui.local.io" http://192.168.72.2
```

`-H` 用于指定访问域名

或者可以直接在浏览器中打开

## deploy testpage app

testpage是一个python的测试页面，通过http访问该页面会返回一个配置好的版本号

Deployment:

```yaml
kind: Service
apiVersion: v1
metadata:
  name: testpage
  namespace: default
  labels:
    type: testpage
spec:
  ports:
  - name: http
    port: 8080
  selector:
    type: testpage
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: testpage
  namespace: default
  labels:
    type: testpage
spec:
  replicas: 2
  template:
    metadata:
      labels:
        type: testpage
    spec:
      containers:
      - name: testpage
        image: k8s-registry.zeusis.com:32000/testpage:0.5
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
```

Ingress:
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: testpage
  namespace: default
spec:
  rules:
  - host: testpage.local.io
    http:
      paths:
      - path: /
        backend:
          serviceName: testpage
          servicePort: http
```

验证

```
$ curl -H "Host: testpage.local.io" http://192.168.72.2
I am1: 172.1.14.4, the version is: 0.5
```

