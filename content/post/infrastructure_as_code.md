---
title: "Infrastructure as code"
date: 2019-04-27T08:19:58+08:00
draft: false
tags: [iac]
categories: []
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

# 为什么我们需要IaC

IaC是Infrastructure as code的简称，后续我们就直接使用简称

## 代码和脚本的魅力

理解我们为什么需要IaC我们可以比较下我们为什么要用Linux，特别是服务器上。

- Windows上安装一个应用的化需要弹出一个图形界面，然后下一步下一步的进行界面操作。这种模式的好处是较简单容易理解
- Linux安装一个应用我们需要执行一个命令（严格说是shell命令）或者一系列命令，这时候你会发现当你第一次执行的适合如果把命令都保存下来，那么如果需要再次进行安装的时候你可以直接将所有命令贴到shell上或者写在shell文件中，这样就可以实现自动安装

在互联网企业的服务器环境一般都是一个比较大的规模，比如一千台，如果你安装一个像Windows上一样的图形操作的应用我相信你会发疯的。如果使用Linux的模式，你只需要在每台服务器上执行一条命令，效率上高出非常多。

我相信这是Linux替代Windows成为服务器市场主要操作系统的最重要原因。后来Windows增加了Powershell的功能，但那时已经晚了

我们如果进一步思考，我们有ssh等服务器连接的技术，那么我们是不是可以写一个脚本去轮序服务器列表，然后连接到各服务器并执行我们已经准备好的脚本呢？如果这样是不是一千台服务器只要执行一个命令就完成所有操作呢？

这就是IaC基本的魅力，我归结为：自动化操作带来**效率提升**

## 运维和部署的管理

在运维的世界中我们经常会碰到几种常见的运维操作

1. **扩容**，我把扩容和环境搭建放在一起，因为我觉得扩容更能说明IaC的魅力。随着业务的增长，我们经常会面临着需要对业务进行不断扩容。这里扩容的一个很重要要求是按照之前的配置(环境)部署出更多的基础设施
1. **迁移**，不管机房变动或者服务器升级等，我们经常需要面临需要把现有环境复制出另外一套，它和扩容有点类似，差异是扩容只是部分设施，而迁移一般是全套设施
1. **回退**，一个应用的上线除了应用本身的变更外也会需要基础设施同步进行大小不一的变动，会涉及到服务器配置、中间件、数据库等。当一次变更失败的适合经常需要把整个环境退回到未变更之前的状态

传统的部署中，这些操作我们一般会使用一个叫`Check List`的变更步骤进行管理。在`Check List`上我们一般会记录我们的操作顺序，每个操作顺序的正向操作内容，以及反向操作内容(用于回退)。这样我们就可以保证我们的变更操作的可靠性，和可维护性。当时大家应该能理解，把所有操作文档化并且提供回退步骤这需要花费不少时间进行准备，且还可能存在认为失误。（当然一般`Check List`完成后会有`review`）

如果我们以IaC为方向来进行思考，我想我会这样做：

1. 把所有操作进行分类，比如服务器磁盘操作、服务器网络操作、系统参数调整等
1. 所有操作有对应的脚本，如果是可回退操作会有回退脚本。如果不可回退那么要特殊分类或对待
1. 基于上述的操作，还会进行逻辑上合集，比如部署一台应用服务器操作，包含：操作系统安装，服务器磁盘配置，系统参数调整等，而且这些合集应该还会有到应用的分类，比如部署的是淘宝首页的应用服务器
1. 有一个服务器列表，这个列表需要有老服务器和新服务器，也需要进行分类，如：应用服务器，数据库服务器，中间件服务器等
1. 有一个日志功能可以记录所有日志情况

基于上述构思

- 如果需要进行扩容，只需要在原有服务器列表中增加一些新服务器，并执行下部署操作那么新服务器就可以很快部署好，新服务器也是采用和老服务器一样的脚本进行操作的所以部署出了同样配置的服务器
- 如果需要进行迁移，只需要更新所有服务器列表并执行部署
- 如果需要回退，我们只需对那些需要回退的服务器执行同一操作回退功能

有了IaC是不是发现运维人员超轻松呢？

有了IaC我们的操作都是可追溯，可管理并快速响应。

下面是参考<[解读基础设施即代码](https://insights.thoughtworks.cn/nfrastructure-as-code/)>的总结

```markdown
基础设施即代码有四项关键原则:

- 再生性。环境中的任何元素可以轻松复制。
- 一致性。无论何时，创建的环境各个元素的配置是完全相同的。
- 快速反馈。能够频繁、容易地进行变更，并快速知道变更是否正确。
- 可见性。所有对环境的变更应该容易理解、可审计、受版本控制。

基础设施即代码的目标是：

- 标准化。 以代码来定义环境，实现开发环境、测试环境、生产环境的标准化。
- 自动化。 以自动化工具来驱动代码准备环境。包括创建环境、更新环境以及销毁环境。
- 可视化。 以监控来可视化环境信息。环境当前状态可视、环境变更历史可视、可追溯。
```

## IaC相关工具

可参考<[15 Infrastructure as Code tools you can use to automate your deployments](https://www.thorntech.com/2018/04/15-infrastructure-as-code-tools/)>

目前市面上已经有很成熟的工具了，对于自动部署我比较喜欢`Ansible`，它架构和配置比较简单，使用起来很方便。

上面文章中把`Docker`也列在工具内，我会把它和`Kubernetes`放在一起讨论。

## Everything as code

这里引入另一个概念`Everything as code`，我自己的翻译是，`一起都代码化`（基础设施、文档、代码等等）

做过开发的人都知道一个工具`Git`，这个工具现在已经非常普及。开发人员也大都知道另一个工具`markdown`，比如你在看的这篇文章就是用`markdown`写的。

代码为什么要使用`Git`进行管理了？很重要的一个原因是版本问题，这里版本不单指应用的版本，应该包括代码的一切变动。这样的好处是在`排查Bug`和`版本管理`的时候就可以很方便找到要的代码。

这里我们试着思考一种场景：

1. 如果我们有一个应用对环境依赖比较大，假设每次应用的变更都要进行基础设施变更
1. 这时候如果我们的应用需要部署1.0版本，是不是我们也希望获得1.0版本对应的基础设施配置
1. 基于这样的场景我们如果将基础设施配置也通过`Git`与应用进行`类版本`的管理那么会不会更理想。我这里指的`类版本`是因为并不一定他们是一一对应的，但至少他们是有一个关系存在，比如应用2.0和1.0都对应基础设施配置的1.0版本

所以就有人提出应该把`一切都代码化`，这样我们就可以通过`Git`的管理功能把一切资源串联再一起形成一个链条。

# 总结

到这里我已经阐述了我个人对IaC的思考与理解。总的来说IaC在过去几年已经大大改变了运维人的工作方式和思维习惯，对运维人员的工作起到非常大的帮助。

后续我们将聊聊对运维带来革命的一项技术：Kubernetes，当然它与IaC也有非常大的关系。

# 参考

- [Infrastructure as code: What is it? Why is it important?](https://www.hashicorp.com/resources/what-is-infrastructure-as-code)
- [15 Infrastructure as Code tools you can use to automate your deployments](https://www.thorntech.com/2018/04/15-infrastructure-as-code-tools/)
- [Infrastructure as Code: 5 Reasons Why You Should Implement IaC Now](https://www.thorntech.com/2018/01/infrastructureascodebenefits/)
- [Everything as Code: The future of ops tools](https://www.hashicorp.com/resources/everything-as-code-the-future-of-ops-tools)
- [Infrastructure and How “Everything as Code” changes everything](https://www.bmc.com/blogs/infrastructure-everything-code-changes-everything/)
