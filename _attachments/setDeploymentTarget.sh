#!/bin/bash
TARGET=$1
if [ $# -lt 1 ]
  then
    printf "Must specify the target URL, e.g.\\n  ./setDeploymentTarget.sh zanzibar\\n"
    exit
fi
echo "Setting database in app/Coconut.coffee to use $TARGET"
sed "s#\@databaseName = .*#\@databaseName = \"$TARGET\"#" app/Coconut.coffee > /tmp/Coconut.coffee; cp /tmp/Coconut.coffee app/Coconut.coffee
