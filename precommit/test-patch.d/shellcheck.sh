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

add_test_type shellcheck

SHELLCHECK_TIMER=0

SHELLCHECK=${SHELLCHECK:-$(which shellcheck 2>/dev/null)}

SHELLCHECK_SPECIFICFILES=""

# if it ends in an explicit .sh, then this is shell code.
# if it doesn't have an extension, we assume it is shell code too
function shellcheck_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.sh$ ]]; then
    add_test shellcheck
    SHELLCHECK_SPECIFICFILES="${SHELLCHECK_SPECIFICFILES} ./${filename}"
  fi

  if [[ ! ${filename} =~ \. ]]; then
    add_test shellcheck
  fi
}

function shellcheck_precheck
{
  declare langs

  if ! verify_command "shellcheck" "${SHELLCHECK}"; then
    add_vote_table 0 shellcheck "Shellcheck was not available."
    delete_test shellcheck
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

function shellcheck_private_findbash
{
  local i
  local value
  local list

  while read -r line; do
    value=$(find "${line}" ! -name '*.cmd' -type f \
      | ${GREP} -E -v '(.orig$|.rej$)')

    for i in ${value}; do
      if [[ ! ${i} =~ \.sh(\.|$)
          && ! $(head -n 1 "${i}") =~ ^#! ]]; then
        yetus_debug "Shellcheck skipped: ${i}"
        continue
      fi
      list="${list} ${i}"
    done
  done < <(find . -type d -name bin -o -type d -name sbin -o -type d -name scripts -o -type d -name libexec -o -type d -name shellprofile.d)
  # shellcheck disable=SC2086
  echo ${list} ${SHELLCHECK_SPECIFICFILES} | tr ' ' '\n' | sort -u
}

function shellcheck_preapply
{
  declare i
  declare msg

  if ! verify_needed_test shellcheck; then
    return 0
  fi

  big_console_header "shellcheck plugin: ${PATCH_BRANCH}"

  start_clock

  echo "Running shellcheck against all identifiable shell scripts"
  pushd "${BASEDIR}" >/dev/null
  for i in $(shellcheck_private_findbash); do
    if [[ -f ${i} ]]; then
      ${SHELLCHECK} -f gcc "${i}" >> "${PATCH_DIR}/branch-shellcheck-result.txt"
    fi
  done
  popd > /dev/null

  # shellcheck disable=SC2016
  SHELLCHECK_VERSION=$(${SHELLCHECK} --version | ${GREP} version: | ${AWK} '{print $NF}')
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

  echo "Running shellcheck against all identifiable shell scripts"
  # we re-check this in case one has been added
  for i in $(shellcheck_private_findbash); do
    if [[ -f ${i} ]]; then
      ${SHELLCHECK} -f gcc "${i}" >> "${PATCH_DIR}/patch-shellcheck-result.txt"
    fi
  done

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
