all: deploy

add:
	git add .

commit: add
	git commit -am "ok"

push: commit
	git push origin master

generate: push
	hexo g

deploy: generate
	hexo d
	echo "myblog site: https://hellwen.github.io/"
