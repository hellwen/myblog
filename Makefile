all: deploy

add:
	git add .

commit: add
	git commit -am "ok"

push: commit
	git push origin master

generate: push
	cd ~/hexo && hexo g

deploy: generate
	cd ~/hexo && hexo d
