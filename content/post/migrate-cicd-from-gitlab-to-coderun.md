---
title: CICD从Gitlab迁移到Coderun
date: 2018-11-27
tags: ["gitlab", "coderun", "cicd", "迁移"]
categories: ["迁移"]
---

## 背景

我们是一个10人小团队，因为本人之前接触过Docker和Drone，所有项目开发阶段开始的时候就确定使用CICD和Docker的方式进行开发与部署。前期为了方便我们直接使用[Gitlab.com](https://gitlab.com)（不是私有部署）进行代码仓库的存储于Gitlab CI进行构建，然后通过Gitlab Runner部署到阿里云的开发服务器上。

没有自己部署Gitlab的原因是不想去管理Gitlab，比如保证Gitlab的可用，数据安全等，对于我们这样的小团队减少自己部署产品可以节省不少时间和精力，而且[Gitlab.com](https://gitlab.com)也基本是免费的。

前期因为产品开发阶段所以我们只考虑了直接在服务器上通过Gitlab Runner部署开发环境和测试环境。但近期在准备产品的上线，我们需要将镜像推送到阿里云的Kubernetes（我们是使用托管版）上进行部署。在准备使用Gitlab CI部署时发现阿里云K8s（托管版）不支持token连接。
后来与阿里云相关工作人员联系后告知可以通过service和endpoint间接通过token访问k8s api。这种方式kubectl可以使用，但是配置到Gitlab.com上依然无效。

评估后我们得出两种方案：

1. 使用自定义的镜像（Gitlab CI支持使用任意镜像进行扩展）封装kubectl进行部署，这样的方式需要将kubeconfig配置到变量中，并使用脚本生成kubeconfig文件。然后再执行service和deployment文件进行部署。（Drone上的K8s插件不太靠谱，最好不要使用)
1. 寻找其他的CICD平台（其实想寻找其他平台的还有一个重要的原因是Gitlab.com在17点-03点这段时间速度特变，我们团队又经常要加班，所以晚上很痛苦。猜测应该和美国人上班时间有关系）。也有看了下CodePipeline，但是纯GUI一步配置的方式真心不方便，没有效率，所以放弃。

后来找到了一个CICD的SaaS平台：[CodeRun](https://coderun.top)

经过一段时间的研究和试用后我们目前所有的CICD都迁移到了[CodeRun](https://coderun.top)上（代码仓库也顺便迁移到[Gitee](https://gitee.com)上)

下面我们来具体介绍下两个平台和我们的迁移过程

## [Gitlab](https://gitlab.com)

Gitlab（包括私有部署）应该是国内使用量最大的代码仓库，Gitlab因为发展不断加入新功能，最亮眼的应该就是CICD和Kubernetes的支持了。
所以理论上一套Gitlab就可以搞定你的代码仓库和CICD还是很方便的。

Gitlab的代码仓库功能就不讨论了。对于Gitlab CI这个新功能就比较有意思。大家都知道国内使用最多的CICD应该是Jenkins（应该是全球最多的）。我觉得其中最重要的一个原因是Jenkins是一个比较老的产品，在新的CICD方式没有出来的时候他就已经有非常大了的用户了。
但Jenkins有几个比较明显的缺点：

1. 需要自行部署
1. 插件和配置还是有一定学习难度
1. 配置相对来说比较复杂
1. Jenkins一般都需要专人进行维护

所以后来出现了一些仅通过一个Yaml文件就可以配置整个Pipeline的产品，最有名的应该是[Drone](https://drone.io)。Drone因为部署方便，配置简单，同时还是开源产品所以得到了大量的用户。目前Drone也支持SaaS模式。但对于中国很悲剧的是他服务器也在国外，性能是个问题。
Gitlab CI是另一个支持一个Yaml文件配置的CI产品，他和Drone模式非常类似，基于 Docker 镜像作为 Stage 来执行。使用镜像作为Stage的好处就是你可以自定义镜像来进行扩展需求。比如前面提到的自行扩展对K8s的支持。

Gitlab Yaml配置样子如下：

```yaml
image: docker:latest

stages:
- build
- deploy

variables:
  APP_NAME: api
  REGISTRY_IMAGE: "${DOUWA_REGISTRY_URL}/image/${APP_NAME}"

before_script:
  - docker login -u $REGISTRY_USER -p $REGISTRY_PASSWORD $REGISTRY_URL

build:
  stage: build
  retry: 2
  tags:
    - dev
  script:
    - docker build -t $REGISTRY_IMAGE:${CI_COMMIT_REF_NAME} .
    - docker push $REGISTRY_IMAGE:${CI_COMMIT_REF_NAME}

deploy-dev:
  stage: deploy
  tags:
    - dev
  script:
    - docker stack deploy ${APP_NAME}_${CI_COMMIT_REF_NAME} -c deploy/${CI_COMMIT_REF_NAME}/docker-compose.yml --with-registry-auth
  environment:
    name: develop
  only:
    - dev
```

yaml这个配置应该挺好懂的。这里再简单介绍下：

1. image: 定义了所有下面的步骤默认使用docker镜像
1. variables: 定义了方便后续使用的变量
1. 两个步骤:
  - build: 构建镜像
  - deploy-dev: 部署开发环境，其中`only`限制了只有`dev`分支才执行
  - stages部分进行了说明

因为gitlab没有整合资源，所有docker的操作和部署都是需要自己写脚本完成。当然这对于高级用户肯定是没有难度的，但对于新手就需要一定学习。

## [CodeRun](https://coderun.top) + [Gitee](https://gitee.com)

迁移到[Gitee](https://gitee.com)，国内一般叫`码云`主要的原因就是[Gitlab.com](https://gitlab.com)太慢了。另外`码云`的项目管理功能也是相当强大的。

那么[CodeRun](https://coderun.top)应该是一个比较新的产品，好像也没什么知名度。但试用了下感觉还不错，而且国内好像也没有类似的独立平台，我的意思是整合CICD的独立平台，不是我对云平台提供的CICD产品有偏见，而是他们更多以附加产品存在，在易用性并不会太下功夫，而整合方面基本都会排除其他产品。

我个人认为[CodeRun](https://coderun.top)的优点有：

1. 整合常见的Git平台：Github、Bitbucket、Gitee、Coding、Gitlab（私有部署好像也能支持）
1. 有独立的镜像仓库，当然也可以配置第三方镜像仓库
1. 可以配置token或者证书验证的Kubernetes（阿里云Kubernetes默认使用证书的验证方式）
1. 有独立的Helm仓库
1. 同样是Yaml配置，有一个简单的GUI
1. Yaml的易用性比Gitlab要好

下面是之前Gitlab那个项目的CodeRun版本：

```yaml
steps:
  build:
    image: crun/docker
    repo_name: ${APP_NAME}
    registry_name: coderun
    dockerfile: Dockerfile
    context: .
    tags: ${CI_COMMIT_BRANCH}

  deploy:
    image: crun/kube
    cluster_name: myk8s
    template: deploy/deployment.yml
    namespace: default
    when:
      branch: dev
```

简单说明下：

- build: 使用`crun/docker`步骤，代码仓库中的Dockerfile构建镜像，并上传到`CodeRun`提供的镜像仓库
- deploy: 使用`crun/kube`步骤，和代码仓库中的`deploy/deployment.yml`配置直接将镜像部署到在`CodeRun`上配置好的`myk8s`的Kubernetes集群上

和Gitlab的差异：

1. 没有任何脚本操作
1. 不需要定义一堆变量和参数

Kubernetes集群`myK8s`的配置：

![](/img/blog/kubernetes_conf.png?classes=shadow)
