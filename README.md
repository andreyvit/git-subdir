# git-subdir

A reimplementation of git-subtree that works better for simple workflows. As you might have guessed, it provides a new `git subdir` command.


## Example use case

Imagine you have a project called _mysite_ that uses another project called _mixins_.

* You want _mixins_ to live in its own repository.
* You also want _mysite_ to contain a copy of _mixins_ under `lib/mixins` subfolder.
* You want to easily copy changes between the two.

Here's how you set that up, assuming that _mixins_ repository lives on GitHub.

First, add a copy of _mixins_ to _mysite_:

    $ cd ~/mysite
    $ git remote add mixins
    $ git subdir lib/mixins --url https://github.com/youraccount/mixins.git -I

Bingo; `lib/mixins` now contains a copy of _mixins_ (including the entire version history). There's a merge commit that binds the two repositories together.

Proceeding to the cool stuff! Make a change in _mixins_...

    $ cd ~/mixins
    $ echo ".button($color) { background: $color }" >>useful.less
    $ git add useful.less
    $ git commit -m "Add .button mixin"

 ...and replicate the change into _mysite_:

    $ cd ~/mysite
    $ git subdir lib/mixins       # this will show you the status, make sure everything looks fine
    $ git subdir lib/mixins -I

A more likely scenario is that you change `lib/mixins` within _mysite_ first...

    $ cd ~/mysite
    $ echo ".clearfix() { overflow: visible }" >>lib/mixins/useful.less
    $ git add lib/mixins/useful.less
    $ git commit -m "Add .clearfix mixin"

...and then export those changes to the standalone repository later:

    $ cd ~/mysite
    $ git subdir lib/mixins       # make sure everything looks fine
    $ git subdir lib/mixins -E

If some other sites (_yoursite_, _theirsite_) also have copies of _mixins_ (and have already been set up with git-subdir), you can now import the changes you have just exported into all those projects:

    $ cd ~/yoursite
    $ git subdir lib/mixins       # make sure everything looks fine
    $ git subdir lib/mixins -I
    $ cd ~/theirsite
    $ git subdir lib/mixins       # make sure everything looks fine
    $ git subdir lib/mixins -I

With git-subdir, you're free to make changes wherever you like, knowing that you can sync them later.


## Synopsis

Usage:

    git subdir [-Q | -S | -E | -I]
    git subdir [-Q | -S | -E | -I] <subdir> [--remote <remote>] [--branch branch] [--url <url>]

This command runs one of the following four operations, defaulting to the `--status` one:

    -S, --sync              sync (import and/or export)
    -I, --import            import changes
    -E, --export            export changes
    -Q, --status            display the current status (the default mode), aka 'query' mode

Subdirectory options (saved into git config automatically):

    -r, --remote <remote>   remote name (defaults to the last component of <subdir>)
    -b, --branch <branch>   remote branch name (defaults to master)
    --url <url>             remote url (if you want git-subdir to set up git-remote automatically)

Other options:

    -F, --no-fetch          don't run 'git fetch'
    --fetch                 do run 'git fetch' (override --no-fetch in case you have a script/alias)

    -n, --dry-run           don't execute anything, merely print the commands that would be executed
    --force                 force importing even in the presence of incoming changes

If no `<subdir>` is specified, the command should operate on all subdirectories mentioned in git config. Unfortunately, this mode is not implemented yet.

If you specify `--url <url`, Git remote named `<remote>` will be created automatically if it does not exist, or, if the remote already exists, its url will be updated as necessary.

Import a subproject added as remote `<remote>` (branch `<branch>`) into directory `<subdir>` of the current branch:


Export any changes made in directory `<subdir>` on the current branch into an external subproject pointed to by remote `<remote>` (branch `<branch>`):

    git subtree-export <subdir> <remote> [<branch>]

If the `<branch>` is omitted, it defaults to master.


## Sharing git-subdir config

Unlike git-submodule, git-subdir does not have a notion of a shared `.gitmodules` file. That is by design; neighter your repository nor the world in general needs another obscure configuration file.

To share settings with your collaborators, create a simple shell script, perhaps calling it `git-subdirs.sh`:

    git subdir some/cool-dir --url git@github.com:youraccount/cool-repo.git
    git subdir another-dir --url git@github.com:youraccount/another-repo.git --branch stable

Because all of these values are saved into your `git config`, you only need to run `git subdir <subdir>` to sync in the future.

(To have even less files to maintain, you can put these commands in your README instead of a shell script.)


## Warning: If there are both incoming and outgoing changes...

...you've got a bit of a problem. In fact, git-subdir tells you as much:

    Houston, we have a problem!

        There are both incoming and outgoing commits.
        Please read the docs about resolving this case.
        Refusing to do anything to avoid screwing up.

        You can use --force to override, but pls be very sure!

        FYI, here's the most recently imported/exported commit:
        f395909 - blah (1 seconds ago) <Andrey Tarantsov>

(WARNING WARNING: right now, because of an implementation bug, this warning is triggered way more often than necessary. You need to use `--force` in many import operations. I plan to work on an updated version soon.)

Before we get to it, let me advise you to avoid this case. You're free to make changes in _mysite_ and export them to _mixins_, and you're free to make changes in _mixins_ and import them into _mysite_, but you need to stick to one of these options at a time to avoid unnecessary trouble.

Nevertheless, if you do find yourself with both incoming (“unimported”) and outgoing (“unexported”) changes, here's what you need to know.

First, running `git subdir` will fail if there are both incoming changes and outgoing changes. That's good, because you don't want to accidentally overwrite them.

Second, you can use `--force` to make `git subdir --import` proceed, which will overwrite any outgoing changes.

Third, the way you resolve this is by running `git subdir --export --branch <temp-branch>` to export changes into a separate branch in your destination repository (_mixins_), which will succeed because there are no incoming changes in that new empty branch. Then go into the destination repository and merge the changes there, like this:

    $ cd ~/mysite
    $ git subdir lib/mixins -E -b temp
    $ cd ~/mixins
    $ git fetch
    $ git checkout temp
    $ git rebase master       # this is where changes are actually merged
    $ git checkout master
    $ git merge temp
    $ git push
    $ cd ~/mysite
    $ git subdir lib/mixins -I -b master

I might automate this process in the future, perhaps as part of the import command.


## git-subdir vs git-subtree vs subtree merge

Here's how git-subdir is different from git-subtree:

* does not store any kind of metadata, does not annotate commits — your repository has no trace of git-subdir (we do store the value of `--remote` and `--branch` in `git config`, so that you don't need to type it all over again)
* does not currently support ‘squashing’ imported version history
* does not support splitting an existing repository (git-subtree works fine for that)
* importing does not rely on subtree merge, so you can sync changes two-way without stupid conflicts
* exporting does not try to be smart, it simply finds commits that are missing from the target repository and exports them, staying blissfully ignorant of merges; as a contrast, git-subtree relies on recreating the target repository from scratch via `git-split` and hopes that the result stays compatible with the actual target, which is kinda fragile

So:

* the biggest difference of `git subdir` from `git subtree pull` (and `git pull -s subtree`) is that the former does not use subtree merge;

* the biggest difference of `git subdir` from `git subtree push` is that the former is similar to cherry-picking the new commits, while the latter is similar to doing `git filter-branch` followed by `git push`.
