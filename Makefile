all: push

add:
	git add .

commit: add
	git commit -am "ok"

push: commit
	git push origin master
