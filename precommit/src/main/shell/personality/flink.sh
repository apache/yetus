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

personality_plugins "all"

## @description  Globals specific to this personality
## @audience     private
## @stability    evolving
function personality_globals
{
  # shellcheck disable=SC2034
  BUILDTOOL=maven
  #shellcheck disable=SC2034
  PATCH_BRANCH_DEFAULT=master
  #shellcheck disable=SC2034
  JIRA_ISSUE_RE='^FLINK-[0-9]+$'
  #shellcheck disable=SC2034
  GITHUB_REPO="apache/flink"
}

add_test_type flinklib

## @description  flinklib file filter
## @audience     private
## @stability    evolving
## @param        filename
function flinklib_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.java$
    || ${filename} =~ \.scala$
    || ${filename} =~ pom.xml$ ]]; then
    add_test flinklib
  fi
}

## @description  count files in the lib dir
## @audience     private
## @stability    evolving
function flinklib_count
{
  find "${BASEDIR}" \
    | ${GREP} "/lib/" \
    | ${GREP} -v "_qa_workdir" \
    | wc -l
}

## @description  check fliblib
## @audience     private
## @stability    evolving
## @param        repostatus
function flinklib_rebuild
{
  declare repostatus=$1

  start_clock
  big_console_header "${PATCH_BRANCH} flink library dependencies"

  if ! verify_needed_test flinklib; then
    echo "${BUILDMODEMSG} does not need flinklib testing."
    return 0
  fi

  pushd "${BASEDIR}" >/dev/null
  echo_and_redirect "${PATCH_DIR}/${repostatus}-flinklib-root.txt" \
     "${MAVEN}" "${MAVEN_ARGS[@]}" package -DskipTests -Dmaven.javadoc.skip=true -Ptest-patch
  if [[ $? != 0 ]]; then
     add_vote_table -1 flinklib "Unable to determine flink libs in ${PATCH_BRANCH}."
  fi

  if [[ ${repostatus} = branch ]]; then
    FLINK_PRE_LIB_FILES=$(flinklib_count)
    return 0
  else
    FLINK_POST_LIB_FILES=$(flinklib_count)
  fi
  popd >/dev/null

  if [[ "${BUILDMODE}" = full ]]; then
    if [[ ${FLINK_POST_LIB_FILES} -gt 0 ]]; then
      add_vote_table -1 flinklib "Lib folder dependencies are currently ${FLINK_POST_LIB_FILES}"
      return 1
    else
      add_vote_table +1 flinklib "No lib folder dependencies!"
      return 0
    fi
  fi

  if [[ "${FLINK_POST_LIB_FILES}" -gt "${FLINK_PRE_LIB_FILES}" ]]; then
    add_vote_table -1 flinklib "Patch increases lib folder dependencies from " \
      "${FLINK_PRE_LIB_FILES} to ${FLINK_POST_LIB_FILES}"
    return 1
  elif [[ "${FLINK_POST_LIB_FILES}" -eq "${FLINK_PRE_LIB_FILES}" ]]; then
    add_vote_table 0 flinklib "Patch did not change lib dependencies" \
      " (still ${FLINK_PRE_LIB_FILES})"
  else
    add_vote_table +1 flinklib "Patch decreases lib folder dependencies by " \
      "$((FLINK_PRE_LIB_FILES-FLINK_POST_LIB_FILES))."
  fi
  return 0
}
