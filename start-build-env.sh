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

make_cache_list() {
  gotit="false"
  cache_array=()
  for imagelocation in "${YETUS_DOCKER_REPO}" "${ASF_DOCKER_REPO}"; do
    if [[ "${imagelocation}" == "apache/yetus" ]]; then
      # skip Apache docker hub since we will pull from
      # github later
      continue
    fi
    for branch in "${BRANCH}" "main"; do
      for type in "-base" ""; do
        image="${imagelocation}${type}:${branch}"
        if docker pull "${image}"; then
          cache_array+=("${image}")
          gotit="true"
          break
        fi
      done
      if [[  "${gotit}" == "true" ]]; then
        gotit="false"
        break
      fi
    done
  done
  printf -v thelist "%s," "${cache_array[@]}"
  CACHE_LIST=${thelist%,}
}

set -e            # exit on error
ROOTDIR=$(cd -P -- "$(dirname -- "${BASH_SOURCE-$0}")" >/dev/null && pwd -P)

ASF_DOCKER_REPO="ghcr.io/apache/yetus"
YETUS_DOCKER_REPO=${YETUS_DOCKER_REPO:-apache/yetus}
CACHE_LIST=""

# shellcheck disable=SC2034
DOCKER_BUILDKIT=1
export DOCKER_BUILDKIT

# shellcheck disable=SC2034
DOCKER_CLI_EXPERIMENTAL=1
export DOCKER_CLI_EXPERIMENTAL

# moving to the path of the Dockerfile reduces the context
cd "${ROOTDIR}/precommit/src/main/shell/test-patch-docker"

printf "Using:\n\n\n"
docker version
printf "\n\n\n"

BRANCH=$(git branch | grep '\*' | cut -d ' ' -f2 )
if [[ "${BRANCH}" =~ HEAD ]]; then
  BRANCH=$(git branch | grep '\*' | awk '{print $NF}'  | sed -e s,rel/,,g -e s,\),,g )
fi
BRANCH=${BRANCH//\//_}

if [[ "${GITHUB_ACTIONS}" == true ]]; then
  echo "::group::start-build-env - warm docker cache"
fi

echo "Attempting a few pulls to save time"
echo "Errors here will be ignored!"

make_cache_list

if [[ "${GITHUB_ACTIONS}" == true ]]; then
  echo "::endgroup::"
  echo "::group::start-build-env - rebuild base"
fi

if [[ -n "${CACHE_LIST}" ]]; then
  set -x
  docker build \
  --cache-from="${CACHE_LIST}" \
    -t "${YETUS_DOCKER_REPO}-build:${BRANCH}" .
  set +x
else
  set -x
  docker build \
    -t "${YETUS_DOCKER_REPO}-build:${BRANCH}" .
  set +x
fi

USER_NAME=${SUDO_USER:=$USER}
USER_ID=$(id -u "${USER_NAME}")
GROUP_ID=$(id -g "${USER_NAME}")

# When using SELinux, mounted directories may not be accessible
# to the container. To work around this, with Docker prior to 1.7
# one needs to run the "chcon -Rt svirt_sandbox_file_t" command on
# the directories. With Docker 1.7 and later the z mount option
# does this automatically.
if command -v selinuxenabled >/dev/null && selinuxenabled; then
  DCKR_VER=$(docker -v|
  awk '$1 == "Docker" && $2 == "version" {split($3,ver,".");print ver[1]"."ver[2]}')
  DCKR_MAJ=${DCKR_VER%.*}
  DCKR_MIN=${DCKR_VER#*.}
  if [[ "${DCKR_MAJ}" -eq 1 ]] && [[ "${DCKR_MIN}" -ge 7 ]] ||
     [[ "${DCKR_MAJ}" -gt 1 ]]; then
    V_OPTS=:z
  else
    for d in "${PWD}" "${HOME}/.m2"; do
      ctx=$(stat --printf='%C' "$d"|cut -d':' -f3)
      if [ "$ctx" != svirt_sandbox_file_t ] && [ "$ctx" != container_file_t ]; then
        printf 'INFO: SELinux is enabled.\n'
        printf '\tMounted %s may not be accessible to the container.\n' "$d"
        printf 'INFO: If so, on the host, run the following command:\n'
        printf '\t# chcon -Rt svirt_sandbox_file_t %s\n' "$d"
      fi
    done
  fi
fi

if [[ "${GITHUB_ACTIONS}" == true ]]; then
  echo "::endgroup::"
  echo "::group::start-build-env - build asf-site-src container"
fi

cd "${ROOTDIR}/asf-site-src"
docker build \
  -t "${YETUS_DOCKER_REPO}-build-${USER_ID}:${BRANCH}" \
  --build-arg GROUP_ID="${GROUP_ID}" \
  --build-arg USER_ID="${USER_ID}" \
  --build-arg USER_NAME="${USER_NAME}" \
  --build-arg DOCKER_TAG="${BRANCH}" \
  --build-arg DOCKER_REPO="${YETUS_DOCKER_REPO}" \
  .

# now cd back
cd "${ROOTDIR}"
# By mapping the .m2 directory you can do an mvn install from
# within the container and use the result on your normal
# system.  And this also is a significant speedup in subsequent
# builds because the dependencies are downloaded only once.
# Additionally, we mount GPG and SSH directories so that
# release managers can use the container to do releases

dockerargs=(--rm=true)
dockerargs+=(-w "/home/${USER_NAME}/yetus")
dockerargs+=(-v "${PWD}:/home/${USER_NAME}/yetus${V_OPTS:-}")

# maven cache
if [[ ! -d  ${HOME}/.m2 ]]; then
  mkdir "${HOME}/.m2"
fi
dockerargs+=(-v "${HOME}/.m2:/home/${USER_NAME}/.m2${V_OPTS:-}")

# GPG Signing for dist creation
if [[ ! -d ${HOME}/.gnupg ]]; then
  mkdir "${HOME}/.gnupg"
fi
dockerargs+=(-v "${HOME}/.gnupg:/home/${USER_NAME}/.gnupg${V_OPTS:-}")

# git operations
if [[ ! -d ${HOME}/.ssh ]]; then
  mkdir "${HOME}/.ssh"
fi
dockerargs+=(-v "${HOME}/.ssh:/home/${USER_NAME}/.ssh${V_OPTS:-}")

dockerargs+=(-u "${USER_NAME}")

if tty -s; then
  dockerargs+=(-t)
fi

if [[ "${GITHUB_ACTIONS}" == true ]]; then
  echo "::endgroup::"
fi

set -x

docker run -i \
   "${dockerargs[@]}" \
  "${YETUS_DOCKER_REPO}-build-${USER_ID}:${BRANCH}" "$@"
