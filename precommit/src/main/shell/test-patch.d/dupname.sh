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

# dupname check ALWAYS gets activated
add_test_type dupname
add_test dupname


## @description  Sort an array by its elements, ignoring case
## @audience     private
## @stability    evolving
## @replaceable  yes
## @param        arrayvar
function dupname_icase_sort_array
{
  declare arrname=$1
  declare arrref="${arrname}[@]"
  declare array=("${!arrref}")

  declare globstatus
  declare oifs
  declare -a sa

  globstatus=$(set -o | grep noglob | awk '{print $NF}')

  if [[ -n ${IFS} ]]; then
    oifs=${IFS}
  fi
  set -f
  # shellcheck disable=SC2034,SC2207
  IFS=$'\n' sa=($(sort -f <<<"${array[*]}"))
  # shellcheck disable=SC1083
  eval "${arrname}"=\(\"\${sa[@]}\"\)

  if [[ -n "${oifs}" ]]; then
    IFS=${oifs}
  else
    unset IFS
  fi

  if [[ "${globstatus}" = off ]]; then
    set +f
  fi
}

## @description  Check the current patchfile for case issues
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function dupname_precheck
{
  declare -i count=0
  declare cur
  declare fn
  declare prev
  declare -a tmpfiles

  tmpfiles=("${CHANGED_FILES[@]}")

  big_console_header "Checking for duplicated filenames that differ only in case"
  start_clock

  pushd "${BASEDIR}" >/dev/null || return 1

  # check the existing tree
  for fn in "${CHANGED_FILES[@]}"; do
    existing=$(${GIT} ls-files ":(icase)${fn}")
    if [[ -n "${existing}" ]]; then
      if [[ "${existing}" != "${fn}" ]]; then
        echo "${fn}:1:patch ${fn} matches existing ${existing}" >> "${PATCH_DIR}/results-dupnames.txt"
        ((count=count + 1))
      fi
    fi
  done

  popd >/dev/null || return 1

  if [[ "${BUILDMODE}" != full ]]; then

    dupname_icase_sort_array tmpfiles

    for cur in "${tmpfiles[@]}"; do
      if [[ -n ${prev} ]]; then
        if [[ "${cur}" != "${prev}" ]]; then
          curlc=$(echo "${cur}" | tr '[:upper:]' '[:lower:]')
          if [[ "${curlc}" == "${prevlc}" ]]; then
            echo "${cur}:1:matches ${prev} in same patch file" >> "${PATCH_DIR}/results-dupnames.txt"
            ((count=count + 1))
          fi
        fi
      fi
      prev=${cur}
      prevlc=${curlc}
    done
  fi

  if [[ ${count} -gt 0 ]]; then
    if [[ "${BUILDMODE}" != full ]]; then
      add_vote_table_v2 -1 dupname "@@BASE@@/results-dupnames.txt" \
        "The patch has ${count}" \
        " duplicated filenames that differ only in case."
      bugsystem_linecomments_queue dupname "${PATCH_DIR}/results-dupnames.txt"
      yetus_error "ERROR: Won't apply the patch; may break the workspace."
      return 1
    else
      add_vote_table_v2 -1 dupname "@@BASE@@/results-dupnames.txt" \
        "Source has ${count}" \
        " duplicated filenames that differ only in case."
      bugsystem_linecomments_queue dupname "${PATCH_DIR}/results-dupnames.txt"
    fi
  else
    add_vote_table_v2 +1 dupname "" "No case conflicting files found."
  fi

  return 0
}