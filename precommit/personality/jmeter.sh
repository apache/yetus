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

personality_plugins "all,-javadoc,-findbugs,-asflicense"

## @description  Globals specific to this personality
## @audience     private
## @stability    evolving
function personality_globals
{
  # shellcheck disable=SC2034
  PATCH_BRANCH_DEFAULT=trunk
  # shellcheck disable=SC2034
  BUILDTOOL=ant
  # shellcheck disable=SC2034
  GITHUB_REPO="apache/jmeter"
  # shellcheck disable=SC2034
  JMETER_DOWNLOAD_JARS=false
}

add_test_type jmeter

## @description  Personality usage options
## @audience     private
## @stability    evolving
function jmeter_usage
{
  yetus_add_option "--jmeter-download-jars=<bool>"  "download third-party jars needed by ant build"
}

## @description  Process personality options
## @audience     private
## @stability    evolving
## @param        arguments
function jmeter_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --jmeter-download-jars=*)
        JMETER_DOWNLOAD_JARS=${i#*=}
      ;;
    esac
  done
}

## @description  Download jmetere dependencies
## @audience     private
## @stability    evolving
function jmeter_precheck
{
  if [[ ${JMETER_DOWNLOAD_JARS} = true ]]; then
    pushd "${BASEDIR}" >/dev/null
    echo_and_redirect "${PATCH_DIR}/jmeter-branch-download-jars.txt" "${ANT}" download_jars
    popd >/dev/null
  fi
}
