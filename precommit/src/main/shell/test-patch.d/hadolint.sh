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

add_test_type hadolint

HADOLINT_TIMER=0
HADOLINT=${HADOLINT:-$(command -v hadolint 2>/dev/null)}

# files that are going to get hadolint'd
HADOLINT_CHECKFILES=()

function hadolint_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ Dockerfile ]]; then
    add_test hadolint
    yetus_add_array_element HADOLINT_CHECKFILES "${filename}"
  fi
}

function hadolint_precheck
{
  declare langs

  if ! verify_command "hadolint" "${HADOLINT}"; then
    add_vote_table 0 hadolint "hadolint was not available."
    delete_test hadolint
  fi

  if [[ -z "${LANG}" ]]; then
    langs=$(locale -a)
    if [[ ${langs}  =~ C.UTF-8 ]]; then
      yetus_error "WARNING: hadolint needs UTF-8 locale support. Forcing C.UTF-8."
      export LANG=C.UTF-8
      export LC_ALL=C.UTF-8
    elif [[ ${langs}  =~ en_US.UTF-8 ]]; then
      yetus_error "WARNING: hadolint needs UTF-8 locale support. Forcing en_US.UTF-8."
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
    else
      for i in ${langs}; do
        if [[ "${i}" =~ UTF-8 ]]; then
          yetus_error "WARNING: hadolint needs UTF-8 locale support. Forcing ${i}."
          export LANG="${i}"
          export LC_ALL="${i}"
          break
        fi
      done
    fi
  fi

  if [[ ! "${LANG}" =~ UTF-8 ]]; then
    yetus_error "WARNING: hadolint may fail without UTF-8 locale setting."
  fi
}

function hadolint_logic
{
  declare repostatus=$1
  declare i

  pushd "${BASEDIR}" >/dev/null || return 1

  for i in "${HADOLINT_CHECKFILES[@]}"; do
    if [[ -f "${i}" ]]; then
      echo " * ${i}"
      "${HADOLINT}" "${i}" >> "${PATCH_DIR}/${repostatus}-hadolint-result.txt"
    fi
  done
  popd > /dev/null || return 1
}

function hadolint_preapply
{
  if ! verify_needed_test hadolint; then
    return 0
  fi

  big_console_header "hadolint plugin: ${PATCH_BRANCH}"

  start_clock

  hadolint_logic branch

  # keep track of how much as elapsed for us already
  HADOLINT_TIMER=$(stop_clock)
  return 0
}

## filename:line\sCODE Text
function hadolint_calcdiffs
{
  declare branch=$1
  declare patch=$2
  declare tmp=${PATCH_DIR}/pl.$$.${RANDOM}
  declare j

  # first, pull out just the errors
  # shellcheck disable=SC2016
  ${AWK} -F: '{print $NF}' "${branch}" | cut -d' ' -f2- > "${tmp}.branch"

  # shellcheck disable=SC2016
  ${AWK} -F: '{print $NF}' "${patch}" | cut -d' ' -f2- > "${tmp}.patch"

  ${DIFF} --unchanged-line-format="" \
     --old-line-format="" \
     --new-line-format="%dn " \
     "${tmp}.branch" \
     "${tmp}.patch" > "${tmp}.lined"

  # now, pull out those lines of the raw output
  # shellcheck disable=SC2013
  for j in $(cat "${tmp}.lined"); do
    # shellcheck disable=SC2086
    head -${j} "${patch}" | tail -1
  done

  rm "${tmp}.branch" "${tmp}.patch" "${tmp}.lined" 2>/dev/null
}

function hadolint_postapply
{
  declare i
  declare numPrepatch
  declare numPostpatch
  declare diffPostpatch
  declare fixedpatch
  declare statstring

  if ! verify_needed_test hadolint; then
    return 0
  fi

  big_console_header "hadolint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${HADOLINT_TIMER}"

  hadolint_logic patch

  calcdiffs \
    "${PATCH_DIR}/branch-hadolint-result.txt" \
    "${PATCH_DIR}/patch-hadolint-result.txt" \
    hadolint \
      > "${PATCH_DIR}/diff-patch-hadolint.txt"

  # shellcheck disable=SC2016
  numPrepatch=$(wc -l "${PATCH_DIR}/branch-hadolint-result.txt" | ${AWK} '{print $1}')

  # shellcheck disable=SC2016
  numPostpatch=$(wc -l "${PATCH_DIR}/patch-hadolint-result.txt" | ${AWK} '{print $1}')

  # shellcheck disable=SC2016
  diffPostpatch=$(wc -l "${PATCH_DIR}/diff-patch-hadolint.txt" | ${AWK} '{print $1}')


  ((fixedpatch=numPrepatch-numPostpatch+diffPostpatch))

  statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

  if [[ ${diffPostpatch} -gt 0 ]] ; then
    add_vote_table -1 hadolint "${BUILDMODEMSG} ${statstring}"
    add_footer_table hadolint "@@BASE@@/diff-patch-hadolint.txt"
    bugsystem_linecomments "hadolint" "${PATCH_DIR}/diff-patch-hadolint.txt"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
    add_vote_table +1 hadolint "${BUILDMODEMSG} ${statstring}"
    return 0
  fi

  add_vote_table +1 hadolint "There were no new hadolint issues."
  return 0
}

function hadolint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    hadolint_preapply
  else
    hadolint_postapply
  fi
}
