---
title: "IaC and Kubernetes"
date: 2019-04-29T15:19:58+08:00
draft: true
tags: [iac, kubernetes]
categories: [kubernetes]
author: ""

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: false
toc: false
autoCollapseToc: false
postMetaInFooter: false
hiddenFromHomePage: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: false
reward: false
mathjax: false
mathjaxEnableSingleDollar: false
mathjaxEnableAutoNumber: false

# You unlisted posts you might want not want the header or footer to show
hideHeaderAndFooter: false

# You can enable or disable out-of-date content warning for individual post.
# Comment this out to use the global config.
#enableOutdatedInfoWarning: false

flowchartDiagrams:
  enable: false
  options: ""

sequenceDiagrams:
  enable: false
  options: ""

---

# 定义

Infrastructure as code一般翻译为：基础设施即代码

那什么是基础设施了，一般是指为了IT中为了提供应用顺利部署和运行的那些环境，包括有：服务器、网络、存储、数据库等等。
另一种理解可以认为阿里云是IaaS提供商，那么阿里云上的都是基础设施。

基础设施即代码是指一切的基础设施都代码化，或者说使用一套代码(配置)就可以部署和管理基础设施。一般来讲并不是单指纯粹的代码化，更多的是代码化带来的管理、运维、自动化的提升。

如果想更全面的了解可以参考<<[基础设施即代码](https://book.douban.com/subject/30298097/)>>这本书

## Kubernetes对部署与运维的改变

这里以Kubernetes为题的原因是对于运维来说更关注的是体系而不仅仅是容器的相关操作。

对于整个体系来说docker只是一种容器的实现技术，与整个运维体系并不会有大的影响。

所以我认为容器与Kubernetes才是改变整个运维体系的关键。

为什么这么说了，让我们来分析下：

1. 应用部署的一大工作是应用的环境依赖（这里指程序上，比如第三方包，系统需要特定包），部署过程中也经常因为应用环境依赖导致变更异常。而容器技术的成熟（容器技术很早就有了，但市场成熟也就没多少年的事）解决了这个问题。我们将所有的应用环境依赖封装在一个镜像（容器的静态模式）中，只要操作系统支持相应的容器技术（比如Docker）那么它就可以运行这个镜像。
1. 基础设施包括的其他几大部分，网络、LB、应用配置、扩容、回退、升级（升级应用版本）都已经被Kubernetes封装了。当然这里并不包括全部，但已经包括了大部分，如果使用Kubernetes后大量的运维工作都会变得简单，且只需围绕Kubernetes进行。

### Kubernetes

简单介绍下：

引用来自[百度百科](https://baike.baidu.com/item/kubernetes/22864162?fr=aladdin)
```
kubernetes，简称K8s，是用8代替8个字符“ubernete”而成的缩写。是一个开源的，用于管理云平台中多个主机上的容器化的应用，Kubernetes的目标是让部署容器化的应用简单并且高效（powerful）,Kubernetes提供了应用部署，规划，更新，维护的一种机制。

传统的应用部署方式是通过插件或脚本来安装应用。这样做的缺点是应用的运行、配置、管理、所有生存周期将与当前操作系统绑定，这样做并不利于应用的升级更新/回滚等操作，当然也可以通过创建虚拟机的方式来实现某些功能，但是虚拟机非常重，并不利于可移植性。

新的方式是通过部署容器方式实现，每个容器之间互相隔离，每个容器有自己的文件系统 ，容器之间进程不会相互影响，能区分计算资源。相对于虚拟机，容器能快速部署，由于容器与底层设施、机器文件系统解耦的，所以它能在不同云、不同版本操作系统间进行迁移。

容器占用资源少、部署快，每个应用可以被打包成一个容器镜像，每个应用与容器间成一对一关系也使容器有更大优势，使用容器可以在build或release 的阶段，为应用创建容器镜像，因为每个应用不需要与其余的应用堆栈组合，也不依赖于生产环境基础结构，这使得从研发到测试、生产能提供一致环境。类似地，容器比虚拟机轻量、更“透明”，这更便于监控和管理。
```




# 新时代

DevOps + Kubernetes = Iac

# 相关工具和平台介绍


1. [CodeRun.top](https://coderun.top)


# 参考

- [Infrastructure as code: What is it? Why is it important?](https://www.hashicorp.com/resources/what-is-infrastructure-as-code)
- [15 Infrastructure as Code tools you can use to automate your deployments](https://www.thorntech.com/2018/04/15-infrastructure-as-code-tools/)
- [Infrastructure as Code: 5 Reasons Why You Should Implement IaC Now](https://www.thorntech.com/2018/01/infrastructureascodebenefits/)
- [Everything as Code: The future of ops tools](https://www.hashicorp.com/resources/everything-as-code-the-future-of-ops-tools)
- [Infrastructure and How “Everything as Code” changes everything](https://www.bmc.com/blogs/infrastructure-everything-code-changes-everything/)
