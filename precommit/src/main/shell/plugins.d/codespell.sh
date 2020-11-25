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

add_test_type codespell

CODESPELL_TIMER=0
CODESPELL=${CODESPELL:-$(command -v codespell 2>/dev/null)}
CODESPELL_X_FILE=".codespellignorelines"

function codespell_usage
{
  yetus_add_option "--codespell-exclude-lines=<file>" "Lines to ignore via codespell -x (default: '${CODESPELL_X_FILE}')"
}

function codespell_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --codespell-exclude-lines=*)
        delete_parameter "${i}"
        CODESPELL_X_FILE=${i#*=}
      ;;
    esac
  done

  pushd "${BASEDIR}" >/dev/null || return 1
  CODESPELL_X_FILE=$(yetus_abs "${CODESPELL_X_FILE}")
  popd >/dev/null || return 1

  return 0
}

function codespell_filefilter
{
  add_test codespell
}

function codespell_precheck
{
  if ! verify_command "codespell" "${CODESPELL}"; then
    add_vote_table_v2 0 codespell "" "codespell was not available."
    delete_test codespell
  fi
}

function codespell_logic
{
  declare repostatus=$1
  declare -a codespellargs
  declare i

  pushd "${BASEDIR}" >/dev/null || return 1

  # codespell will ignore skip directives if you give it
  # a specific file name.  so best we can do is
  # use CHANGED_DIRS[@].  Will still need to filter out
  # files, but this should at least cut back on the runtime

  if [[ -f "${CODESPELL_X_FILE}" ]]; then
    codespellargs=("--exclude-file" "${CODESPELL_X_FILE}")
  fi

  # specifically add ./ because otherwise the .codespellrc file gets weird
  "${CODESPELL}" \
    --disable-colors \
    --interactive 0 \
    --quiet-level 2 \
    "${codespellargs[@]}" \
    "./${i}" \
  | "${SED}" -e 's,^./,,g' \
    >> "${PATCH_DIR}/${repostatus}-codespell-tmp.txt"

  for i in "${CHANGED_FILES[@]}"; do
    "${GREP}" -E "^${i}:" \
      "${PATCH_DIR}/${repostatus}-codespell-tmp.txt" \
      >> "${PATCH_DIR}/${repostatus}-codespell-result.txt"
  done

  popd > /dev/null || return 1
}

function codespell_preapply
{
  if ! verify_needed_test codespell; then
    return 0
  fi

  big_console_header "codespell plugin: ${PATCH_BRANCH}"

  start_clock

  codespell_logic branch

  # keep track of how much as elapsed for us already
  CODESPELL_TIMER=$(stop_clock)
  return 0
}

function codespell_calcdiffs
{
  error_calcdiffs "$@"
}

function codespell_postapply
{
  declare version

  if ! verify_needed_test codespell; then
    return 0
  fi

  big_console_header "codespell plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${CODESPELL_TIMER}"

  codespell_logic patch

  version=$("${CODESPELL}" --version)
  add_version_data codespell "${version##* v}"

  root_postlog_compare \
    codespell \
    "${PATCH_DIR}/branch-codespell-result.txt" \
    "${PATCH_DIR}/patch-codespell-result.txt"
}

function codespell_precompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    codespell_preapply
  else
    codespell_postapply
  fi
}
