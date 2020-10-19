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

add_test_type author

AUTHOR_LOGNAME="results-author.txt"

## @description  author usage hook
## @audience     private
## @stability    evolving
## @replaceable  no
function author_usage
{
  yetus_add_option "--author-ignore-list=<list>" "list of filenames to ignore (full build mode only)"
}

## @description  author parse args hook
## @audience     private
## @stability    evolving
## @replaceable  no
function author_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --author-ignore-list=*)
        delete_parameter "${i}"
        yetus_comma_to_array AUTHOR_IGNORE_LIST "${i#*=}"
      ;;
    esac
  done
}

## @description  helper function for @author tags check
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function author_generic
{
  declare authortags
  declare i
  declare msg

  if [[ "${BUILDMODE}" = full ]]; then
    msg="source tree"
  else
    msg="patch"
  fi

  # shellcheck disable=SC2016
  authortags=$(wc -l "${PATCH_DIR}/${AUTHOR_LOGNAME}" | "${AWK}" '{print $1}')
  echo "There appear to be ${authortags} @author tags in the ${msg}."
  if [[ ${authortags} != 0 ]] ; then
    add_vote_table_v2 -1 @author \
      "@@BASE@@/${AUTHOR_LOGNAME}" \
      "${BUILDMODEMSG} appears to contain ${authortags} @author tags which the" \
      " community has agreed to not allow in code contributions."
    bugsystem_linecomments_queue author "${PATCH_DIR}/${AUTHOR_LOGNAME}"
    return 1
  fi
  add_vote_table_v2 +1 @author "" "${BUILDMODEMSG} does not contain any @author tags."
  return 0
}

## @description  Check the current patchfile for @author tags
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
## @param        patchfile
function author_patchfile
{
  declare patchfile=$1
  # shellcheck disable=SC2155
  declare -r appname=$(basename "${BASH_SOURCE-$0}")
  declare i

  if [[ "${BUILDMODE}" != patch ]]; then
    return
  fi

  big_console_header "Checking for @author tags: ${BUILDMODE}"

  start_clock

  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ ${appname} ]]; then
      echo "Skipping @author checks as ${appname} has been patched."
      add_vote_table_v2 0 @author "" "Skipping @author checks as ${appname} has been patched."
      return 0
    fi
  done

  "${GREP}" -i -n '^[^-].*@author' "${patchfile}" >> "${PATCH_DIR}/${AUTHOR_LOGNAME}"
  author_generic
}


## @description  Check the current directory for @author tags
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function author_postcompile
{
  # shellcheck disable=SC2155
  declare -r appname=$(basename "${BASH_SOURCE-$0}")
  declare -a globalignore

  if [[ "${BUILDMODE}" != full ]]; then
    return
  fi

  big_console_header "Checking for @author tags: ${BUILDMODE}"

  start_clock

  if [[ -n "${EXCLUDE_PATHS_FILE}" ]] && [[ -f "${EXCLUDE_PATHS_FILE}" ]]; then
    globalignore=("${GREP}" "-v" "-E" "-f" "${EXCLUDE_PATHS_FILE}")
  else
    globalignore=("cat")
  fi

  "${GIT}" grep -n -I --extended-regexp -i -e '^[^-].*@author' \
    | "${GREP}" -v "${appname}" \
    | "${globalignore[@]}" \
    >> "${PATCH_DIR}/author-tags-git.txt"

  if [[ -z "${AUTHOR_IGNORE_LIST[0]}" ]]; then
    cp -p "${PATCH_DIR}/author-tags-git.txt" "${PATCH_DIR}/${AUTHOR_LOGNAME}"
  else
    printf "^%s\n" "${AUTHOR_IGNORE_LIST[@]}" > "${PATCH_DIR}/author-tags-filter.txt"
    "${GREP}" -v -E \
      -f "${PATCH_DIR}/author-tags-filter.txt" \
      "${PATCH_DIR}/author-tags-git.txt" \
      > "${PATCH_DIR}/${AUTHOR_LOGNAME}"
  fi

  author_generic
}
