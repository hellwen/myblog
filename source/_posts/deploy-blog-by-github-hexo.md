title: Deploy private blog using Github and Hexo
date: 2017-01-18 14:00:00
tags:
- github
- hexo
- blog
---

## Install nodejs

### Download and Install nodejs

先找个地方，用于存放你的node程序

一般会使用固定的目录，如：/data/daen-bin

```
mkdir -p /data/dean-bin
cd /data/dean-bin
```

下载并解压程序文件到dean-bin目录

```
wget https://nodejs.org/dist/v4.7.2/node-v4.7.2-linux-x64.tar.xz
xz -d node-v4.7.2-linux-x64.tar.xz
tar -xf node-v4.7.2-linux-x64.tar
rm -f node-v4.7.2-linux-x64.tar
```

创建node链接，方便后续更新版本不需要更新配置

```
ln -s node-v4.7.2-linux-x64 node
```

修改profile文件，让其可以读取到node和npm两个命令

```
cat << EOF >> ~/.bash_profile
export MY_BIN=/data/dean-bin
export NODEROOT=\$MY_BIN/node
export PATH=\$PATH:\$NODEROOT/bin
EOF
```

## Install hexo

创建hexo文件夹，并安装hexo，同时进行初始化

```
mkdir hexo
cd hexo
npm install -g hexo-cli
hexo init
```

安装hexo插件

```
npm install hexo-generator-index --save
npm install hexo-generator-archive --save
npm install hexo-generator-category --save
npm install hexo-generator-tag --save
npm install hexo-server --save
npm install hexo-deployer-git --save
npm install hexo-deployer-heroku --save
npm install hexo-deployer-rsync --save
npm install hexo-deployer-openshift --save
npm install hexo-renderer-marked --save
npm install hexo-renderer-stylus --save
npm install hexo-generator-feed --save
npm install hexo-generator-sitemap --save
```

启动hexo服务进行本地测试

```
$ hexo s
INFO  Start processing
INFO  Hexo is running at http://localhost:4000/. Press Ctrl+C to stop.
```

如果出现上面提示，你就可以通过本地的4000端口访问页面，访问成功说明hexo可正常使用


## 创建github仓库（注册自行解决，并确定已经将自己的私有key放在github上。也就是可以免密码使用git）

在github上创建仓库：xxx.github.io.git

其中xxx为你的git用户名，如：git@github.com:dean/dean.github.io.git

## 修改hexo配置

其中title, subtitle, description, author根据按字面理解进行修改
language设置成zh_CN
url设置成你自己的域名，如果不进行域名执行可不修改
其中deploy参照下列进行修改

最终的配置文件：

```
# Hexo Configuration
## Docs: https://hexo.io/docs/configuration.html
## Source: https://github.com/hexojs/hexo/

# Site
title: Dean's Blog
subtitle: to going...
description:
author: Dean.wu
language: zh_CN
timezone:

# URL
## If your site is put in a subdirectory, set url as 'http://yoursite.com/child' and root as '/child/'
url: http://yoursite.com
root: /
permalink: :year/:month/:day/:title/
permalink_defaults:

# Directory
source_dir: source
public_dir: public
tag_dir: tags
archive_dir: archives
category_dir: categories
code_dir: downloads/code
i18n_dir: :lang
skip_render:

# Writing
new_post_name: :title.md # File name of new posts
default_layout: post
titlecase: false # Transform title into titlecase
external_link: true # Open external links in new tab
filename_case: 0
render_drafts: false
post_asset_folder: false
relative_link: false
future: true
highlight:
  enable: true
  line_number: true
  auto_detect: false
  tab_replace:

# Category & Tag
default_category: uncategorized
category_map:
tag_map:

# Date / Time format
## Hexo uses Moment.js to parse and display date
## You can customize the date format as defined in
## http://momentjs.com/docs/#/displaying/format/
date_format: YYYY-MM-DD
time_format: HH:mm:ss

# Pagination
## Set per_page to 0 to disable pagination
per_page: 10
pagination_dir: page

# Extensions
## Plugins: https://hexo.io/plugins/
## Themes: https://hexo.io/themes/
theme: landscape

# Deployment
## Docs: https://hexo.io/docs/deployment.html
deploy:
  type: git
  repo: git@github.com:xxx/xxx.github.io.git
  branch: master
  message: update :{{now("YYYY-MM-DD HH/mm/ss")}}
```

## 测试hexo部署

```
hexo g
hexo d
```

如果上述命令执行正常，你将可以打开你的博客页面：[https://xxx.github.io/](https://xxx.github.io/)

Done
