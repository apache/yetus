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

add_test_type detsecrets

DETSECRETS_TIMER=0

DETSECRETS=${DETSECRETS:-$(command -v detect-secrets 2>/dev/null)}

# why are these command line options instead of reading from a file?
DETSECRETS_FILES='' #regex of files to ignore
DETSECRETS_LINES='' #regex of lines to ignore
DETSECRETS_SECRETS='' #regex of secrets to ignore
DETSECRETS_HASHFILE='.yetus/detsecrets-ignored-hashes.txt'
DETSECRETS_OLD='false'

function detsecrets_usage
{
  yetus_add_option "--detsecrets=<file>" "Filename of the detect-secrets executable (default: ${DETSECRETS})"
  yetus_add_option "--detsecrets-files=<regex>" "Regex of files to ignore"
  yetus_add_option "--detsecrets-hashes-to-ignore=<file>" "Filename of a list of hashes to ignore (default: ${DETSECRETS_HASHFILE})"
  yetus_add_option "--detsecrets-lines=<regex>" "Regex of lines to ignore"
  yetus_add_option "--detsecrets-secrets=<regex>" "Regex of secrets to ignore"
}

function detsecrets_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
    --detsecrets=*)
      delete_parameter "${i}"
      DETSECRETS=${i#*=}
    ;;
    --detsecrets-files=*)
      delete_parameter "${i}"
      DETSECRETS_FILES=${i#*=}
    ;;
    --detsecrets-hashes-to-ignore=*)
      delete_parameter "${i}"
      DETSECRETS_HASHFILE=${i#*=}
    ;;
    --detsecrets-lines=*)
      delete_parameter "${i}"
      DETSECRETS_LINES=${i#*=}
    ;;
    --detsecrets-secrets=*)
      delete_parameter "${i}"
      DETSECRETS_SECRETS=${i#*=}
    ;;
    esac
  done
}

function detsecrets_filefilter
{
  add_test detsecrets
}

function detsecrets_precheck
{
  if ! verify_command "detect-secrets" "${DETSECRETS}"; then
    add_vote_table_v2 0 detsecrets "" "detect-secrets was not available."
    delete_test detsecrets
  fi

  # shellcheck disable=SC2016
  DETSECRETS_VERSION=$("${DETSECRETS}" --version 2>/dev/null| "${AWK}" '{print $NF}')

  if [[ ${DETSECRETS_VERSION} =~ /^0 ]]; then
    DETSECRETS_OLD='true'
  fi
}

function detsecrets_calcdiffs
{
  # should be able to use column since our detsecrets-parse turns
  # our output into file:line:hash:error, where hash will be unique
  column_calcdiffs "$@"
}

function detsecrets_convert_json_to_flat
{
  declare repostatus=$1

  if [[ -f "${PATCH_DIR}/excluded.txt" ]]; then
    stripcmd=("${GREP}" "-v" "-f" "${PATCH_DIR}/excluded.txt")
  else
    stripcmd=("cat")
  fi

  # rip apart the detect-secrets json and make it a colon delimited file
  # to make it easier to parse.  Theoretically, python or python3 should
  # be available on the path since detect-secrets also needs it.
  pythonexec=$(command -v python3) || pythonexec=$(command -v python)

  "${pythonexec}" "${BINDIR}/plugins.d/detsecrets_parse.py" \
    "${PATCH_DIR}/${repostatus}-detsecrets-result.json" \
    "${DETSECRETS_HASHFILE}" \
  | "${stripcmd[@]}" \
    > "${PATCH_DIR}/${repostatus}-detsecrets-result.txt"
}

function detsecrets_executor
{
  declare repostatus=$1
  declare i
  declare count
  declare detsecretsStderr=${repostatus}-detsecrets-stderr.txt
  declare -a detsecretsopts

  if ! verify_needed_test detsecrets; then
    return 0
  fi

  big_console_header "detsecrets plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${DETSECRETS_TIMER}"

  echo "Running detect-secrets against source tree."
  pushd "${BASEDIR}" >/dev/null || return 1

  detsecretsopts=()

  if [[ -n "${DETSECRETS_FILES}" ]]; then
    detsecretsopts=("${detsecretsopts[@]}" "--exclude-files" "${DETSECRETS_FILES}")
  fi

  if [[ -n "${DETSECRETS_LINES}" ]]; then
    detsecretsopts=("${detsecretsopts[@]}" "--exclude-lines" "${DETSECRETS_LINES}")
  fi
  if [[ -n "${DETSECRETS_SECRETS}" ]]; then
    detsecretsopts=("${detsecretsopts[@]}" "--exclude-secrets" "${DETSECRETS_SECRETS}")
  fi

  if [[ ${DETSECRETS_OLD} == 'false' ]]; then
    "${DETSECRETS}" "${detsecretsopts[@]}" scan \
      --all-files \
      "${detsecretsopts[@]}" \
      > "${PATCH_DIR}/${repostatus}-detsecrets-result.json" \
      2>"${PATCH_DIR}/${detsecretsStderr}"
  else
    "${DETSECRETS}" "${detsecretsopts[@]}" scan \
      "${detsecretsopts[@]}" \
      > "${PATCH_DIR}/${repostatus}-detsecrets-result.json" \
      2>"${PATCH_DIR}/${detsecretsStderr}"
  fi

  detsecrets_convert_json_to_flat "${repostatus}"

  if [[ -f ${PATCH_DIR}/${detsecretsStderr} ]]; then
    # shellcheck disable=SC2016
    count=$(wc -l "${PATCH_DIR}/${detsecretsStderr}" | "${AWK}" '{print $1}')
    if [[ ${count} -gt 0 ]]; then
      add_vote_table_v2 -1 detsecrets "@@BASE@@/${detsecretsStderr}" "Error running detsecrets. Please check detsecrets stderr files."
      return 1
    fi
  fi
  rm "${PATCH_DIR}/${detsecretsStderr}" 2>/dev/null
  popd >/dev/null || return 1
  return 0
}

function detsecrets_preapply
{
  declare retval

  if ! verify_needed_test detsecrets; then
    return 0
  fi

  detsecrets_executor "branch"
  retval=$?

  # keep track of how much as elapsed for us already
  DETSECRETS_TIMER=$(stop_clock)
  return ${retval}
}

function detsecrets_postapply
{
  if ! verify_needed_test detsecrets; then
    return 0
  fi

  detsecrets_executor patch

  # shellcheck disable=SC2016
  DETSECRETS_VERSION=$("${DETSECRETS}" --version 2>/dev/null | "${GREP}" detsecrets | "${AWK}" '{print $NF}')
  add_version_data detsecrets "${DETSECRETS_VERSION%,}"


  root_postlog_compare \
    detsecrets \
    "${PATCH_DIR}/branch-detsecrets-result.txt" \
    "${PATCH_DIR}/patch-detsecrets-result.txt"
}

function detsecrets_precompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    detsecrets_preapply
  else
    detsecrets_postapply
  fi
}
