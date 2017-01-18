


wget https://nodejs.org/dist/v4.7.2/node-v4.7.2-linux-x64.tar.xz

xz -d node-v4.7.2-linux-x64.tar.xz

tar -xf node-v4.7.2-linux-x64.tar


mv node-v4.7.2-linux-x64 node

rm -f node-v4.7.2-linux-x64.tar

cat << EOF >> ~/.bash_profile
export NODEROOT=\$MY_BIN/node
export PATH=\$PATH:\$NODEROOT/bin
EOF


mkdir hexo
cd hexo
npm install -g hexo-cli
hexo init


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

hexo server

hexo generate
hexo d

