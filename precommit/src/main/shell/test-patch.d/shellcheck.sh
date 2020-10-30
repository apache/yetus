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

SHELLCHECK=${SHELLCHECK:-$(command -v shellcheck 2>/dev/null)}

# files that are going to get shellcheck'd
SHELLCHECK_CHECKFILES=()

# files that are going to get shellcheck'd
SHELLCHECK_FILTERFILES=()


function shellcheck_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.sh$ ]]; then
    # if it ends in an explicit .sh, then this is shell code.
    add_test shellcheck
    yetus_add_array_element SHELLCHECK_FILTERFILES "${filename}"
  elif [[ ${filename} =~ \.bats$ ]]; then
    # if it ends in an explicit .bats, then this is bats code
    # which modern shellcheck can work with.
    add_test shellcheck
  elif [[ ${BUILDTOOL} = maven && ${filename} =~ src/main/shell ]]; then
    # if it is maven and in src/main/shell, assume it's shell code
    add_test shellcheck
    yetus_add_array_element SHELLCHECK_FILTERFILES "${filename}"
  elif [[ ! ${filename} =~ \. ]]; then
    # if it doesn't have an extension then assume it is
    # and the plugin will sort it out
    add_test shellcheck
    yetus_add_array_element SHELLCHECK_FILTERFILES "${filename}"
  fi
}

function shellcheck_precheck
{
  declare langs

  if ! verify_command "shellcheck" "${SHELLCHECK}"; then
    add_vote_table_v2 0 shellcheck "" "Shellcheck was not available."
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
  declare excludepath

  if [[ ! -f "${fn}" ]]; then
    yetus_debug "Shellcheck rejected (not exist): ${fn}"
    return
  fi

  # EXLUDE_PATHS should already be initialized by now, since
  # we're in _precheck by the time this gets called

  for excludepath in "${EXCLUDE_PATHS[@]}"; do
    if [[  "${fn}" =~ ${excludepath} ]]; then
      return
    fi
  done

  text=$(head -n 1 "${fn}")

  # shell check requires either a bangpath or a shellcheck directive
  # on the first line.
  if [[ "${text}" =~ ^\#! ]] && [[ "${text}" =~ sh ]]; then
    yetus_add_array_element SHELLCHECK_CHECKFILES "${fn}"
    yetus_debug "Shellcheck added: ${fn}"
  elif [[ "${text}" =~ shellcheck ]]; then
    yetus_add_array_element SHELLCHECK_CHECKFILES "${fn}"
    yetus_debug "Shellcheck added: ${fn}"
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
  pushd "${BASEDIR}" >/dev/null || return 1

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
  popd > /dev/null || return 1
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

  if [[ ${SHELLCHECK_VERSION} =~ 0.[0-3].[0-5] ]]; then
    msg="v${SHELLCHECK_VERSION} is an old version that has serious bugs. Consider upgrading."
    add_footer_table shellcheck "${msg}"
  fi
  add_version_data shellcheck "${SHELLCHECK_VERSION}"

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

  if ! verify_needed_test shellcheck; then
    return 0
  fi

  big_console_header "shellcheck plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${SHELLCHECK_TIMER}"

  shellcheck_logic patch

  root_postlog_compare \
    shellcheck \
    "${PATCH_DIR}/branch-shellcheck-result.txt" \
    "${PATCH_DIR}/patch-shellcheck-result.txt"
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
