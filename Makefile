.PHONY: link unlink

install:
	cp $$(pwd)/git-subtree-import $${prefix-/usr/local}/bin/git-subtree-import
	cp $$(pwd)/git-subtree-export $${prefix-/usr/local}/bin/git-subtree-export

link:
	ln -s $$(pwd)/git-subtree-import $${prefix-/usr/local}/bin/git-subtree-import
	ln -s $$(pwd)/git-subtree-export $${prefix-/usr/local}/bin/git-subtree-export

uninstall:
	rm -f $${prefix-/usr/local}/bin/git-subtree-import
	rm -f $${prefix-/usr/local}/bin/git-subtree-export
