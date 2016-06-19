#!/bin/bash

ROOT_DIR=$(cd $(dirname $0)/..; pwd)

get_summary() {
    (cd $ROOT_DIR && git log -1 --pretty='%s')
}

get_hash() {
    (cd $ROOT_DIR && git log -1 --pretty='%H')
}

publish() {
    commit_hash=$(get_hash)
    summary=$(get_summary)
    if (cd $ROOT_DIR/public && git diff --quiet); then
        echo "there are no changes to publish"
        return
    fi
    (cd $ROOT_DIR/public && \
        git diff --quiet && \
        git add . && \
        git commit -m "publish ${commit_hash}: \"${summary}\"" && \
        git push
    )
    # update submodule
    (cd $ROOT_DIR && \
        git add public && \
        git commit -m "published ${commit_hash} automatically" && \
        git push
    )
}

publish
