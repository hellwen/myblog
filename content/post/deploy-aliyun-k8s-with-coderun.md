---
title: 快速部署应用到阿里云Kubernetes
date: 2019-05-07
tags: ["coderun", "cicd", "阿里云", "aliyun", "kubernetes"]
categories: ["coderun", "kubernetes"]
---

今天给大家介绍下如何快速部署应用到阿里云`Kubernetes`(托管版)，以下简称`k8s`

`k8s`是个复杂的产品我相信大部分企业在应用的时候并不会关系太深层次的问题，所以我个人比较推荐的`k8s`使用方式是直接部署各大云平台的`托管版`(`Azure`云平台只提供了`托管版`)。`托管版`有如下优势：

1. 部署简单，因为云平台解决了`master`节点管理，所以我们只需一键部署`node`节点
1. 运维简单，因为只管理`node`节点，所以我们并不需要担心集群可靠性问题。并且云平台一般会在安装的`k8s`版本中嵌入云平台自己的网络和存储解决方案。网络方面可能体会不太明显，但至少我们可以直接在`k8s`中管理云磁盘`Disk`
1. 成本低，大部分中小公司如果要运作`k8s`是需要招聘独立的运维人员的，如果使用`托管版`我相信一般的开发人员或者其他数据库人员是可以替代的，且因为运维简单并不需要花太多功夫

所以今天的主题中`k8s`的`托管版`是`快`的其中一个因素，另一个因素就是`Coderun`，它是一个`CI/CD`平台，你可以将它与`jenkins`、`drone`、`CircleCI`、`Travis`或`Codefresh`等进行比较，他们是类似的平台，其实准确说`Coderun`和`Codefresh`是比较类似的，与其他平台的差异是集成了`镜像仓库`和`Helm Charts`，以及集成了一些相关的云平台资源，所以它是另一个`快`的因素。

## 阿里云Kubernetes

阿里云`k8s`部署这里不进行介绍，详见：[ACK](https://www.aliyun.com/product/kubernetes?spm=5176.224200.cloudEssentials.11.70296ed6cqTskE)

1. 自部署，阿里云仅提供一键部署但不提供管理和后续维护．要求用户水平较高
1. 托管模式，阿里云提供一键部署，并负责管理`Master`节点．这种模式用户仅需要管理`Node`节点，基本不需要担心节点挂了，并且可以自行确定`Node`节点要求的性能．后续升级也可以交给阿里云负责
1. serverless，终极模式，啥都不需要管理，只需要把镜像提交上去，并确定资源需求即可．不需要维护任何服务器．

如上所述我比较推荐托管版

### 获取KubeConfig

不管哪种集群创建后都可以在控制台获取到`KubeConfig`配置，在阿里云控制台点击某个集群后可以看到下图`KubeConfig`：

![](/img/blog/aliyun_kubeconfig.png)

我们需要三个信息：

1. 集群地址，阿里云为每个Kubernetes集群都分配了一个外部地址(如果是自部署模式好像需要自己配置)
1. `client-certificate-data`，集群的访问证书
1. `client-key-data`，相当于证书的秘钥

如果`k8s`开启了`RBAC`模式，那么我们需要创建`Service Account`和绑定`Role`然后参考`Token`模式配置：[K8s Token](https://g.coderun.top/docs/#/config/integration/k8s_cluster?id=token%E6%A8%A1%E5%BC%8F)

## Coderun

`Coderun`的地址是：[https://g.coderun.top/](https://g.coderun.top/)，我们需要先进行注册，当前它的注册很方便，直接使用`Github`、`Gitlab`、`Gitee`或`Coding`账号都可以直接登录(注册并登录)，所以如果你的代码仓库是使用云平台那就非常方便了。

下面演示的例子: [coderun-demo](https://github.com/hellwen/coderun-demo)，因为我是直接使用`Github`账号登录，所以默认会自动添加了`Github`的配置，如果你要构建的仓库不在你的当前账号下需要自己再配置`Git`账号，参考官方文档：[Git配置](https://g.coderun.top/docs/#/config/integration/git)

### 配置Kubernetes集群

在`Coderun`控制台的`整合`->`Kubernetes`，点击右边的`添加`按钮选择`证书`模式，如图：

![](/img/blog/kubernetes_conf2.png)

- 其中上图中的`名称`是你可以自行定义的名称，这个名称可以方便后续在`Pipeline`中使用，所以最好取一个好记的名称(这里使用`myk8s`)．
- 证书：填写`KubeConfig`中的`client-certificate-data`
- Key：填写`KubeConfig`中的`client-key-data`

完毕后保存，这里我们得到一个叫`myk8s`的集群，这个集群连接到我们在阿里云上的`k8s`集群，后续的所有部署只需要部署到`myk8s`即可。

## 配置Pipeline

### 添加仓库

在`Coderun`控制台的`Repo|仓库`，点击`添加仓库`．在右侧选择代码仓库，(如果不是当前用户的`Git`仓库，参见[Git配置](https://g.coderun.top/docs/#/config/integration/git))，如下图：

![](/img/blog/add_repo.png)

选择`Build`类型

![](/img/blog/add_repo_type.png)

三种类型分别是：

1. `coderun.yml`，使用代码仓库中的`coderun.yml`文件进行构建
1. `Dockerfile`，使用代码仓库中的`Dockerfile`作为镜像的构建
1. 模板，和上述的`Dockerfile`类似，只是使用`Coderun`内置的各语言`Dockerfile`模板

因为我们在代码仓库中已经有`Dockerfile`，所以直接使用`Dockerfile`创建，我们可以看到添加好的仓库：

![](/img/blog/repo_list.png)

### yaml配置

点击添加好的仓库`hellwen/coderun-demo`，我们可以看到`Pipeline`页面，如图：

![](/img/blog/repo_pipeline_yml.png)

`yaml`配置如下：

```yaml
steps:
  docker:
    image: crun/docker
    registry_name: coderun
    repo_name: hellwen/coderun-demo
    dockerfile_content: |
      FROM node:8

      WORKDIR /www
      COPY index.html /www

      RUN npm install http-server -g

      EXPOSE 8080
      CMD ["http-server"]

    context: .
    tags: latest
```

默认`coderun`会将`dockerfile`解析出来，这样的好处是在`coderun`上可以随意修改`Pipeline`并重新部署，因为我们已经有`Dockerfile`所以更简洁的配置：

```yaml
steps:
  docker:
    image: crun/docker
    registry_name: coderun
    repo_name: hellwen/coderun-demo
    tags: latest
```

上述配置会默认使用当前代码仓库下的`Dockerfile`文件，注意：如果是使用代码仓库中的文件是和`Build`的代码分支有关的哦。

几个比较重要的配置：

- registry_name: 这个参数是指定代码仓库的配置，相关的配置在`整合`中，每个用户`coderun`会自动创建一个同名的镜像仓库，所以这里可以直接使用
- repo_name: 镜像名称，默认为代码仓库名称，可以执行修改但要注意不要和其他仓库镜像同名

配置好我们就可以进行下测试了，选择`分支`页面，如图：

![](/img/blog/repo_branch.png)

点击`Build`后可以看到当前的`Build`进度，第一次`Build`一般会因为上传镜像所以稍微有点慢

![](/img/blog/repo_build_log.png)

`Build`完成后如下右上角有绿色确定图标指示成功：

![](/img/blog/repo_build_log2.png)

`Coderun`在`build docker`的时候会自动上传镜像到对应的仓库中， 所以如果观察日志会看到我们上传后的镜像地址是：`r.crun.top/hellwen/hellwen/coderun-demo:latest`，其中`hellwen/hellwen`并不是`Bug`第一个`hellwen`是`Coderun`账号，第二个`hellwen`是`Github`账号(我们添加的仓库的前缀)

我们到`镜像`页面可以看到我们刚刚上传的镜像：

![](/img/blog/images.png)

### Kubernetes部署

前面步骤我们只是完成了`镜像`的构建，有了镜像后我们就可以进行部署。

#### 配置镜像仓库

如果要让`k8s`访问你的`Coderun`私有镜像仓库需要配置`Secret`，操作如下：

创建`Coderun`的访问`Token`(`Coderun`以外必选通过`Token`才能访问)，`整合`->`Token`：

![](/img/blog/token.png)

点击`生成Token`，任何输入一个名称，点击`生成`，如下：

![](/img/blog/token_gen.png)

复制上图的`Token`备用：`bj8pikhk57kg00fn9vd0`

(要使用`kubectl`访问`k8s`集群请自行配置`KubeConfig`)

```shell
$ kubectl create secret docker-registry coderun --docker-server=r.crun.top --docker-username=hellwen --docker-password=bj8pikhk57kg00fn9vd0
```

其中`docker-password`为上面生成的`Token`，`docker-username`需要修改成你自己的账号

```shell
$ kubectl get secrets coderun
NAME      TYPE                             DATA   AGE
coderun   kubernetes.io/dockerconfigjson   1      1m
```

#### 增加deploy

在原有配置上增加一个`step`: `deploy`

```yaml
steps:
  docker:
    image: crun/docker
    registry_name: coderun
    repo_name: hellwen/coderun-demo
    tags: latest

  deploy:
    image: crun/kube
    settings:
      cluster_name: myk8s
      namespace: default
      template: deployment.yml
```

- 其中`crun/kube`是官方提供的插件，用于部署到`k8s`，它可以执行任何`k8s`对象
- `cluster_name`这里指定的是前面步骤配置的`k8s`集群，我们命名为：`myk8s`
- `namespace`指定`k8s`集群的默认命名空间
- `template`指定`k8s`能有效识别的`yaml`配置(可以包含：`service`和`deployment`等)

其中`deployment.yml`如下(内容有点多，不好意思，如果你不了解`k8s`请自行学习)：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: demo
        image: {{CR_IMAGE}}
        ports:
          - name: http
            containerPort: 8080
---
kind: Service
apiVersion: v1
metadata:
  name: demo
  labels:
    app: demo
spec:
  selector:
    app: demo
  ports:
    - port: 80
      targetPort: http
      name: http
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: demo
spec:
  rules:
    - host:
      http:
        paths:
          - backend:
              serviceName: demo
              servicePort: 80
            path: /
```

重要参数：

- `image`中我们使用了一个变量`{{CR_IMAGE}}`这个变量会自动从`crun/docker`获取到`build`后的完整镜像地址
- `Ingress`中的`host`配置为空是为了让集群的根目录可以访问到

其中`ingress`需要`nginx-ingress`控制器的支持，如果没有只是你没法访问到页面，但部署依然正常的。

`helm`的安装这里不介绍了，自行`Google`，如果要安装`ingress`控制器可以使用下列命令：

```shell
$ helm install stable/nginx-ingress --name nginx-ingress --namespace kube-system
```

在执行一次`Build`，如下：

![](/img/blog/repo_build_log3.png)

上图的左边列表我们可以看到多了一个`deploy`，右边的日志显示我们部署了`Deployment`，`Service`和`Ingress`

#### 部署效果

部署后的`k8s`状态(要使用`kubectl`访问`k8s`集群请自行配置`KubeConfig`)：

```shell
$ kubectl get svc,deployment,ingress demo
NAME           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/demo   ClusterIP   172.21.10.89   <none>        80/TCP    14m

NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deployment.extensions/demo   1         1         1            1           14m

NAME                      HOSTS   ADDRESS         PORTS   AGE
ingress.extensions/demo   *       47.110.164.15   80      9m
```

```shell
$ kubectl get deployment demo -o go-template='{{range .spec.template.spec.containers}}{{.image}}{{end}}'
r.crun.top/hellwen/hellwen/coderun-demo:latest
```

上面的镜像地址我们可以看到使用`{{CR_IMAGE}}`会自动被替换成`r.crun.top/hellwen/hellwen/coderun-demo:latest`，也就是我们`crun/docker`后上传的地址，是不是特别方便了:)

#### 访问应用

如果有`ingress`控制器，直接使用`ingress`的地址`47.110.164.15`进行访问：

![](/img/blog/demo_view_for_k8s.png)

下次你如果往代码仓库中提交代码，`Coderun`就会自动触发并自动部署，完全自动哦。

## 总结

到这里我们的部署就完成了．比起自己搭建`Jenkins`是不是方便不少

`Jenkins`应该是用得做广泛的`CI/CD`工具了，但是`Jenkins`并不诞生在`Docker`和`Kubernetes`的年代，所以难免有些设计比较落后。最明显的问题就是配置的雪花问题，现在的运维架构很讲究[IaC](https://hellwen.github.io/post/infrastructure_as_code/)，从`Iac`的角度来讲雪花会带来后续大量运维和管理难点。

目前新的`CI/CD`一般都采用一个一代码仓库统一进行管理的`yaml`文件方式来进行部署，这样就可以避免雪花问题。`Coderun`更是如此，相较于其他产品我觉得`Coderun`的好处有几点：

1. 国内的平台，速度和服务有保障
1. `yaml`解决雪花问题，支持嵌入式和文件方式配置
1. 整合常见的Git平台：`Github`、`Gitee`、`Coding`、`Gitlab`(其中`Gitee`和`Coding`国内有不少用户，国外产品不太会支持这两个代码仓库)
1. 自带`镜像`仓库和`Helm Charts`仓库，更方便维护和`yaml`的使用
1. 基于`docker`镜像作为`step`，用户可以自定义自己的镜像，进行无限扩容
