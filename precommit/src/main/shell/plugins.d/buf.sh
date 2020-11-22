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

add_test_type buf
add_test_type buflint
add_test_type bufcompat

BUFLINT_TIMER=0
BUFCOMPAT_TIMER=0
BUF=${BUF:-$(command -v buf 2>/dev/null)}
BUF_ALREADY=false

function buf_usage
{
  yetus_add_option "--buf=<file>" "path to buf executable (default: ${BUF})"
  yetus_add_option "--buf-basedir=<dir>" "set the starting dir to run buf"
  yetus_add_option "--buf-timeout=###u" "Set the buf timeout"
}

function buf_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --buf=*)
        delete_parameter "${i}"
        BUF=${i#*=}
      ;;
      --buf-basedir=*)
        delete_parameter "${i}"
        BUF_BASEDIR=${i#*=}
      ;;
      --buf-timeout=*)
        delete_parameter "${i}"
        BUF_TIMEOUT=${i#*=}
      ;;
    esac
  done

  if [[ -n "${BUF_BASEDIR}" ]]; then
    # make sure this is relative and strip any ending /
    BUF_BASEDIR=$(yetus_abs "${BUF_BASEDIR}")
    BUF_BASEDIR=$(yetus_relative_dir "${BASEDIR}" "${BUF_BASEDIR}")
  fi

  # forcibly setting return 0 because otherwise
  # return yetus_relative_dir's return value
  # which breaks things usually
  return 0
}

function buf_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.proto$ ]] ||
     [[ "${filename}" =~ buf\.json$ ]] ||
     [[ "${filename}" =~ buf\.yaml$ ]]; then
    add_test buflint
    add_test bufcompat
  fi
}

function buf_precheck
{

  if [[ "${BUF_ALREADY}" == true ]]; then
    return 0
  fi

  if ! verify_command "buf" "${BUF}"; then
    add_vote_table_v2 0 buf "" "buf was not available."
    delete_test buflint
    delete_test bufcompat
  fi

  # shellcheck disable=SC2016
  BUF_VERSION=$("${BUF}" --version 2>/dev/null)
  add_version_data buf "${BUF_VERSION}"
  BUF_ALREADY=true
}

##############

function bufcompat_parse_args {
  buf_parse_args "$@"
}

function bufcompat_filefilter
{
  buf_filefilter "$@"
}

function bufcompat_precheck
{
  buf_precheck "$@"
}

function bufcompat_executor
{
  declare repostatus=$1
  declare bufStderr=${repostatus}-bufcompat-stderr.txt
  declare -a args
  declare -a bufargs

  if ! verify_needed_test bufcompat ; then
    return 0
  fi

  big_console_header "bufcompat plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${BUFCOMPAT_TIMER}"

  echo "Running buf against identified protobuf files."
  if [[ -n "${EXCLUDE_PATHS_FILE}" ]] && [[ -f "${EXCLUDE_PATHS_FILE}" ]]; then
    args=("${GREP}" "-v" "-E" "-f" "${EXCLUDE_PATHS_FILE}")
  else
    args=("cat")
  fi

  if [[ -n "${BUF_TIMEOUT}" ]]; then
    bufargs+=(--timeout "${BUF_TIMEOUT}")
  fi

  pushd "${BASEDIR}/${BUF_BASEDIR}" >/dev/null || return 1

  if [[ "${repostatus}" == "branch" ]]; then
    "${BUF}" image build "${bufargs[@]}" -o "${PATCH_DIR}/buf-image.bin" 2>> "${PATCH_DIR}/${bufStderr}"
  elif [[ -f  "${PATCH_DIR}/buf-image.bin" ]]; then
    "${BUF}" check breaking "${bufargs[@]}" \
      --against-input "${PATCH_DIR}/buf-image.bin" \
      2>> "${PATCH_DIR}/${bufStderr}" \
    | "${AWK}" "{print \"${BUF_BASEDIR}/\"\$0}" \
      > "${PATCH_DIR}/${repostatus}-bufcompat-result.txt" \

  fi

  popd >/dev/null || return 1

  if [[ -f ${PATCH_DIR}/${bufStderr} ]] && [[ -s "${bufStderr}" ]]; then
    add_vote_table_v2 -1 bufcompat "@@BASE@@/${bufStderr}" "Error running buf. Please check buf stderr files."
    return 1
  fi
  rm "${PATCH_DIR}/${bufStderr}" 2>/dev/null
  return 0
}

function bufcompat_preapply
{
  declare retval


  if ! verify_needed_test bufcompat; then
    return 0
  fi

  bufcompat_executor "branch"
  retval=$?

  # keep track of how much as elapsed for us already
  BUFCOMPAT_TIMER=$(stop_clock)
  return ${retval}
}

function bufcompat_postapply
{
  declare incompatcount

  if ! verify_needed_test bufcompat; then
    return 0
  fi

  big_console_header "bufcompat plugin: ${BUILDMODE}"

  bufcompat_executor "patch"

  offset_clock "${BUFCOMPAT_TIMER}"

  if [[ -s "${PATCH_DIR}/${repostatus}-bufcompat-result.txt" ]]; then
    # shellcheck disable=SC2016
    incompatcount=$(wc -l "${PATCH_DIR}/${repostatus}-bufcompat-result.txt")
    incompatcount=${incompatcount%% *}
    add_vote_table_v2 -1 bufcompat \
      "@@BASE@@/${repostatus}-bufcompat-result.txt" \
      "${incompatcount} Incompatible protobuf changes"
    bugsystem_linecomments_queue bufcompat "${PATCH_DIR}/${repostatus}-bufcompat-result.txt"
    return 1
  fi
  return 0
}

function bufcompat_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    bufcompat_preapply
  else
    bufcompat_postapply
  fi
}

##############


function buflint_parse_args {
  buf_parse_args "$@"
}

function buflint_filefilter
{
  buf_filefilter "$@"
}

function buflint_precheck
{
  buf_precheck "$@"
}

function buflint_executor
{
  declare repostatus=$1
  declare bufStderr=${repostatus}-buflint-stderr.txt
  declare -a args
  declare -a bufargs

  if ! verify_needed_test buflint ; then
    return 0
  fi

  big_console_header "buflint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${BUFLINT_TIMER}"

  echo "Running buf against identified protobuf files."
  if [[ -n "${EXCLUDE_PATHS_FILE}" ]] && [[ -f "${EXCLUDE_PATHS_FILE}" ]]; then
    args=("${GREP}" "-v" "-E" "-f" "${EXCLUDE_PATHS_FILE}")
  else
    args=("cat")
  fi


  if [[ -n "${BUF_TIMEOUT}" ]]; then
    bufargs+=(--timeout "${BUF_TIMEOUT}")
  fi

  pushd "${BASEDIR}/${BUF_BASEDIR}" >/dev/null || return 1

  "${BUF}" check lint  "${bufargs[@]}" 2>> "${PATCH_DIR}/${bufStderr}" \
    | "${AWK}" "{print \"${BUF_BASEDIR}/\"\$0}" \
    | "${args[@]}" > "${PATCH_DIR}/${repostatus}-buflint-result.txt"

  popd >/dev/null || return 1

  if [[ -f ${PATCH_DIR}/${bufStderr} ]] && [[ -s "${bufStderr}" ]]; then
    add_vote_table_v2 -1 buflint \
      "@@BASE@@/${bufStderr}" \
      "Error running buf. Please check buf stderr files."
    return 1
  fi
  rm "${PATCH_DIR}/${bufStderr}" 2>/dev/null
  return 0
}


function buflint_preapply
{
  declare retval

  if ! verify_needed_test buflint; then
    return 0
  fi

  buflint_executor "branch"
  retval=$?

  # keep track of how much as elapsed for us already
  BUFLINT_TIMER=$(stop_clock)
  return ${retval}
}

function buflint_postapply
{
  if ! verify_needed_test buflint; then
    return 0
  fi

  # shellcheck disable=SC2016
  BUF_VERSION=$("${BUF}" version 2>/dev/null | "${GREP}" Version | "${AWK}" '{print $NF}')
  add_version_data buf "${BUF_VERSION}"

  buflint_executor patch

  root_postlog_compare \
    buflint \
    "${PATCH_DIR}/branch-buflint-result.txt" \
    "${PATCH_DIR}/patch-buflint-result.txt"
}

function buflint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    buflint_preapply
  else
    buflint_postapply
  fi
}
