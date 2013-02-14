# git-subtree-additions

A naïve reimplementation of git-subtree that works better for simple workflows; provides `git subtree-import` and `git subtree-export` commands.


## Example use case

Imagine you have a project called _mysite_ that uses another project called _mixins_.

* You want _mixins_ to live in its own repository.
* You also want _mysite_ to contain a copy of _mixins_ under `lib/mixins` subfolder.
* You want to easily copy changes between the two.

Here's how you set that up, assuming that _mixins_ repository lives on GitHub.

First, add a copy of _mixins_ to _mysite_:

    $ cd ~/mysite
    $ git remote add mixins https://github.com/youraccount/mixins.git
    $ git subtree-import lib/mixins mixins

Bingo; `lib/mixins` now contains a copy of _mixins_ (including the entire version history). There's a merge commit that binds the two repositories together.

Now for the cool stuff. Make a change to _mixins_...

    $ cd ~/mixins
    $ echo ".button($color) { background: $color }" >>useful.less
    $ git add useful.less
    $ git commit -m "Add .button mixin"

 ...and replicate the change into _mysite_:

    $ cd ~/mysite
    $ git subtree-import lib/mixins mixins

A more likely scenario is that you change `lib/mixins` within _mysite_ first...

    $ cd ~/mysite
    $ echo ".clearfix() { overflow: visible }" >>lib/mixins/useful.less
    $ git add lib/mixins/useful.less
    $ git commit -m "Add .clearfix mixin"

...and then export those changes to the standalone repository later:

    $ cd ~/mysite
    $ git subtree-export lib/mixins mixins

If some other sites (_yoursite_, _theirsite_) also have copies of _mixins_, you can now import the changes you have just exported into all those projects:

    $ cd ~/yoursite
    $ git subtree-import lib/mixins mixins
    $ cd ~/theirsite
    $ git subtree-import lib/mixins mixins

With git-subtree-additions, you're free to make changes wherever you like, knowing that you can sync them later.


## Synopsis

Import a subproject added as remote `<remote>` (branch `<branch>`) into directory `<subdir>` of the current branch:

    git subtree-import <subdir> <remote> [<branch>]

Export any changes made in directory `<subdir>` on the current branch into an external subproject pointed to by remote `<remote>` (branch `<branch>`):

    git subtree-export <subdir> <remote> [<branch>]

If the `<branch>` is omitted, it defaults to master.


## Warning: If there are both incoming and outgoing changes...

...you've got a bit of a problem.

Before we get to it, let me advise you to avoid this case. You're free to make changes in _mysite_ and export them to _mixins_, and you're free to make changes in _mixins_ and import them into _mysite_, but you need to stick to one of these options at a time to avoid unnecessary trouble.

Nevertheless, if you do find yourself with both incoming (“unimported”) and outgoing (“unexported”) changes, here's what you need to know.

First, running `git subtree-export` will fail if there are incoming changes. That's good, because you don't want to accidentally overwrite them.

Second, `git subtree-import` will overwrite any outgoing changes without warning. The changes still remain in your version history, but the merge commit will appear to revert them. So if you're not sure, it's a good idea to run `git subtree-export` before `git subtree-import`.

Third, the way you resolve this is by running `git subtree-export` into a separate branch in your destination repository (_mixins_), then merging the branch there. Like this:

    $ cd ~/mysite
    $ git subtree-export lib/mixins mixins temp
    $ cd ~/mixins
    $ git fetch
    $ git checkout temp
    $ git rebase master       # this is where changes are actually merged
    $ git checkout master
    $ git merge temp
    $ git push
    $ cd ~/mysite
    $ git subtree-import lib/mixins mixins

I might automate this process in the future, perhaps as part of `git subtree-import`.


## git-subtree-additions vs git-subtree vs subtree merge

Here's how git-subtree-additions is different from git-subtree:

* does not store any kind of metadata, does not annotate commits — the repository has no trace of git-subtree-additions
* does not currently support ‘squashing’ imported version history
* does not support splitting an existing repository (for that use case, git-subtree works fine)
* importing does not rely on subtree merge, so you can sync changes two-way without stupid conflicts
* exporting does not try to be smart, it simply finds commits that are missing from the target repository and exports them, staying blissfully ignorant of merges; as a contrast, git-subtree relies on recreating the target repository from scratch via `git-split` and hopes that the result stays compatible with the actual target, which is kinda fragile

So:

* the biggest difference of `git subtree-import` from `git subtree pull` (and `git pull -s subtree`) is that the former does not use subtree merge;

* the biggest difference of `git subtree-exports` from `git subtree push` is that the former is similar to cherry-picking the new commits, while the latter is similar to doing `git filter-branch` followed by `git push`.
