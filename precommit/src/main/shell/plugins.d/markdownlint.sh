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

add_test_type markdownlint

MARKDOWNLINT_TIMER=0
MARKDOWNLINT=${MARKDOWNLINT:-$(command -v markdownlint 2>/dev/null)}

# files that are going to get markdownlint'd
MARKDOWNLINT_CHECKFILES=()

function markdownlint_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.md$ ]]; then
    add_test markdownlint
    yetus_add_array_element MARKDOWNLINT_CHECKFILES "${filename}"
  fi
}

function markdownlint_precheck
{
  if ! verify_command "markdownlint" "${MARKDOWNLINT}"; then
    add_vote_table_v2 0 markdownlint "" "markdownlint was not available."
    delete_test markdownlint
  fi
}

function markdownlint_logic
{
  declare repostatus=$1
  declare i
  declare line
  declare output

  pushd "${BASEDIR}" >/dev/null || return 1

  for i in "${MARKDOWNLINT_CHECKFILES[@]}"; do
    if [[ -f "${i}" ]]; then
      while read -r; do
        if [[ "${REPLY}" =~ ^.*:[0-9]+:[0-9]+ ]]; then
          # fn:line(space)MD333/key long description
          line=${REPLY}
        else
          # fn:line(space)MD###/key long description
          line=$(echo "${REPLY}" | "${SED}" 's, ,:0 ,')
        fi
        #fn:line:col:MD###/key long description
        output=$(echo "${line}" | "${SED}" 's, ,:,')

        echo "${output}" >> "${PATCH_DIR}/${repostatus}-markdownlint-result.txt"
      done < <("${MARKDOWNLINT}" "${i}" 2>&1)
    fi
  done
  popd > /dev/null || return 1
}

function markdownlint_preapply
{
  if ! verify_needed_test markdownlint; then
    return 0
  fi

  big_console_header "markdownlint plugin: ${PATCH_BRANCH}"

  start_clock

  markdownlint_logic branch

  # keep track of how much as elapsed for us already
  MARKDOWNLINT_TIMER=$(stop_clock)
  return 0
}

function markdownlint_calcdiffs
{
  column_calcdiffs "$@"
}

function markdownlint_postapply
{
  declare version

  if ! verify_needed_test markdownlint; then
    return 0
  fi

  big_console_header "markdownlint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${MARKDOWNLINT_TIMER}"

  markdownlint_logic patch

  # shellcheck disable=SC2016
  version=$("${MARKDOWNLINT}" --version 2>&1)
  add_version_data markdownlint "${version#* }"

  root_postlog_compare \
    markdownlint \
    "${PATCH_DIR}/branch-markdownlint-result.txt" \
    "${PATCH_DIR}/patch-markdownlint-result.txt"
}

function markdownlint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    markdownlint_preapply
  else
    markdownlint_postapply
  fi
}
