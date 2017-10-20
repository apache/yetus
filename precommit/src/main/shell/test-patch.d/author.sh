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
  authortags=$(wc -l "${PATCH_DIR}/author-tags.txt" | "${AWK}" '{print $1}')
  echo "There appear to be ${authortags} @author tags in the ${msg}."
  if [[ ${authortags} != 0 ]] ; then
    add_vote_table -1 @author \
      "${BUILDMODEMSG} appears to contain ${authortags} @author tags which the" \
      " community has agreed to not allow in code contributions."
    add_footer_table @author "@@BASE@@/author-tags.txt"
    return 1
  fi
  add_vote_table +1 @author "${BUILDMODEMSG} does not contain any @author tags."
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
      add_vote_table 0 @author "Skipping @author checks as ${appname} has been patched."
      return 0
    fi
  done

  ${GREP} -i -n '^[^-].*@author' "${patchfile}" >> "${PATCH_DIR}/author-tags.txt"
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
  declare fn

  if [[ "${BUILDMODE}" != full ]]; then
    return
  fi

  big_console_header "Checking for @author tags: ${BUILDMODE}"

  start_clock

  "${GIT}" grep -n -I --extended-regexp -i -e '^[^-].*@author' \
    | ${GREP} -v "${appname}" \
    >> "${PATCH_DIR}/author-tags-git.txt"

  if [[ -z "${AUTHOR_IGNORE_LIST[0]}" ]]; then
    cp -p "${PATCH_DIR}/author-tags-git.txt" "${PATCH_DIR}/author-tags.txt"
  else
    cp -p "${PATCH_DIR}/author-tags-git.txt" "${PATCH_DIR}/author-tags.1"
    for fn in "${AUTHOR_IGNORE_LIST[@]}"; do
      ${GREP} -v -E "^${fn}" "${PATCH_DIR}/author-tags.1" >> "${PATCH_DIR}/author-tags.2"
      mv "${PATCH_DIR}/author-tags.2" "${PATCH_DIR}/author-tags.1"
    done
    mv "${PATCH_DIR}/author-tags.1" "${PATCH_DIR}/author-tags.txt"
  fi

  author_generic
}
