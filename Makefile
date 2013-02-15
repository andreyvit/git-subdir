.PHONY: link unlink

install:
	cp $$(pwd)/git-subdir $${prefix-/usr/local}/bin/git-subdir

link:
	ln -s $$(pwd)/git-subdir $${prefix-/usr/local}/bin/git-subdir

uninstall:
	rm -f $${prefix-/usr/local}/bin/git-subdir
