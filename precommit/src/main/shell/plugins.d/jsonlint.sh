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

add_test_type jsonlint

JSONLINT_TIMER=0

JSONLINT=${JSONLINT:-$(command -v jsonlint 2>/dev/null)}

function jsonlint_usage
{
  yetus_add_option "--jsonlint=<file>" "path to jsonlint executable"
}

function jsonlint_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --jsonlint=*)
        JSONLINT=${i#*=}
        delete_parameter "${i}"
      ;;
    esac
  done
}

function jsonlint_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.json$ ]]; then
    add_test jsonlint
  fi
}

function jsonlint_precheck
{
  if ! verify_command jsonlint "${JSONLINT}"; then
    add_vote_table_v2 0 jsonlint "" "jsonlint was not available."
    delete_test jsonlint
    return 0
  fi
}

function jsonlint_exec
{
  declare i
  declare repostatus=$1

  echo "Running jsonlint against identified json files."
  pushd "${BASEDIR}" >/dev/null || return 1

  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.json$ && -f ${i} ]]; then
      "${JSONLINT}" --quiet --compact "${i}"  2>&1 \
        | "${SED}" -e 's# line ##g' \
                   -e 's#, col #:#g' \
                   -e 's#, found: #:#g' \
      >> "${PATCH_DIR}/${repostatus}-jsonlint-result.txt" 2>&1
    fi
  done

  popd >/dev/null || return 1
  return 0
}

function jsonlint_preapply
{
  declare i

  if ! verify_needed_test jsonlint; then
    return 0
  fi

  big_console_header "jsonlint plugin: ${PATCH_BRANCH}"

  start_clock

  jsonlint_exec branch

  JSONLINT_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call column_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function jsonlint_calcdiffs
{
  column_calcdiffs "$@"
}

function jsonlint_postapply
{
  if ! verify_needed_test jsonlint; then
    return 0
  fi

  big_console_header "jsonlint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${JSONLINT_TIMER}"

  jsonlint_exec patch

  root_postlog_compare \
    jsonlint \
    "${PATCH_DIR}/branch-jsonlint-result.txt" \
    "${PATCH_DIR}/patch-jsonlint-result.txt"


  # shellcheck disable=SC2016
  JSONLINT_VERSION=$("${JSONLINT}" --version | "${AWK}" '{print $NF}')
  add_version_data jsonlint "${JSONLINT_VERSION}"
}

function jsonlint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    jsonlint_preapply
  else
    jsonlint_postapply
  fi
}
