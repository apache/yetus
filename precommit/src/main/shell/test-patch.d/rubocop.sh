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

add_test_type rubocop

RUBOCOP_TIMER=0

RUBOCOP=${RUBOCOP:-$(command -v rubocop 2>/dev/null)}

function rubocop_usage
{
  yetus_add_option "--rubocop=<file>" "path to rubocop executable"
  yetus_add_option "--rubocop-config=<file>" "relative path to rubocop config in source tree [default: none]"
}

function rubocop_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
    --rubocop=*)
      delete_parameter "${i}"
      RUBOCOP=${i#*=}
    ;;
    --rubocop-config=*)
      delete_parameter "${i}"
      RUBOCOP_CONFIG=${i#*=}
    ;;
    esac
  done
}

function rubocop_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.rb$ ]]; then
    add_test rubocop
  fi
}

function rubocop_precheck
{
  if ! verify_command rubocop "${RUBOCOP}"; then
    add_vote_table_v2 0 rubocop "" "rubocop was not available."
    delete_test rubocop
  fi
}


function rubocop_exec
{
  declare i
  declare repostatus=$1
  declare -a args

  args=('-f' 'e')

  echo "Running rubocop against identified ruby scripts."
  pushd "${BASEDIR}" >/dev/null || return 1

  if [[ -f "${RUBOCOP_CONFIG}" ]]; then
    args+=('-c' "${RUBOCOP_CONFIG}")
  fi

  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.rb$ && -f ${i} ]]; then
      "${RUBOCOP}" "${args[@]}" "${i}" | "${AWK}" '!/[0-9]* files? inspected/' >> "${PATCH_DIR}/${repostatus}-rubocop-result.txt"
    fi
  done
  popd >/dev/null || return 1
  return 0
}

function rubocop_preapply
{
  declare i
  declare -a args

  if ! verify_needed_test rubocop; then
    return 0
  fi

  big_console_header "rubocop plugin: ${PATCH_BRANCH}"

  start_clock

  rubocop_exec branch

  RUBOCOP_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call column_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function rubocop_calcdiffs
{
  column_calcdiffs "$@"
}

function rubocop_postapply
{
  if ! verify_needed_test rubocop; then
    return 0
  fi

  big_console_header "rubocop plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${RUBOCOP_TIMER}"

  rubocop_exec patch

  # shellcheck disable=SC2016
  RUBOCOP_VERSION=$("${RUBOCOP}" -v | "${AWK}" '{print $NF}')
  add_version_data rubocop "${RUBOCOP_VERSION}"

  root_postlog_compare \
    rubocop \
    "${PATCH_DIR}/branch-rubocop-result.txt" \
    "${PATCH_DIR}/patch-rubocop-result.txt"
}

function rubocop_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    rubocop_preapply
  else
    rubocop_postapply
  fi
}
