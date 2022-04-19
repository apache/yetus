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

add_test_type ansiblelint

ANSIBLELINT_TIMER=0

ANSIBLELINT=${ANSIBLELINT:-$(command -v ansible-lint 2>/dev/null)}

function ansiblelint_usage
{
  yetus_add_option "--ansiblelint=<path>" "path to ansible-lint executable"
}

function ansiblelint_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
    --ansiblelint=*)
      ANSIBLELINT=${i#*=}
    ;;
    esac
  done
}

function ansiblelint_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ playbooks/.*\.yml$ ]] || [[ ${filename} =~ playbooks/.*\.yaml$ ]]; then
    add_test ansiblelint
  fi
}

function ansiblelint_precheck
{
  if ! verify_command ansiblelint "${ANSIBLELINT}"; then
    add_vote_table 0 ansiblelint "ansiblelint was not available."
    delete_test ansiblelint
    return 0
  fi
}

function ansiblelint_logic
{
  declare repostatus=$1
  declare i
  declare -a ansiblelint_params

  pushd "${BASEDIR}" >/dev/null || return 1

  ansiblelint_params=(--nocolor)
  ansiblelint_params+=(-f plain)
  ansiblelint_params+=(--parseable-severity)
  ansiblelint_params+=(--show-relpath)

  if [[ "${OFFLINE}" == "true" ]]; then
    ansiblelint_params+=(--offline)
  fi

  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ playbooks/.*\.yaml$ && -f ${i} ]] ||
       [[ ${i} =~ playbooks/.*\.yml$ && -f ${i} ]]; then

      # unfortunately, ansible-lint pollutes stderr with a pointless message
      # about how to skip tests so there is no point in trying to process it. :(
      "${ANSIBLELINT}" \
        "${ansiblelint_params[@]}" \
        "${i}" \
        >> "${PATCH_DIR}/${repostatus}-ansiblelint-result.tmp" \
        2> "${PATCH_DIR}/${repostatus}-ansiblelint-stderr.txt"
    fi
  done

  if [[ -f "${PATCH_DIR}/${repostatus}-ansiblelint-result.tmp" ]]; then
    sort \
      "${PATCH_DIR}/${repostatus}-ansiblelint-result.tmp" \
      > "${PATCH_DIR}/${repostatus}-ansiblelint-result.txt"
    rm "${PATCH_DIR}/${repostatus}-ansiblelint-result.tmp"
  else
    touch "${PATCH_DIR}/${repostatus}-ansiblelint-result.txt"
  fi

  popd > /dev/null || return 1
}


function ansiblelint_preapply
{
  if ! verify_needed_test ansiblelint; then
    return 0
  fi

  big_console_header "ansiblelint plugin: ${PATCH_BRANCH}"

  start_clock

  ansiblelint_logic branch

  # keep track of how much as elapsed for us already
  ANSIBLELINT_TIMER=$(stop_clock)
  return 0
}

function ansiblelint_postapply
{
  declare version

  if ! verify_needed_test ansiblelint; then
    return 0
  fi

  big_console_header "ansiblelint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${ANSIBLELINT_TIMER}"

  ansiblelint_logic patch

  # shellcheck disable=SC2016
  version=$("${ANSIBLELINT}" --version | "${AWK}" '{print $NF}')

  add_version_data ansiblelint "v${version}"

  root_postlog_compare \
    ansiblelint \
    "${PATCH_DIR}/branch-ansiblelint-result.txt" \
    "${PATCH_DIR}/patch-ansiblelint-result.txt"
}

function ansiblelint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    ansiblelint_preapply
  else
    ansiblelint_postapply
  fi
}