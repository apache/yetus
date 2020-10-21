#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SHELLDOC-IGNORE

this="${BASH_SOURCE-$0}"
thisdir=$(cd -P -- "$(dirname -- "${this}")" >/dev/null && pwd -P)

pushd "${thisdir}/.." >/dev/null || exit 1

if [[ ! -d precommit ]]; then
  echo "ERROR: Unsure about directory structure."
  exit 1
fi

#shellcheck source=precommit/src/main/shell/core.d/00-yetuslib.sh
. precommit/src/main/shell/core.d/00-yetuslib.sh

BINDIR=$(yetus_abs "${thisdir}")
BASEDIR=$(yetus_abs "${BINDIR}/..")
STARTING_BRANCH=main

USER_NAME=${SUDO_USER:=$USER}
USER_ID=$(id -u "${USER_NAME}")
pushd "${BASEDIR}" >/dev/null || exit 1

usage()
{
  yetus_add_option "--jira=<issue>" "[REQUIRED] Path to use to store release bits"
  yetus_add_option "--startingbranch=<git ref>" "Make an ASF release"
  yetus_add_option "--version=[version]" "Use an alternative version string"
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage
}

option_parse()
{
  declare i

  for i in "$@"; do
    case ${i} in
      --jira=*)
        JIRAISSUE=${i#*=}
      ;;
      --help)
        usage
        exit
      ;;
      --startingbranch=*)
        STARTING_BRANCH=${i#*=}
      ;;
      --version=*)
        NEW_BRANCH_VERSION=${i#*=}
      ;;
    esac
  done

  if [[ -z "${JIRAISSUE}" ]]; then
    usage
    exit 1
  fi
}

docker_run() {
  docker run -i \
    -v "${PWD}:/src" \
    -v "${HOME}/.m2:${HOME}/.m2" \
    -u "${USER_ID}" \
    -e "HOME=${HOME}" \
    -w /src \
    "apache/yetus:main" \
    "$@"
}

cleanup() {
  git checkout --force "${STARTING_BRANCH}"
  git branch -D "${JIRAISSUE}-release"
  exit 1
}

determine_versions() {
  declare major
  declare minor
  declare micro
  declare microinc

  OLD_BRANCH_VERSION=$(docker_run mvn -Dmaven.repo.local="${HOME}/.m2" help:evaluate -Dexpression=project.version -q -DforceStdout)

  if [[ ${OLD_BRANCH_VERSION} =~ -SNAPSHOT ]]; then
    if [[ -n "${NEW_BRANCH_VERSION}" ]]; then
      OLD_BRANCH_VERSION="${NEW_BRANCH_VERSION}"
    else
      NEW_BRANCH_VERSION=${OLD_BRANCH_VERSION//-SNAPSHOT}
    fi
    major=$(echo "${OLD_BRANCH_VERSION}" | cut -d. -f1)
    minor=$(echo "${OLD_BRANCH_VERSION}" | cut -d. -f2)
    ((minor=minor+1))
    NEW_MAIN_VERSION="${major}.${minor}.0-SNAPSHOT"
  elif [[ -z "${NEW_BRANCH_VERSION}" ]]; then
    major=$(echo "${OLD_BRANCH_VERSION}" | cut -d. -f1)
    minor=$(echo "${OLD_BRANCH_VERSION}" | cut -d. -f2)
    micro=$(echo "${OLD_BRANCH_VERSION}" | cut -d. -f3)
    ((microinc=micro+1))
    NEW_BRANCH_VERSION="${major}.${minor}.${microinc}"
  fi
}

update_version() {
  declare oldversion=${1//\./\\.}
  declare newversion=$2

  # *MOST* systems have sed -i these days
  while read -r file; do
    sed -i "s,${oldversion},${newversion},g" "${file}"
  done < <( find . -name 'pom.xml')
}

option_parse "$@"

trap cleanup INT QUIT TRAP ABRT BUS SEGV TERM ERR

set -x

git clean -xdf

docker_run mvn -Dmaven.repo.local="${HOME}/.m2" clean

git fetch origin
git checkout --force "${STARTING_BRANCH}"
git fetch origin
if [[ ! "${STARTING_BRANCH}" =~ rel ]]; then
  git rebase "origin/${STARTING_BRANCH}"
fi

determine_versions

git checkout -b "${JIRAISSUE}-release"

update_version "${OLD_BRANCH_VERSION}" "${NEW_BRANCH_VERSION}"

git commit -a -m "${JIRAISSUE}. Stage version ${NEW_BRANCH_VERSION}"

if [[ -n "${NEW_MAIN_VERSION}" ]]; then

  git checkout -b "${JIRAISSUE}-${STARTING_BRANCH}"
  update_version "${OLD_BRANCH_VERSION}" "${NEW_MAIN_VERSION}"
fi

git checkout "${JIRAISSUE}-release"
echo "Source tree is now in ${JIRAISSUE}-release"
popd >/dev/null || exit 1
