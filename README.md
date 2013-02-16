# git-subdir

Provides `git subdir` command that allows you to embed a subrepository within another Git repository — kind of like `git submodule` and `git subtree`.

Quick intro:

    # embedding a repository
    cd ~/master-repo
    git subdir myembedded/ --url git@github.com/myname/embedded-repo.git --import

    # exporting commits to the embedded repo
    git subdir myembedded/ --status   # preview the outgoing commits
    git subdir myembedded/ --export

    # importing commits from the embedded repo
    git subdir myembedded/ --status   # preview the incoming commits
    git subdir myembedded/ --import

Compared to other approaches, git-subdir:

* Embeds the actual content, not just a reference (like git-subtree and unlike git-submodule).
* Does not store any metadata, and there's no requirement for the imported commits to stay intact. Rebase, amend and filter-branch to your heart's content.
* Does not try to map commits across repositories. It focuses on the commits that need to be imported or exported at the moment, and does not care about historical commits.
* In fact, there is no persistent state at all (aside from some command-line options automatically saved as defaults for later).
* Will happily pick up the results of git-subtree, subtree merge or any other way of syncing folders. In fact, even if you have copied the subfolder via drag'n'drop or `cp -r`, you can still use git-subdir to sync changes.
* Syncs both ways: you can commit into the embedded repository and then import the commits into the master one, or you can commit in the master repository and then export the commits into the embedded one. In fact, you can alternate between the two approaches.

To put it simply, the idea of git-subdir is that, conceptually, we want an approach similar to cherry-picking rather than the strict semantics of normal merge/rebase.

Caveats:

* Requires manual intervention to merge changes when there are both incoming and outgoing commits. This isn't a conceptual problem, just something that hasn't been implemented yet. See a dedicated warning section below.
* This is a very new piece of software, so bugs are expected in abundance.


## Installation

    curl -L https://github.com/andreyvit/git-subdir/raw/master/git-subdir | sudo tee /usr/bin/git-subdir >/dev/null

or:

    git clone https://github.com/andreyvit/git-subdir.git
    cd git-subdir
    make install

For development use `make link` instead. You can also run the tests using the provided `test-*.sh` scripts. (Note: the tests don't have any assertions; it's up to you to look at the output logs and see if everything worked well. It is very easy to do, though, and it's usually enough to only inspect the final git log.)


## Example use case

Imagine you have a project called _mysite_ that uses another project called _mixins_.

* You want _mixins_ to live in its own repository.
* You also want _mysite_ to contain a copy of _mixins_ under `lib/mixins` subfolder.
* You want to easily copy changes between the two.

Here's how you set that up, assuming that _mixins_ repository lives on GitHub.

First, add a copy of _mixins_ to _mysite_:

    $ cd ~/mysite
    $ git subdir lib/mixins --url https://github.com/youraccount/mixins.git -I

Bingo; `lib/mixins` now contains a copy of _mixins_. There's a merge commit that binds the two repositories together.

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

If some other sites (yoursite, theirsite) also have copies of _mixins_ (and have already been set up with git-subdir), you can now import the changes you have just exported into all those projects:

    $ cd ~/yoursite
    $ git subdir lib/mixins       # make sure everything looks fine
    $ git subdir lib/mixins -I
    $ cd ~/theirsite
    $ git subdir lib/mixins       # make sure everything looks fine
    $ git subdir lib/mixins -I

With git-subdir, you're free to make changes wherever you like knowing that you can sync them later.


## Synopsis

Usage:

    git subdir [-Q | -S | -E | -I]
    git subdir [-Q | -S | -E | -I] <subdir> [-r <remote>] [-b branch] [--url <url>] [...]

This command runs one of the following four operations, defaulting to the `--status` one:

    -S, --sync              sync (import and/or export)
    -I, --import            import changes
    -E, --export            export changes
    -Q, --status            display the current status (the default mode), aka 'query' mode

Subdirectory options (saved into git config per `<subdir>` automatically):

    -r, --remote <remote>   remote name
    -b, --branch <branch>   remote branch name
    --url <url>             remote url (if you want git-subdir to set up git-remote automatically)
    -M, --method <method>   importing method (discussed below)
    --prefix <prefix>       prefix for imported commit msgs

Available expansions for `--prefix`: `<remote>`, `<branch>`, `<subdir>`.

Subdirectory option defaults: `-r $(basename <subdir>) -b master -M squash --prefix '[<remote>] '`.

Other options:

    -F, --no-fetch          don't run 'git fetch'
    --fetch                 do run 'git fetch' (override --no-fetch in case you have a script/alias)

    -n, --dry-run           don't execute anything, merely print the commands that would be executed
    --force                 force importing even in the presence of incoming changes

If no `<subdir>` is specified, the command should operate on all subdirectories mentioned in git config. Unfortunately, this mode is not implemented yet.

If you specify `--url <url>`, a Git remote named `<remote>` will be created automatically if it does not exist. Or, if the remote does exist, its url will be updated when necessary.


## Choosing the history importing method

When importing commits from the embedded repository, git-subdir can use one of the following approaches to deal with the imported history. Illustrated with sample git logs of the master repository.

* `--method=squash` merges (squashes) the incoming commits into a single commit on every import. The history stays linear, and you don't see the individual imported commits:

        * 3dc1607 - (HEAD, master) [foo] Update to ee41ff0
        * 764582d - set f = 49 and b = 13
        * 184ec32 - [foo] Update to d22c2bd
        * 86456aa - set f = 47
        * 4943c34 - set f = 46
        * e238c48 - [foo] Update to 65c0d23
        * 3797560 - [foo] Import 9e22367
        * cf21d4e - set b = 12
        * 054345a - add b = 11

* `--method=linear` adds individual incoming commits into your repository; the history stays linear:

        * 0fa70d1 - (HEAD, master) [foo] set f = 50
        * 66d8704 - set f = 49 and b = 13
        * 78d47b9 - [foo] set f = 48
        * d24051f - set f = 47
        * d2bd079 - set f = 46
        * 18b63a7 - [foo] set f = 45
        * 63d779d - [foo] set f = 44
        * 000a770 - [foo] set f = 43
        * 2b0d4eb - [foo] add f = 42
        * 01f6488 - set b = 12
        * b7ef91c - add b = 11

* `--method=merge` adds _unmodified_ incoming commits to your history, and then adds one merge commit per import to join the histories.

    This is how subtree merges (`git merge -s subtree`) normally work in Git, and also the default mode of git-subtree. Your history becomes a mess, and the exported commits will be duplicated.

    You _might_ find this mode appealing because it provides a better separation between the repositories and still keeps the individual commits; it also leaves enough metadata for subtree merges to be operational in the future.

        *   83ef37f - (HEAD, master) [foo] Update to 9cbe394
        |\
        | * 9cbe394 - (foo/master) set f = 50
        | * e9af0a6 - set f = 49 and b = 13
        * | 0c54b1b - set f = 49 and b = 13
        * |   e0c67cf - [foo] Update to 0eeff53
        |\ \
        | |/
        | * 0eeff53 - set f = 48
        | * d276859 - set f = 47
        | * f14606d - set f = 46
        * | 8c4b5d6 - set f = 47
        * | 2eb3fa1 - set f = 46
        * |   c53fe8f - [foo] Update to 58be0c4
        |\ \
        | |/
        | * 58be0c4 - set f = 45
        | * f22eb8e - set f = 44
        * |   cbfc588 - [foo] Import 99c9be7
        |\ \
        | |/
        | * 99c9be7 - set f = 43
        | * f521f9d - add f = 42
        * 7cbc4f1 - set b = 12
        * 66ccc94 - add b = 11

    ↑↑↑↑ do you _really_ want your history to look like that?

* `--method=squash,linear` uses `squash` for the initial import and `linear` after that. Useful if you want `linear` but don't care to import the long prior history of the repository that you embed.

        * 15a0e85 - (HEAD, master) [foo] set f = 50
        * 74ad1fc - set f = 49 and b = 13
        * 2c2c938 - [foo] set f = 48
        * 2153dbf - set f = 47
        * 75eaac9 - set f = 46
        * 0e44e44 - [foo] set f = 45
        * ff10f73 - [foo] set f = 44
        * de06e66 - [foo] Import 638fb59
        * 4991bc4 - set b = 12
        * a890970 - add b = 11

* `--method=squash,merge` uses `squash` for the initial import and `merge` after that:

        *   cfdca8d - (HEAD, master) [foo] Update to adb4da0
        |\
        | * adb4da0 - (foo/master) set f = 50
        | * ad57dde - set f = 49 and b = 13
        * | 523bcea - set f = 49 and b = 13
        * |   98a14c0 - [foo] Update to 14afbe2
        |\ \
        | |/
        | * 14afbe2 - set f = 48
        | * 8866f7f - set f = 47
        | * 30c2fd0 - set f = 46
        * | dc3c34b - set f = 47
        * | f920010 - set f = 46
        * |   cfe6080 - [foo] Update to b4c7b07
        |\ \
        | |/
        | * b4c7b07 - set f = 45
        | * 567bd03 - set f = 44
        | * f01b80e - set f = 43
        | * 11bfea6 - add f = 42
        * 96858c3 - [foo] Import f01b80e
        * bd56bc4 - set b = 12
        * 1dbfc58 - add b = 11

Like other subdir options, the chosen method is saved in your git options and used in subsequent invocations.

Please note that you're free to change the importing method down the line. In fact, you are free to merge, split, rebase, amend the imported commits as you like, or even do crazy stuff like `git filter-branch`, as long as your changes don't affect the actual content of `<subdir>`.

The beauty of git-subdir is that it does not care about the commits when importing and exporting changes; all it cares about is the actual data in your `<subdir>` matching the data in the imported repository at some point in history.


## Sharing git-subdir config

Unlike git-submodule, git-subdir does not have a notion of a shared `.gitmodules` file. That is by design; neighter your repository nor the world in general needs another obscure configuration file.

To share settings with your collaborators, create a simple shell script, perhaps calling it `git-subdirs.sh`:

    git subdir some/cool-dir --url git@github.com:youraccount/cool-repo.git
    git subdir another-dir --url git@github.com:youraccount/another-repo.git --branch stable

Because all of these values are saved into your `git config`, you only need to run `git subdir <subdir>` to sync in the future.

(To have even less files to maintain, you can put these commands in your README instead of a shell script.)


## Configuration

* `git config --global subdir.importMessage '<prefix>Update to <commit>'`

    A message to use for squash and merge commits when using the respective modes, and also for reflogs.

    (This message is used when updating an existing copy. For the initial import, _subdir.initialImportMessage_ is used instead.)

    Available expansions:

    * `<remote>`, `<branch>`, `<subdir>`, `<prefix>` — values set by the corresponding options;
    * `<commit>` — an abbreviated id of the latest imported commit.

* `git config --global subdir.initialImportMessage '<prefix>Import <commit>'`

    Similar to _subdir.importMessage_, but used for the initial import.


## Warning: If there are both incoming and outgoing changes...

...you've got a bit of a problem. In fact, git-subdir tells you as much:

    Houston, we have a problem!

        There are both incoming and outgoing commits.
        Please read the docs about resolving this case.
        Refusing to do anything to avoid screwing up.

        You can use --force to override, but pls be very sure!

        FYI, here's the most recently imported/exported commit:
        f395909 - blah (1 seconds ago) <Andrey Tarantsov>

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


## How git-subdir determines to commits to sync

First, git-subdir finds the most recent commit in the embedded repository that matches the _content_ of the specified `<subdir>` of the master repository _at some point in history_. We'll call that a _base_ commit.

(Let that sink in.)

After we have the base commit, things get very simple:

* Any commits in the embedded repository made after the base commit need to be imported, and are thus called _incoming commits_.

* Any commits that affect `<subdir>` in the master repository and made after the base commit, need to be _exported_, and are thus called _outgoing commits_.

If we have both incoming and outgoing commits, we have to merge them as described below. This isn't handled very well right now (see a warning section above).

If we only have incoming commits, we can import them. You have a choice of several methods to deal with the imported history.

If we only have outgoing commits, we can export them; internally, this looks very similar to cherry-picking.


## git-subdir vs git-subtree vs subtree merge

Here's how git-subdir is different from git-subtree:

* does not store any kind of metadata, does not annotate commits — your repository has no trace of git-subdir (we do store the value of `--remote` and `--branch` in `git config`, so that you don't need to type it all over again)
* does not even care that commits match, as long as they point to the same subdir tree
* does not support splitting an existing repository (git-subtree works fine for that)
* importing does not rely on subtree merge, so you can sync changes two-way without stupid conflicts
* exporting does not try to be smart, it simply finds commits that are missing from the target repository and exports them, staying blissfully ignorant of merges; as a contrast, git-subtree relies on recreating the target repository from scratch via `git-split` and hopes that the result stays compatible with the actual target, which is kinda fragile

So:

* the biggest difference of `git subdir` from `git subtree pull` (and `git pull -s subtree`) is that the former does not use subtree merge;

* the biggest difference of `git subdir` from `git subtree push` is that the former is similar to cherry-picking the new commits, while the latter is similar to doing `git filter-branch` followed by `git push`.
