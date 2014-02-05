#!/bin/bash

ERR_SITE_GEN=1
ERR_SITE_DEPLOY=2
ERR_GIT_ADD=3
ERR_GIT_COMMIT=4
ERR_GIT_PUSH=5
ERR_NO_COMMIT_MESSAGE=6

if [ $# -eq 0 ]; then
    echo "You must specify a commit message. No quotes or flags required."
    exit ERR_NO_COMMIT_MESSAGE
elif ! rake generate; then
    echo "Error generating site."
    exit $ERR_SITE_GEN
elif ! rake deploy; then
    echo "Error deploying site."
    exit $ERR_SITE_DEPLOY
elif ! git add .; then
    echo "Error adding files to git."
    exit $ERR_GIT_ADD
elif ! git commit -a -m "$*"; then
    echo "Error committing files to git."
    exit $ERR_GIT_COMMIT
elif ! git push; then
    echo "Error pushing to git."
    exit $ERR_GIT_PUSH
fi
