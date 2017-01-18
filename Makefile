all: publish

add:
	git add .

commit: add
	git commit -am "ok"

push: commit
	git push origin master

publish: push
	cd ~/hexo
	make
