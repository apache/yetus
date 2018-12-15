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

set -e               # exit on error
ROOTDIR=$(cd -P -- "$(dirname -- "${BASH_SOURCE-$0}")" >/dev/null && pwd -P)

# moving to the path of the Dockerfile reduces the context
cd "${ROOTDIR}/precommit/src/main/shell/test-patch-docker"

BRANCH=$(git branch | grep '\*' | cut -d ' ' -f2)
if [[ "${BRANCH}" =~ HEAD ]]; then
  BRANCH=$(git branch | grep '\*' | awk '{print $NF}'  | sed -e s,rel/,,g -e s,\),,g )
fi

echo "Attempting a pull of apache/yetus-base:${BRANCH} and apache/yetus-base:master to save time"
echo "Errors here will be ignored!"
docker pull "apache/yetus-base:${BRANCH}" || docker pull "apache/yetus-base:master" || true

docker build -t "apache/yetus-build:${BRANCH}" .

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

cd "${ROOTDIR}/asf-site-src"
docker build \
  -t "apache/yetus-build-${USER_ID}:${BRANCH}" \
  --build-arg GROUP_ID="${GROUP_ID}" \
  --build-arg USER_ID="${USER_ID}" \
  --build-arg USER_NAME="${USER_NAME}" \
  --build-arg DOCKER_TAG="${BRANCH}" \
  .

# now cd back
cd "${ROOTDIR}"
# By mapping the .m2 directory you can do an mvn install from
# within the container and use the result on your normal
# system.  And this also is a significant speedup in subsequent
# builds because the dependencies are downloaded only once.
# Additionally, we mount GPG and SSH directories so that
# release managers can use the container to do releases
docker run --rm=true -i -t \
  -v "${PWD}:/home/${USER_NAME}/yetus${V_OPTS:-}" \
  -w "/home/${USER_NAME}/yetus" \
  -v "${HOME}/.m2:/home/${USER_NAME}/.m2${V_OPTS:-}" \
  -v "${HOME}/.gnupg:/home/${USER_NAME}/.gnupg" \
  -v "${HOME}/.ssh:/home/${USER_NAME}/.ssh" \
  -u "${USER_NAME}" \
  "apache/yetus-build-${USER_ID}:${BRANCH}" "$@"
