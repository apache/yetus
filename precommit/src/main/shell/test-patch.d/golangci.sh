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

add_test_type golangcilint

GOLANGCI_TIMER=0
GOLANGCI_LINT=$(command -v golangci-lint 2>/dev/null)

## @description  Usage info for slack plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function golangcilint_usage
{
  yetus_add_option "--golangcilint=<file>" "Location of the go binary (default: \"${GOLANGCI_LINT:-not found}\")"
  yetus_add_option "--golangcilint-config=<file>" "Location of the config file"
}

## @description  Option parsing for slack plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function golangcilint_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --golangcilint=*)
        GOLANGCI_LINT=${i#*=}
        delete_parameter "${i}"
      ;;
      --golangcilint-config=*)
        GOLANGCI_CONFIG=${i#*=}
        delete_parameter "${i}"
      ;;
    esac
  done
}

function golangcilint_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.go$ ]]; then
    add_test golangcilint
  fi
}

function golangcilint_precheck
{
  if [[ -z "${GOLANGCI_LINT}" ]]; then
    add_vote_table_v2 0 golangcilint "" "golangci-lint was not found."
    delete_test golangcilint
  fi
}

function golangcilint_exec
{
  declare i
  declare repostatus=$1
  declare -a args
  declare -a gargs

  if [[ -f "${EXCLUDE_PATHS_FILE}" ]]; then
    gargs=("${GREP}" "-v" "-E" "-f" "${EXCLUDE_PATHS_FILE}")
  else
    gargs=("cat")
  fi

  args+=("--max-issues-per-linter=0")
  args+=("--max-same-issues=0")
  args+=("--out-format=line-number")
  args+=("--print-issued-lines=false")
  args+=("--color=never")

  if [[ -f "${GOLANGCI_CONFIG}" ]]; then
    args+=("--config" "${GOLANGCI_CONFIG}")
  fi

  golang_gomod_find

  for d in "${GOMOD_DIRS[@]}"; do
    pushd "${d}" >/dev/null || return 1
    while read -r; do
      p=$(yetus_relative_dir "${BASEDIR}" "${d}")
      if [[ -n "${p}" ]]; then
        p="${p}/"
      fi
      echo "${p}${REPLY}" >> "${PATCH_DIR}/${repostatus}-golangcilint-result.txt"
    done < <("${GOLANGCI_LINT}" run "${args[@]}" ./... 2>&1 \
      | "${gargs[@]}" \
      | sort -t : -k 1,1 -k 2,2n -k 3,3n -k 4)
    popd >/dev/null || return 1
  done
  return 0
}

function golangcilint_preapply
{
  declare i

  if ! verify_needed_test golangcilint; then
    return 0
  fi

  big_console_header "golangcilint plugin: ${PATCH_BRANCH}"

  start_clock

  golangcilint_exec branch
  GOLANGCI_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call column_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function golangcilint_calcdiffs
{
  column_calcdiffs "$@"
}

function golangcilint_postapply
{

  if ! verify_needed_test golangcilint; then
    return 0
  fi

  big_console_header "golangcilint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${GOLANGCI_TIMER}"

  golangcilint_exec patch

  root_postlog_compare \
    golangcilint \
    "${PATCH_DIR}/branch-golangcilint-result.txt" \
    "${PATCH_DIR}/patch-golangcilint-result.txt"
}

function golangcilint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    golangcilint_preapply
  else
    golangcilint_postapply
  fi
}
