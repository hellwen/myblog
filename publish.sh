#!/bin/sh

hugo

SITEPATH="/home/trams/Develop/hellwen.github.io"
BLOGPATH="/home/trams/Develop/myblog"

cd $SITEPATH

echo "Move file"
rm -rf *
mv ${BLOGPATH}/public/* .
rmdir ${BLOGPATH}/public

echo "Git Commit"
git add .
git commit -m "publish"
git push -u origin master
