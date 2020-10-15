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

add_test_type checkmake

CHECKMAKE_TIMER=0

CHECKMAKE=${CHECKMAKE:-$(command -v checkmake 2>/dev/null)}

function checkmake_usage
{
  yetus_add_option "--checkmake=<file>" "path to checkmake executable"
  yetus_add_option "--checkmake-config=<file>" "relative path to checkmake config in source tree [default: none]"
}

function checkmake_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
      --checkmake=*)
        CHECKMAKE=${i#*=}
      ;;
      --checkmake-config=*)
        CHECKMAKE_CONFIG=${i#*=}
      ;;
    esac
  done
}

function checkmake_filefilter
{
  local filename=$1

  if [[ ${filename} =~ /Makefile$ ]] || [[ ${filename} =~ ^Makefile$ ]]; then
    add_test checkmake
  fi
}

function checkmake_precheck
{
  if ! verify_command checkmake "${CHECKMAKE}"; then
    add_vote_table_v2 0 checkmake "" "checkmake was not available."
    delete_test checkmake
  fi
}

function checkmake_exec
{
  declare i
  declare repostatus=$1
  declare basefn="${PATCH_DIR}/${repostatus}-checkmake-result"
  declare -a args

  echo "Running checkmake against identified Makefiles."
  pushd "${BASEDIR}" >/dev/null || return 1


  args=('--format={{.LineNumber}}:{{.Rule}}:{{.Violation}}')
  if [[ -f "${CHECKMAKE_CONFIG}" ]]; then
    args+=("--config=${CHECKMAKE_CONFIG}")
  fi

  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ /Makefile$ ]] || [[ ${i} =~ ^Makefile$ ]]; then
      if [[ -f ${i} ]]; then
        while read -r; do
           echo "${i}:${REPLY}" >> "${basefn}.tmp"
        done < <("${CHECKMAKE}" "${args[@]}" "${i}")
      fi
    fi
  done

  if [[ -f  "$${basefn}.tmp" ]]; then
    sort -k1,1 -k2,2n "${basefn}.tmp" \
      >  "${basefn}.text"
    rm  "${basefn}.tmp"
  fi

  popd >/dev/null || return 1
  return 0
}

function checkmake_preapply
{
  declare i
  declare -a args

  if ! verify_needed_test checkmake; then
    return 0
  fi

  big_console_header "checkmake plugin: ${PATCH_BRANCH}"

  start_clock

  checkmake_exec branch

  CHECKMAKE_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call error_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function checkmake_calcdiffs
{
  error_calcdiffs "$@"
}

function checkmake_postapply
{
  if ! verify_needed_test checkmake; then
    return 0
  fi

  big_console_header "checkmake plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${CHECKMAKE_TIMER}"

  checkmake_exec patch

  root_postlog_compare \
    checkmake \
    "${PATCH_DIR}/branch-checkmake-result.txt" \
    "${PATCH_DIR}/patch-checkmake-result.txt"
}

function checkmake_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    checkmake_preapply
  else
    checkmake_postapply
  fi
}
