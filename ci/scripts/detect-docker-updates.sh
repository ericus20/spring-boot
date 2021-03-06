#!/bin/bash

existing_tasks=$( curl -s https://api.github.com/repos/${GITHUB_ORGANIZATION}/${GITHUB_REPO}/pulls\?labels\=type:%20task\&state\=open\&creator\=spring-buildmaster )
existing_upgrade_issues=$( echo "$existing_tasks" | jq -c --arg TITLE "$ISSUE_TITLE" '.[] | select(.title==$TITLE)' )

if [[ ${existing_upgrade_issues} = "" ]]; then
  git clone git-repo git-repo-updated > /dev/null
else
  git clone git-repo-ci-docker git-repo-updated > /dev/null
  echo "Pull request already exists."
  exit 0
fi

latest_version=$(curl -I -s https://github.com/docker/docker-ce/releases/latest | grep "location:" | awk '{n=split($0, parts, "/"); print substr(parts[n],2);}' | awk '{$1=$1;print}' | tr -d '\r' | tr -d '\n' )

if [[ $latest_version =~ (beta|rc) ]]; then
	echo "Skip pre-release versions"
	exit 0;
fi

latest="https://download.docker.com/linux/static/stable/x86_64/docker-$latest_version.tgz"
current=$( git-repo/ci/images/get-docker-url.sh )

if [[ $current = $latest ]]; then
	echo "Already up-to-date"
	exit 0;
fi

pushd git-repo-updated > /dev/null
git config user.name "Spring Buildmaster" > /dev/null
git config user.email "buildmaster@springframework.org" > /dev/null
sed -i "s/version=.*/version=\"$latest_version\"/" ci/images/get-docker-url.sh
git add ci/images/get-docker-url.sh > /dev/null
commit_message="Upgrade to Docker $latest_version in CI"
git commit -m "$commit_message" > /dev/null
popd
echo ${commit_message} > commit-details/message