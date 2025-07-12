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

add_test_type ruff

RUFF_TIMER=0

RUFF=${RUFF:-$(command -v ruff 2>/dev/null)}
# backward compatibility, do not use
RUFF_PIP_CMD=$(command -v pip 2>/dev/null)
RUFF_REQUIREMENTS=false
RUFF_PIP_USER=true
RUFF_CHECK_MODE=true
RUFF_FORMAT_MODE=true

function ruff_usage
{
  yetus_add_option "--ruff=<file>" "Filename of the ruff executable (default: ${RUFF})"
  yetus_add_option "--ruff-check=<bool>" "Enable ruff check mode (default: ${RUFF_CHECK_MODE})"
  yetus_add_option "--ruff-format=<bool>" "Enable ruff format mode (default: ${RUFF_FORMAT_MODE})"
  yetus_add_option "--ruff-pip-cmd=<file>" "Command to use for pip when installing requirements.txt (default: ${RUFF_PIP_CMD})"
  yetus_add_option "--ruff-requirements=<bool>" "pip install requirements.txt (default: ${RUFF_REQUIREMENTS})"
  yetus_add_option "--ruff-use-user=<bool>" "Use --user for the requirements.txt (default: ${RUFF_PIP_USER})"
}

function ruff_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
    --ruff=*)
      delete_parameter "${i}"
      RUFF=${i#*=}
    ;;
    --ruff-check=*)
      delete_parameter "${i}"
      RUFF_FORMAT_MODE=${i#*=}
    ;;
    --ruff-format=*)
      delete_parameter "${i}"
      RUFF_CHECK_MODE=${i#*=}
    ;;
    --ruff-pip-cmd=*)
      delete_parameter "${i}"
      RUFF_PIP_CMD=${i#*=}
    ;;
    --ruff-requirements=*)
      delete_parameter "${i}"
      RUFF_REQUIREMENTS=${i#*=}
    ;;
    --ruff-use-user=*)
      delete_parameter "${i}"
      RUFF_PIP_USER=${i#*=}
    ;;
    esac
  done
}

function ruff_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.py$ ]]; then
    add_test ruff
  fi
}

function ruff_precheck
{
  if ! verify_command "ruff" "${RUFF}"; then
    add_vote_table_v2 0 ruff "" "ruff was not available."
    delete_test ruff
    return 0
  fi

  if [[ "${RUFF_REQUIREMENTS}" == true ]] && ! verify_command pip "${RUFF_PIP_CMD}"; then
    add_vote_table_v2 0 ruff "" "pip command not available. Will process without it."
  fi
}

function ruff_calcdiffs
{
  column_calcdiffs "$@"
}

function ruff_executor
{
  declare repostatus=$1
  declare i
  declare count
  declare ruffStderr=${repostatus}-ruff-stderr.txt
  declare oldpp
  declare -a ruffopts
  declare -a reqfiles

  if ! verify_needed_test ruff; then
    return 0
  fi

  big_console_header "ruff plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${RUFF_TIMER}"

  if [[ "${RUFF_REQUIREMENTS}" == true ]]; then
    echo "Processing all requirements.txt files. Errors will be ignored."

    if [[ "${RUFF_PIP_USER}" == true ]]; then
      ruffopts=("--user")
    fi

    reqfiles=()
    for i in "${CHANGED_FILES[@]}"; do
      dirname=$(yetus_abs "${i}")
      dirname=$(dirname "${dirname}")
      if [[ -f "${dirname}/requirements.txt" ]]; then
        reqfiles+=("${dirname}/requirements.txt")
      fi
    done
    yetus_sort_and_unique_array reqfiles
    for i in "${reqfiles[@]}"; do
      "${RUFF_PIP_CMD}" install "${ruffopts[@]}" -r "${i}" || true
    done
    oldpp=${PYTHONPATH}
    for i in "${HOME}/.local/lib/python"*/site-packages; do
      export PYTHONPATH="${PYTHONPATH:+${PYTHONPATH}:}${i}"
    done
  fi

  pushd "${BASEDIR}" >/dev/null || return 1

  if [[ "${RUFF_CHECK_MODE}" = "true" ]]; then
    ruffopts=()
    ruffopts+=('check')
    ruffopts+=('--output-format=concise')
    ruffopts+=('--no-cache')


    echo "Running ruff check against identified python scripts."
    for i in "${CHANGED_FILES[@]}"; do
      if [[ ${i} =~ \.py$ && -f ${i} ]]; then
        "${RUFF}" "${ruffopts[@]}" "${i}" \
          >> "${PATCH_DIR}/${repostatus}-ruff-check-result.tmp" \
          2>>"${PATCH_DIR}/${ruffStderr}"
      fi
    done
  fi

  if [[ "${RUFF_FORMAT_MODE}" = "true" ]]; then
    ruffopts=()
    ruffopts+=('format')
    ruffopts+=('--check')
    ruffopts+=('--no-cache')
    ruffopts+=('--silent')

    echo "Running ruff format against identified python scripts."
    for i in "${CHANGED_FILES[@]}"; do
      if [[ ${i} =~ \.py$ && -f ${i} ]]; then
        if ! "${RUFF}" "${ruffopts[@]}" "${i}"2>>"${PATCH_DIR}/${ruffStderr}"; then
          echo ":${i}" >> "${PATCH_DIR}/${repostatus}-ruff-format-result.tmp"
        fi
      fi
    done

  fi


  if [[ -n "${oldpp}" ]]; then
    export PYTHONPATH=${oldpp}
  fi

  if [[ -f ${PATCH_DIR}/${ruffStderr} ]]; then
    count=$("${GREP}"  -Evc "^(No config file found|Using config file)" "${PATCH_DIR}/${ruffStderr}")
    if [[ ${count} -gt 0 ]]; then
      add_vote_table_v2 -1 ruff "@@BASE@@/${ruffStderr}" "Error running ruff. Please check ruff stderr files."
      return 1
    fi
  fi
  rm "${PATCH_DIR}/${ruffStderr}" 2>/dev/null
  popd >/dev/null || return 1
  return 0
}

function ruff_preapply
{
  declare retval

  if ! verify_needed_test ruff; then
    return 0
  fi

  ruff_executor "branch"
  retval=$?

  # keep track of how much as elapsed for us already
  RUFF_TIMER=$(stop_clock)
  return ${retval}
}

function ruff_postapply
{
  if ! verify_needed_test ruff; then
    return 0
  fi

  ruff_executor patch

  # shellcheck disable=SC2016
  RUFF_VERSION=$("${RUFF}" --version 2>/dev/null | "${AWK}" '{print $NF}')
  add_version_data ruff "${RUFF_VERSION}"


  root_postlog_compare \
    ruff_check \
    "${PATCH_DIR}/branch-ruff-check-result.txt" \
    "${PATCH_DIR}/patch-ruff-check-result.txt"

  root_postlog_compare \
    ruff_format \
    "${PATCH_DIR}/branch-ruff-check-result.txt" \
    "${PATCH_DIR}/patch-ruff-check-result.txt"

}

function ruff_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    ruff_preapply
  else
    ruff_postapply
  fi
}

function ruff_format_calcdiffs
{
  declare branch=$1
  declare patch=$2
  declare tmp=${PATCH_DIR}/pl.$$.${RANDOM}
  declare j

  # compare the errors, generating a string of line
  # numbers. Sorry portability: GNU diff makes this too easy
  "${DIFF}" --unchanged-line-format="" \
     --old-line-format="" \
     --new-line-format="%dn " \
     "${tmp}.branch" \
     "${tmp}.patch" > "${tmp}.lined"

  if [[ "${BUILDMODE}" == full ]]; then
    cat "${patch}"
  else
    # now, pull out those lines of the raw output
    # shellcheck disable=SC2013
    for j in $(cat "${tmp}.lined"); do
      head -"${j}" "${patch}" | tail -1
    done
  fi

  rm "${tmp}.branch" "${tmp}.patch" "${tmp}.lined" 2>/dev/null
}