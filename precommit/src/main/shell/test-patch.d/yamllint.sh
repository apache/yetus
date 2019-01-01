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

# no public APIs here
# SHELLDOC-IGNORE

add_test_type yamllint

YAMLLINT_TIMER=0
YAMLLINT=${YAMLLINT:-$(command -v yamllint 2>/dev/null)}

# files that are going to get yamllint'd
YAMLLINT_CHECKFILES=()

function yamllint_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.yaml$ ]] ||
     [[ ${filename} =~ \.yml$ ]]; then
    add_test yamllint
    yetus_add_array_element YAMLLINT_CHECKFILES "${filename}"
  fi
}

function yamllint_precheck
{
  if ! verify_command "yamllint" "${YAMLLINT}"; then
    add_vote_table 0 yamllint "yamllint was not available."
    delete_test yamllint
  fi


}

function yamllint_logic
{
  declare repostatus=$1
  declare i
  declare fn
  declare output

  pushd "${BASEDIR}" >/dev/null || return 1

  for i in "${YAMLLINT_CHECKFILES[@]}"; do
    if [[ -f "${i}" ]]; then
      fn=""
      while read -r; do
        if [[ -z "${fn}" ]]; then
          fn=$REPLY
        elif [[ -n "${REPLY}" ]]; then
          # (space)line:col(space)error/warning(space)text
          output=$(echo "${REPLY}" | awk '{$1=$1":"; $2=$2":"; print $0;}')
          # fn:line:col:(space)error/warning:(space)text
          echo "${fn}:${output}" >> "${PATCH_DIR}/${repostatus}-yamllint-result.txt"
        fi
      done < <("${YAMLLINT}" "${i}")
    fi
  done
  popd > /dev/null || return 1
}

function yamllint_preapply
{
  if ! verify_needed_test yamllint; then
    return 0
  fi

  big_console_header "yamllint plugin: ${PATCH_BRANCH}"

  start_clock

  yamllint_logic branch

  # keep track of how much as elapsed for us already
  YAMLLINT_TIMER=$(stop_clock)
  return 0
}

function yamllint_calcdiffs
{
  column_calcdiffs "$@"
}

function yamllint_postapply
{
  declare i
  declare numPrepatch
  declare numPostpatch
  declare diffPostpatch
  declare fixedpatch
  declare statstring

  if ! verify_needed_test yamllint; then
    return 0
  fi

  big_console_header "yamllint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${YAMLLINT_TIMER}"

  yamllint_logic patch

  calcdiffs \
    "${PATCH_DIR}/branch-yamllint-result.txt" \
    "${PATCH_DIR}/patch-yamllint-result.txt" \
    yamllint \
      > "${PATCH_DIR}/diff-patch-yamllint.txt"

  # shellcheck disable=SC2016
  numPrepatch=$(wc -l "${PATCH_DIR}/branch-yamllint-result.txt" | "${AWK}" '{print $1}')

  # shellcheck disable=SC2016
  numPostpatch=$(wc -l "${PATCH_DIR}/patch-yamllint-result.txt" | "${AWK}" '{print $1}')

  # shellcheck disable=SC2016
  diffPostpatch=$(wc -l "${PATCH_DIR}/diff-patch-yamllint.txt" | "${AWK}" '{print $1}')


  ((fixedpatch=numPrepatch-numPostpatch+diffPostpatch))

  statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

  if [[ ${diffPostpatch} -gt 0 ]] ; then
    add_vote_table -1 yamllint "${BUILDMODEMSG} ${statstring}"
    add_footer_table yamllint "@@BASE@@/diff-patch-yamllint.txt"
    bugsystem_linecomments_queue "yamllint" "${PATCH_DIR}/diff-patch-yamllint.txt"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
    add_vote_table +1 yamllint "${BUILDMODEMSG} ${statstring}"
    return 0
  fi

  add_vote_table +1 yamllint "There were no new yamllint issues."
  return 0
}

function yamllint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    yamllint_preapply
  else
    yamllint_postapply
  fi
}
