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

OVERWRITEARGS=("--reexec")
OVERWRITEARGS=("${OVERWRITEARGS[@]}" "--dockermode")
OVERWRITEARGS=("${OVERWRITEARGS[@]}" "--basedir=${BASEDIR}")

cd "${BASEDIR}" || exit 1

if [[ -n ${JAVA_HOME}
  && ! -d ${JAVA_HOME} ]]; then
  echo "JAVA_HOME: ${JAVA_HOME} does not exist. Dockermode: attempting to switch to another." 1>&2
  JAVA_HOME=""
fi

if [[ -z ${JAVA_HOME} ]]; then
  JAVA_HOME=$(find /usr/lib/jvm/ -name "java-*" -type d | tail -1)
  export JAVA_HOME
  if [[ -n "${JAVA_HOME}" ]]; then
    OVERWRITEARGS=("${OVERWRITEARGS[@]}" "--java-home=${JAVA_HOME}")
    echo "Setting ${JAVA_HOME} as the JAVA_HOME."
  fi
fi

# Avoid out of memory errors in builds
MAVEN_OPTS=${MAVEN_OPTS:-"-Xms256m -Xmx1g"}
export MAVEN_OPTS

# strip out --docker param to prevent re-exec again
TESTPATCHMODE=${TESTPATCHMODE/--docker }
TESTPATCHMODE=${TESTPATCHMODE%--docker}

PATCH_DIR=$(cd -P -- "${PATCH_DIR}" >/dev/null && pwd -P)
OVERWRITEARGS=("${OVERWRITEARGS[@]}" "--patch-dir=${PATCH_DIR}")
OVERWRITEARGS=("${OVERWRITEARGS[@]}" "--user-plugins=${PATCH_DIR}/precommit/user-plugins")

# if patch system is generic, then it's either a local
# patch file or was in some other way not pulled from a bug
# system.  So we need to rescue it and then tell
# test-patch where to find it.
if [[ "${PATCH_SYSTEM}" = generic ]]; then
  cp -p "${PATCH_DIR}/patch" /testptch/extras/patch
  OVERWRITEARGS=("${OVERWRITEARGS[@]}" "/testptch/extras/patch")
fi

if [[ -f /testptch/console.txt ]]; then
  OVERWRITEARGS=("${OVERWRITEARGS[@]}" "--console-report-file=/testptch/console.txt")
fi

cd "${PATCH_DIR}/precommit/" || exit 1
#shellcheck disable=SC2086
"${PATCH_DIR}/precommit/test-patch.sh" \
   ${TESTPATCHMODE} \
  "${OVERWRITEARGS[@]}"
