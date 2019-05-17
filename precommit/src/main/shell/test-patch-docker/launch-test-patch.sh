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

declare -a OVERWRITEARGS

# yetuslib is meant to be completely standalone.  This means
# adding it as a common function library here is a-ok

#shellcheck disable=SC1090
source "${PATCH_DIR}/precommit/core.d/00-yetuslib.sh"

if ! yetus_file_to_array OVERWRITEARGS "${DOCKER_WORK_DIR}/user_params.txt"; then
  yetus_error "ERROR: Cannot read user parameters file. Exiting."
  exit 1
fi

# do not want this archived
rm -f "${DOCKER_WORK_DIR}/user_params.txt"

OVERWRITEARGS+=("--reexec")
OVERWRITEARGS+=("--dockermode")
OVERWRITEARGS+=("--basedir=${BASEDIR}")

cd "${BASEDIR}" || exit 1

if [[ -n ${JAVA_HOME} && ! -d ${JAVA_HOME} ]]; then
  yetus_error "WARNING: JAVA_HOME=${JAVA_HOME} does not exist. Dockermode: attempting to switch to another." 1>&2
  JAVA_HOME=""
fi

if [[ -z ${JAVA_HOME} ]]; then
  JAVA_HOME=$(find /usr/lib/jvm/ -name "java-*" -type d | tail -1)
  export JAVA_HOME
  if [[ -n "${JAVA_HOME}" ]]; then
    OVERWRITEARGS+=("--java-home=${JAVA_HOME}")
    yetus_error "WARNING: Setting ${JAVA_HOME} as the JAVA_HOME."
  fi
fi

PATCH_DIR=$(yetus_abs "${PATCH_DIR}")
OVERWRITEARGS+=("--patch-dir=${PATCH_DIR}")
OVERWRITEARGS+=("--user-plugins=${PATCH_DIR}/precommit/user-plugins")

if [[ -f "${PATCH_DIR}/precommit/unit_test_filter_file.txt" ]]; then
  OVERWRITEARGS+=("--unit-test-filter-file=${PATCH_DIR}/precommit/unit_test_filter_file.txt")
fi

# if patch system is generic, then it's either a local
# patch file or was in some other way not pulled from a bug
# system.  So we need to rescue it and then tell
# test-patch where to find it.
if [[ "${PATCH_SYSTEM}" = generic ]]; then
  cp -p "${PATCH_DIR}/input.patch" "${DOCKER_WORK_DIR}/extras/patch"
  OVERWRITEARGS+=("${DOCKER_WORK_DIR}/extras/patch")
fi

cd "${PATCH_DIR}/precommit/" || exit 1

if [[ "${YETUS_DOCKER_BASH_DEBUG}" == true ]]; then
  exec bash -x "${PATCH_DIR}/precommit/test-patch.sh" "${OVERWRITEARGS[@]}"
else
  exec "${PATCH_DIR}/precommit/test-patch.sh" "${OVERWRITEARGS[@]}"
fi