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

add_test_type shellcheck

SHELLCHECK_TIMER=0
SHELLCHECK_X=true

SHELLCHECK=${SHELLCHECK:-$(which shellcheck 2>/dev/null)}

# files that are going to get shellcheck'd
SHELLCHECK_CHECKFILES=()

# files that are going to get shellcheck'd
SHELLCHECK_FILTERFILES=()


# if it ends in an explicit .sh, then this is shell code.
# if it doesn't have an extension, then assume it is and
# we'll deal with it later
function shellcheck_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.sh$ ]]; then
    add_test shellcheck
    yetus_add_array_element SHELLCHECK_FILTERFILES "${filename}"
  fi

  if [[ ! ${filename} =~ \. ]]; then
    add_test shellcheck
    yetus_add_array_element SHELLCHECK_FILTERFILES "${filename}"
  fi
}

function shellcheck_precheck
{
  declare langs

  if ! verify_command "shellcheck" "${SHELLCHECK}"; then
    add_vote_table 0 shellcheck "Shellcheck was not available."
    delete_test shellcheck
  else
    # shellcheck disable=SC2016
    SHELLCHECK_VERSION=$("${SHELLCHECK}" --version | "${GREP}" version: | "${AWK}" '{print $NF}')

    # versions less than 0.4.1 do not support -x
    if [[ ${SHELLCHECK_VERSION} =~ 0.[0-3].[0-9] || ${SHELLCHECK_VERSION} = 0.4.0 ]]; then
      SHELLCHECK_X=false
    fi
  fi

  if [[ -z "${LANG}" ]]; then
    langs=$(locale -a)
    if [[ ${langs}  =~ C.UTF-8 ]]; then
      yetus_error "WARNING: shellcheck needs UTF-8 locale support. Forcing C.UTF-8."
      export LANG=C.UTF-8
      export LC_ALL=C.UTF-8
    elif [[ ${langs}  =~ en_US.UTF-8 ]]; then
      yetus_error "WARNING: shellcheck needs UTF-8 locale support. Forcing en_US.UTF-8."
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
    else
      for i in ${langs}; do
        if [[ "${i}" =~ UTF-8 ]]; then
          yetus_error "WARNING: shellcheck needs UTF-8 locale support. Forcing ${i}."
          export LANG="${i}"
          export LC_ALL="${i}"
          break
        fi
      done
    fi
  fi

  if [[ ! "${LANG}" =~ UTF-8 ]]; then
    yetus_error "WARNING: shellcheck may fail without UTF-8 locale setting."
  fi
}

function shellcheck_criteria
{
  declare fn=$1
  declare text

  if [[ ! -f "${fn}" ]]; then
    yetus_debug "Shellcheck rejected (not exist): ${fn}"
    return
  fi

  text=$(head -n 1 "${fn}")

  # shell check requires either a bangpath or a shell check directive
  # on the first line.  so check for a leading comment char
  # and some sort of reference to 'sh'
  if echo "${text}" | "${GREP}" -E -q "^#"; then
    if echo "${text}" | "${GREP}" -q sh; then
      yetus_add_array_element SHELLCHECK_CHECKFILES "${fn}"
      yetus_debug "Shellcheck added: ${fn}"
    fi
  fi
}

function shellcheck_findscripts
{
  declare fn

  # reset
  SHELLCHECK_CHECKFILES=()

  # run through the files our filter caught
  # this will set SHELLCHECK_CHECKFILES elements
  for fn in "${SHELLCHECK_FILTERFILES[@]}"; do
    shellcheck_criteria "${fn}"
  done

  # finally, sort the array
  yetus_sort_array SHELLCHECK_CHECKFILES
}

function shellcheck_logic
{
  declare repostatus=$1
  declare i

  echo "Running shellcheck against all suspected shell scripts"
  pushd "${BASEDIR}" >/dev/null

  # need to run this every time in case patch
  # add/removed files
  shellcheck_findscripts

  for i in "${SHELLCHECK_CHECKFILES[@]}"; do
    if [[ "${SHELLCHECK_X}" = true ]]; then
      "${SHELLCHECK}" -x -f gcc "${i}" >> "${PATCH_DIR}/${repostatus}-shellcheck-result.txt"
    else
      "${SHELLCHECK}" -f gcc "${i}" >> "${PATCH_DIR}/${repostatus}-shellcheck-result.txt"
    fi
  done
  popd > /dev/null
}

function shellcheck_preapply
{
  declare msg

  if ! verify_needed_test shellcheck; then
    return 0
  fi

  big_console_header "shellcheck plugin: ${PATCH_BRANCH}"

  start_clock

  shellcheck_logic branch

  msg="v${SHELLCHECK_VERSION}"
  if [[ ${SHELLCHECK_VERSION} =~ 0.[0-3].[0-5] ]]; then
    msg="${msg} (This is an old version that has serious bugs. Consider upgrading.)"
  fi
  add_footer_table shellcheck "${msg}"

  # keep track of how much as elapsed for us already
  SHELLCHECK_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call column_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function shellcheck_calcdiffs
{
  column_calcdiffs "$@"
}

function shellcheck_postapply
{
  declare i
  declare numPrepatch
  declare numPostpatch
  declare diffPostpatch
  declare fixedpatch
  declare statstring

  if ! verify_needed_test shellcheck; then
    return 0
  fi

  big_console_header "shellcheck plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${SHELLCHECK_TIMER}"

  shellcheck_logic patch

  calcdiffs \
    "${PATCH_DIR}/branch-shellcheck-result.txt" \
    "${PATCH_DIR}/patch-shellcheck-result.txt" \
    shellcheck \
      > "${PATCH_DIR}/diff-patch-shellcheck.txt"

  # shellcheck disable=SC2016
  numPrepatch=$(wc -l "${PATCH_DIR}/branch-shellcheck-result.txt" | ${AWK} '{print $1}')

  # shellcheck disable=SC2016
  numPostpatch=$(wc -l "${PATCH_DIR}/patch-shellcheck-result.txt" | ${AWK} '{print $1}')

  # shellcheck disable=SC2016
  diffPostpatch=$(wc -l "${PATCH_DIR}/diff-patch-shellcheck.txt" | ${AWK} '{print $1}')


  ((fixedpatch=numPrepatch-numPostpatch+diffPostpatch))

  statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

  if [[ ${diffPostpatch} -gt 0 ]] ; then
    add_vote_table -1 shellcheck "${BUILDMODEMSG} ${statstring}"
    add_footer_table shellcheck "@@BASE@@/diff-patch-shellcheck.txt"
    bugsystem_linecomments "shellcheck" "${PATCH_DIR}/diff-patch-shellcheck.txt"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
    add_vote_table +1 shellcheck "${BUILDMODEMSG} ${statstring}"
    return 0
  fi

  add_vote_table +1 shellcheck "There were no new shellcheck issues."
  return 0
}

function shellcheck_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    shellcheck_preapply
  else
    shellcheck_postapply
  fi
}
