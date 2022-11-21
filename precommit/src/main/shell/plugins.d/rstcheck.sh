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

# SHELLDOC-IGNORE

add_test_type rstcheck

RSTCHECK_TIMER=0

RSTCHECK=${RSTCHECK:-$(command -v rstcheck 2>/dev/null)}

function rstcheck_usage
{
  yetus_add_option "--rstcheck=<file>" "path to rstcheck executable"
}

function rstcheck_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
      --rstcheck=*)
        RSTCHECK=${i#*=}
        delete_parameter "${i}"
      ;;
    esac
  done
}

function rstcheck_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.rst$ ]]; then
    add_test rstcheck
  fi
}

function rstcheck_precheck
{
  if ! verify_command rstcheck "${RSTCHECK}"; then
    add_vote_table_v2 0 rstcheck "" "rstcheck was not available."
    delete_test rstcheck
    return 0
  fi
}

function rstcheck_exec
{
  declare i
  declare repostatus=$1
  declare output="${PATCH_DIR}/${repostatus}-rstcheck-result.txt"

  pushd "${BASEDIR}" >/dev/null || return 1

  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.rst$ ]]; then
      if [[ -f ${i} ]]; then
        "${RSTCHECK}" "${i}" >> "${output}" 2>&1
      fi
    fi
  done

  popd >/dev/null || return 1
  return 0
}

function rstcheck_preapply
{
  declare i

  if ! verify_needed_test rstcheck; then
    return 0
  fi

  big_console_header "rstcheck plugin: ${PATCH_BRANCH}"

  start_clock

  rstcheck_exec branch

  RSTCHECK_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call error_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function rstcheck_calcdiffs
{
  error_calcdiffs "$@"
}

function rstcheck_postapply
{
  if ! verify_needed_test rstcheck; then
    return 0
  fi

  big_console_header "rstcheck plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${RSTCHECK_TIMER}"

  rstcheck_exec patch

  # shellcheck disable=SC2016
  RSTCHECK_VERSION=$("${RSTCHECK}" --version | "${AWK}" '{print $NF}')
  add_version_data rstcheck "${RSTCHECK_VERSION}"

  root_postlog_compare \
    rstcheck \
    "${PATCH_DIR}/branch-rstcheck-result.txt" \
    "${PATCH_DIR}/patch-rstcheck-result.txt"
}

function rstcheck_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    rstcheck_preapply
  else
    rstcheck_postapply
  fi
}
