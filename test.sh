#!/bin/bash

die() {
    echo "** $*. Stop."
    exit 1
}

step() {
    echo
    echo
    echo "================================================================="
    echo "$1"
    echo "-----------------------------------------------------------------"
}

escape() {
    if test "${1//[ \'\"\\]/}" = "$1"; then
        echo -n "$1"
    else
        if test "${1//\"/}" = "$1"; then
            echo -n "\"$1\""
        else
            if test "${1//\'/}" = "$1"; then
                echo -n "'$1'"
            else
                printf "%q" "$1"
            fi
        fi
    fi
}

escape_and_prettify() {
    escape "$1" | perl -we 'while(<STDIN>) { s!$ARGV[0]/!\$test_dir/!g; s!$ARGV[1]/!\$root_dir/!g; print }' -- "$test_dir" "$root_dir"
}

escape_args() {
    for arg in "$@"; do
        escape_and_prettify "$arg"
        echo -n " "
    done
}

run() {
    echo
    echo "$(escape_args "$@")"
    "$@" 2>&1 | sed 's/^/    /'
    test ${PIPESTATUS[0]} -eq 0 || die "$* failed"
}

run_sh() {
    echo
    echo "$*"
    sh -c "$*" 2>&1 | sed 's/^/    /'
    test ${PIPESTATUS[0]} -eq 0 || die "$* failed"
}

run_cd() {
    echo
    echo cd "$(escape_and_prettify "$1")"
    cd "$1"
}

git-fancylog() {
    git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative "$@"
}

cd $(dirname $0)
root_dir=$(pwd)
test_dir=$root_dir/test
rm -rf $test_dir


####################################################################################################
step "Preparing foo"

mkdir -p $test_dir/foo
run_cd $test_dir/foo
run git init
run git config receive.denyCurrentBranch warn

run_sh 'echo 42 >f'
run git add f
run git commit -m "add f = 42"

run_sh 'echo 43 >f'
run git add f
run git commit -m "set f = 43"

run git-fancylog


####################################################################################################
step "Preparing bar"

mkdir -p $test_dir/bar
run_cd $test_dir/bar
run git init

run_sh 'echo 11 >b'
run git add b
run git commit -m "add b = 11"

run_sh 'echo 12 >b'
run git add b
run git commit -m "set b = 12"

run git-fancylog


####################################################################################################
step "Adding foo to bar"

run_cd $test_dir/bar
run $root_dir/git-subdir foo/ --url $test_dir/foo -I
run git-fancylog


####################################################################################################
step "Commit into foo, import into bar"

run_cd $test_dir/foo
run_sh 'echo 44 >f'
run git add f
run git commit -m "set f = 44"
run git-fancylog

run_cd $test_dir/foo
run_sh 'echo 45 >f'
run git add f
run git commit -m "set f = 45"
run git-fancylog

run_cd $test_dir/bar
run $root_dir/git-subdir foo/ -I


####################################################################################################
step "Commit into bar (only touching foo/), export into foo"

run_cd $test_dir/bar
run_sh 'echo 46 >foo/f'
run git add foo/f
run git commit -m "set f = 46"
run git-fancylog

run_cd $test_dir/bar
run_sh 'echo 47 >foo/f'
run git add foo/f
run git commit -m "set f = 47"
run git-fancylog

run $root_dir/git-subdir -d foo -E
run git-fancylog

run_cd $test_dir/foo
run git-fancylog


####################################################################################################
step "Do more changes in foo, import into bar"

run_cd $test_dir/foo
run_sh 'echo 48 >f'
run git add f
run git commit -m "set f = 48"
run git-fancylog

run_cd $test_dir/bar
run $root_dir/git-subdir foo/ -I
run git-fancylog


####################################################################################################
step "Commit into bar (touching multiple paths including foo/), export into foo"

run_cd $test_dir/bar
run_sh 'echo 13 >b'
run_sh 'echo 49 >foo/f'
run git add b foo/f
run git commit -m "set f = 49 and b = 13"
run git-fancylog

run $root_dir/git-subdir -d foo -E
run git-fancylog

run_cd $test_dir/foo
run git-fancylog


####################################################################################################
step "Do more changes in foo, import into bar"

run_cd $test_dir/foo
run_sh 'echo 50 >f'
run git add f
run git commit -m "set f = 50"
run git-fancylog

run_cd $test_dir/bar
run $root_dir/git-subdir foo/ -I
run git-fancylog

# run git subtree push --prefix=foo foo master
# run git merge -s subtree --log=10 -m "Update foo subproject" foo/master

# run_cd $test_dir/foo
# run git-fancylog
