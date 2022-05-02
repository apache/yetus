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

add_test_type xmllint

XMLLINT_TIMER=0

XMLLINT=${XMLLINT:-$(command -v xmllint 2>/dev/null)}

function xmllint_usage
{
  yetus_add_option "--xmllint=<file>" "path to xmllint executable"
}

function xmllint_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
    --xmllint=*)
      delete_parameter "${i}"
      XMLLINT=${i#*=}
    ;;
    esac
  done
}

function xmllint_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.xml$ || ${filename} =~ \.html?$ ]]; then
    add_test xmllint
  fi
}

function xmllint_precheck
{
  if ! verify_command xmllint "${XMLLINT}"; then
    add_vote_table_v2 0 xmllint "" "xmllint was not available."
    delete_test xmllint
    return 0
  fi
}


function xmllint_exec
{
  declare i
  declare repostatus=$1
  declare tempfile

  tempfile="${PATCH_DIR}/xmltmp.$$"

  pushd "${BASEDIR}" >/dev/null || return 1

  # xmllint's output is _ugly_ and requires filtering.

  printf "^%b:\n" "${CHANGED_FILES[@]}" > "${tempfile}"

  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.xml$ && -f ${i} ]]; then
      "${XMLLINT}" --nout "${i}" 2>&1 \
        | "${GREP}" -E -f "${tempfile}" \
        >> "${PATCH_DIR}/${repostatus}-xmllint-result.txt"
    fi
    if [[ ${i} =~ \.html?$ && -f ${i} ]]; then
      "${XMLLINT}" --html --nout "${i}" 2>&1 \
        | "${GREP}" -E -f "${tempfile}" \
        >> "${PATCH_DIR}/${repostatus}-xmllint-result.txt"
    fi
  done
  rm "${tempfile}"
  popd >/dev/null || return 1
  return 0
}

function xmllint_preapply
{
  if ! verify_needed_test xmllint; then
    return 0
  fi

  big_console_header "xmllint plugin: ${PATCH_BRANCH}"

  start_clock

  xmllint_exec branch

  XMLLINT_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call column_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function xmllint_calcdiffs
{
  column_calcdiffs "$@"
}

function xmllint_postapply
{
  if ! verify_needed_test xmllint; then
    return 0
  fi

  big_console_header "xmllint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${XMLLINT_TIMER}"

  xmllint_exec patch

  # shellcheck disable=SC2016
  XMLLINT_VERSION=$("${XMLLINT}" --version 2>&1 | head -1 | "${AWK}" '{print $NF}')
  add_version_data xmllint "${XMLLINT_VERSION}"

  root_postlog_compare \
    xmllint \
    "${PATCH_DIR}/branch-xmllint-result.txt" \
    "${PATCH_DIR}/patch-xmllint-result.txt"
}

function xmllint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    xmllint_preapply
  else
    xmllint_postapply
  fi
}
