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

add_test_type pathlen

PATHLEN_SIZE=240

## @description  pathlen usage hook
## @audience     private
## @stability    evolving
## @replaceable  no
function pathlen_usage
{
  yetus_add_option "--pathlen-size=<int>" "reject patches with this size of paths (default: ${PATHLEN_SIZE}"

}

## @description  pathlen parse args hook
## @audience     private
## @stability    evolving
## @replaceable  no
function pathlen_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --pathlen-size=*)
        delete_parameter "${i}"
        PATHLEN_SIZE="${i#*=}"
      ;;
    esac
  done
}

## @description  helper function to count long pathnames
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function pathlen_generic
{
  declare size
  declare i
  declare msg
  declare counter

  counter=0

  if [[ "${BUILDMODE}" = full ]]; then
    msg="source tree"
  else
    msg="patch"
  fi

  for i in "${CHANGED_FILES[@]}"; do
    size=${#i}
    if [[ ${size} -gt ${PATHLEN_SIZE} ]]; then
      ((counter = counter + 1 ))
      echo "${i}:1:path size ${counter}" >>  "${PATCH_DIR}/results-pathlen.txt"
    fi
  done

  # shellcheck disable=SC2016
  echo "${counter} files in the ${msg} with paths longer that ${PATHLEN_SIZE}."
  if [[ ${counter} -gt 0 ]] ; then
    add_vote_table_v2 -1 pathlen \
      "@@BASE@@/results-pathlen.txt" \
      "${BUILDMODEMSG} appears to contain ${counter} files with names longer than ${PATHLEN_SIZE}"
    bugsystem_linecomments_queue pathlen "${PATCH_DIR}/results-pathlen.txt"
    return 1
  fi
  return 0
}

## @description  Check the current patchfile for @pathlen tags
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
## @param        patchfile
function pathlen_patchfile
{
  if [[ "${BUILDMODE}" != patch ]]; then
    return
  fi

  big_console_header "Checking for long paths: ${BUILDMODE}"

  start_clock

  pathlen_generic
}


## @description  Check the current directory for @pathlen tags
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function pathlen_postcompile
{
  if [[ "${BUILDMODE}" != full ]]; then
    return
  fi

  big_console_header "Checking for long paths: ${BUILDMODE}"

  start_clock

  pathlen_generic
}
