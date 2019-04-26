---
title: 自动部署阿里云Kubernetes
date: 2019-01-14
tags: ["gitlab", "coderun", "cicd", "阿里云", "aliyun", "kubernetes", "jenkins"]
categories: ["Kubernetes"]
---

今天给大家介绍下如何将应用自动部署到阿里云Kubernetes(托管版)

我们使用三种开发语言，分别是：js, python, golang．三种语言的部署有一些差别，但主要步骤都是一样的．我们今天先介绍下js(前端)的部署方式．

核心的部署步骤如下：

1. Git Clone
1. 编译与Build镜像
1. 部署到Kubernetes，通过Helm或者Deployment

## 配置Kubernetes

阿里云的Kuberntes支持三种模式：

1. 自部署，阿里云仅提供一键部署但不提供管理和后续维护．要求用户水平较高
1. 托管模式，阿里云提供一键部署，并负责管理`Master`节点．这种模式用户仅需要管理`Node`节点，基本不需要担心节点挂了，并且可以自行确定`Node`节点要求的性能．后续升级也可以交给阿里云负责
1. serverless，终极模式，啥都不需要管理，只需要把镜像提交上去，并确定资源需求即可．不需要维护任何服务器．

上面的三种模式我们选择了第2种，因为托管模式可以提供用户足够的自由度又不需要要求太高的管理水平．当然对于三种模式[CodeRun](https://coderun.top)都是支持的．我们来看下具体如何配置集群．

### 获取KubeConfig

不管哪种集群创建后都可以在控制台获取到`KubeConfig`配置，在阿里云控制台点击某个集群后可以看到下图`KubeConfig`：

![](/img/blog/aliyun_kubeconfig.png?classes=shadow)

我们需要三个信息：

1. 集群地址，阿里云为每个Kubernetes集群都分配了一个外部地址(如果是自部署模式好像需要自己配置)
1. 证书，集群的访问证书
1. `Key`，证书对应的`Key`，相当与密钥

有了这三个信息我们就可以配置集群

### 配置CodeRun的Kubernetes集群

在`CodeRun`控制台的`整合`->`Kubernetes`，点击右边的`添加`按钮选择`证书`模式，如图：

![](/img/blog/kubernetes_conf2.png?classes=shadow)

- 其中上图中的`名称`是你可以自行定义的名称，这个名称可以方便后续在`Pipeline`中使用，所以最好取一个好记的名称(这里使用`myk8s`)．

## Pipeline[可以参考](https://g.coderun.top/docs/#/quickstart/create_pipeline/)

### 添加仓库

在`CodeRun`控制台的`Repo|仓库`，点击`添加仓库`．在右侧选择代码仓库，(如果不是当前用户的`Git`仓库，参见[添加Git配置](https://g.coderun.top/docs/#/config/integration/git_add))，如下图：

![](/img/blog/add_repo1.png?classes=shadow)

选择`Build`类型

![](/img/blog/add_repo2_type.png?classes=shadow)

三种类型分别是：

1. `coderun.yml`，使用代码仓库中的`coderun.yml`文件进行构建
1. `Dockerfile`，使用代码仓库中的`Dockerfile`作为镜像的构建
1. 模板，和上述的`Dockerfile`类似，只是使用`CodeRun`内置的各语言`Dockerfile`模板

我们这里选择使用`模板`创建，选择`node`语言．`Dockerfile`内容预览如下：

```yaml
FROM node:8.0-alpine AS builder

WORKDIR /app

COPY package.json /app

# Creating tar of productions dependencies
RUN npm install --production && cp -rp ./node_modules /tmp/node_modules

# Installing all dependencies
RUN npm install

# Copying application code
COPY . /app

# Running tests
RUN npm test

FROM node AS runner

EXPOSE 3000
WORKDIR /app

# Adding production dependencies to image
COPY --from=builder /tmp/node_modules /app/node_modules

# Copying application code
COPY . /app

CMD npm start
```

上述模板是采用`Dockerfile`的多阶段模式进行处理的，分成两大部分：

1. 第一部分是安装依赖，然后进行`npm test`
1. 第二部分是复制第一部分的`node_models`，并启动`npm start`

因为我们的代码中没有测试所以可以注释掉`npm test`这段，另外我们代码使用`vue-cli3`所以`npm start`修改成`npm run serve`，最后如下：

```yaml
FROM node:8.0-alpine AS builder

WORKDIR /app

COPY package.json /app

# Creating tar of productions dependencies
RUN npm install && cp -rp ./node_modules /tmp/node_modules

FROM node AS runner

EXPOSE 3000
WORKDIR /app

# Adding production dependencies to image
COPY --from=builder /tmp/node_modules /app/node_modules

# Copying application code
COPY . /app

CMD npm run serve
```

点击`创建`后，我们可以看到添加好的仓库：

![](/img/blog/repo_list.png?classes=shadow)

### yaml配置

点击`coderuntop/startup`后我们可以看到`Pipeline`页面，如图：

![](/img/blog/repo_pipeline_yml.png?classes=shadow)

配置如下：

```yaml
steps:
  docker:
    image: crun/docker
    registry_name: coderun
    repo_name: hellwen/startup
    dockerfile_content: |
      FROM node:8.0-alpine AS builder

      WORKDIR /app

      COPY package.json /app

      # Creating tar of productions dependencies
      RUN npm install && cp -rp ./node_modules /tmp/node_modules

      FROM node AS runner

      EXPOSE 8080
      WORKDIR /app

      # Adding production dependencies to image
      COPY --from=builder /tmp/node_modules /app/node_modules

      # Copying application code
      COPY . /app

      CMD npm run serve
    context: .
    tags: latest
```

其中，`repo_name`配置的名称需要进行修改，如上已经修改成：`coderuntop/startup`修改成`用户名/项目名`格式，其中用户名就是你当前用户的名称，可以通过控制台的右上角看到．

更多yaml的配置，请参考帮助文档：[https://g.coderun.top/docs/#/yaml/concepts](https://g.coderun.top/docs/#/yaml/concepts)

配置好我们就可以进行下测试了，选择仓库的分支，因为这个项目我把前端代码写在`node`分支中，所以这里直接点击`node`分支的`Build`按钮

![](/img/blog/repo_branch.png?classes=shadow)

点击后在`Build`页面可以看到正在跑的`Build`任务：

![](/img/blog/repo_build_running.png?classes=shadow)

`Build`右边的绿色打勾图标说明这次`Build`成功，我们的`Dockerfile`是正常的．

点击进入某个`Build`任务后可以看到对应的`Build`日志：

![](/img/blog/repo_build_log.png?classes=shadow)

### 增加部署步骤

增加的部署配置如下：

```yaml
deploy:
  image: crun/kube
  cluster_name: myk8s
  namespace: default
  template_content: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: startup-node
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: startup-node
        template:
          metadata:
            labels:
              app: startup-node
          spec:
            containers:
            - name: startup-node
              image: {{CR_IMAGE}}
```

- 其中`crun/kube`是官方提供的`k8s`插件
- `cluster_name`这里指定的是上面配置的`k8s`集群，我们命名为：`myk8s`
- `namespace`指定`k8s`集群的命名空间
- `template_content`指定`k8s`能有效识别的`yaml`配置(可以包含：`service`和`deployment`等)
- `image`中我们使用了一个变量`{{CR_IMAGE}}`这个变量会自动从`crun/docker`获取到`build`后的完整镜像地址

增加部署步骤后我们再`Build`一次，我们可以看到我们的部署增加了一个`Log`：

![](/img/blog/repo_build_log2.png?classes=shadow)

部署后的`k8s`效果：

```shell
$ kubectl get deployment startup-node
NAME           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
startup-node   1         1         1            1           3h
```

```shell
$ kubectl get deployment startup-node -o=custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,STATUS:.status.availableReplicas
NAME           IMAGE                               STATUS
startup-node   r.crun.top/hellwen/startup:latest   1
```

要使用`kubectl`命令连接阿里云需要把前面的`KubeConfig`配置到当前`Shell`的`.kube/config`文件中，至于如何配置可以参考`kubernetes.io`
上面的结果我们可以看到`k8s`上的运行镜像被替换成`r.crun.top/hellwen/startup:latest`这样我们就省去了填写镜像地址的麻烦．

到这里我们的部署就完成了．比起自己搭建`Jenkins`是不是方便不少．
