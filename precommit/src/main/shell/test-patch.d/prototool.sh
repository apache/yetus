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

add_test_type prototool

PROTOTOOL_TIMER=0

PROTOTOOL=${PROTOTOOL:-$(command -v prototool 2>/dev/null)}

function prototool_usage
{
  yetus_add_option "--prototool=<path>" "path to prototool executable (default: ${PROTOTOOL})"
  yetus_add_option "--prototool-basedir=<path>" "set the starting dir to run prototool"
  yetus_add_option "--prototool-walktimeout=<###u>" "set prototool walktimeout value"

}

function prototool_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
      --prototool=*)
        delete_parameter "${i}"
        PROTOTOOL=${i#*=}
      ;;
      --prototool-basedir=*)
        delete_parameter "${i}"
        PROTOTOOL_BASEDIR=${i#*=}
      ;;
      --prototool-walktimeout=*)
        delete_parameter "${i}"
        PROTOTOOL_WALKTIMEOUT=${i#*=}
      ;;

    esac
  done
}

function prototool_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.proto$ ]] ||
     [[ "${filename}" =~ prototool\.json$ ]] ||
     [[ "${filename}" =~ prototool\.yaml$ ]]; then
    add_test prototool
  fi
}

function prototool_precheck
{
  if ! verify_command "prototool" "${PROTOTOOL}"; then
    add_vote_table 0 prototool "prototool was not available."
    delete_test prototool
  fi
}

function prototool_executor
{
  declare repostatus=$1
  declare prototoolStderr=${repostatus}-prototool-stderr.txt
  declare -a args
  declare -a protoargs

  if ! verify_needed_test prototool; then
    return 0
  fi

  big_console_header "prototool plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${PROTOTOOL_TIMER}"

  echo "Running prototool against identified protobuf files."
  if [[ -n "${EXCLUDE_PATHS_FILE}" ]] && [[ -f "${EXCLUDE_PATHS_FILE}" ]]; then
    args=("${GREP}" "-v" "-E" "-f" "${EXCLUDE_PATHS_FILE}")
  else
    args=("cat")
  fi

  if [[ -n "${PROTOTOOL_WALKTIMEOUT}" ]]; then
    protoargs+=(--walk-timeout "${PROTOTOOL_WALKTIMEOUT}")
  fi

  if [[ -n "${PROTOTOOL_BASEDIR}" ]]; then
    pushd "${PROTOTOOL_BASEDIR}" >/dev/null || return 1
  else
    pushd "${BASEDIR}" >/dev/null || return 1
  fi

  "${PROTOTOOL}" lint  "${protoargs[@]}" 2> "${PATCH_DIR}/${prototoolStderr}" | \
    "${args[@]}" > "${PATCH_DIR}/${repostatus}-prototool-result.txt"
  popd >/dev/null || return 1

  if [[ -f ${PATCH_DIR}/${prototoolStderr} ]] && [[ -s "${prototoolStderr}" ]]; then
    add_vote_table -1 prototool "Error running prototool. Please check prototool stderr files."
    add_footer_table prototool "@@BASE@@/${prototoolStderr}"
    return 1
  fi
  rm "${PATCH_DIR}/${prototoolStderr}" 2>/dev/null
  return 0
}


function prototool_preapply
{
  declare retval

  if ! verify_needed_test prototool; then
    return 0
  fi

  prototool_executor "branch"
  retval=$?

  # keep track of how much as elapsed for us already
  PROTOTOOL_TIMER=$(stop_clock)
  return ${retval}
}

function prototool_postapply
{
  declare numPrepatch
  declare numPostpatch
  declare diffPostpatch
  declare fixedpatch
  declare statstring

  if ! verify_needed_test prototool; then
    return 0
  fi

  # shellcheck disable=SC2016
  PROTOTOOL_VERSION=$("${PROTOTOOL}" version 2>/dev/null | "${GREP}" Version | "${AWK}" '{print $NF}')
  add_version_data prototool "${PROTOTOOL_VERSION}"

  prototool_executor patch

  calcdiffs "${PATCH_DIR}/branch-prototool-result.txt" \
            "${PATCH_DIR}/patch-prototool-result.txt" \
            prototool > "${PATCH_DIR}/diff-patch-prototool.txt"

  # shellcheck disable=SC2016
  numPrepatch=$(wc -l "${PATCH_DIR}/branch-prototool-result.txt" | "${AWK}" '{print $1}')

  # shellcheck disable=SC2016
  numPostpatch=$(wc -l "${PATCH_DIR}/patch-prototool-result.txt" | "${AWK}" '{print $1}')

  # shellcheck disable=SC2016
  diffPostpatch=$(wc -l "${PATCH_DIR}/diff-patch-prototool.txt" | "${AWK}" '{print $1}')

  ((fixedpatch=numPrepatch-numPostpatch+diffPostpatch))

  statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

  if [[ ${diffPostpatch} -gt 0 ]] ; then
    add_vote_table -1 prototool "${BUILDMODEMSG} ${statstring}"
    add_footer_table prototool "@@BASE@@/diff-patch-prototool.txt"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
    add_vote_table +1 prototool "${BUILDMODEMSG} ${statstring}"
    return 0
  fi

  add_vote_table +1 prototool "There were no new prototool issues."
  return 0
}

function prototool_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    prototool_preapply
  else
    prototool_postapply
  fi
}
