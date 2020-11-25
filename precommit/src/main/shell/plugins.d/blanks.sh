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

BLANKS_EOL_IGNORE_LIST=
BLANKS_TABS_IGNORE_LIST='.*Makefile.*','.*\.go','.*go\.mod'
BLANKS_EOL_IGNORE_FILE='.yetus/blanks-eol.txt'
BLANKS_TABS_IGNORE_FILE='.yetus/blanks-tabs.txt'

add_test_type blanks

## @description  blanks usage hook
## @audience     private
## @stability    evolving
## @replaceable  no
function blanks_usage
{
  yetus_add_option "--blanks-eol-ignore-file=<file>" "file of regexes to ignore for EOLs (default '${BLANKS_EOL_IGNORE_FILE}')"
  yetus_add_option "--blanks-tabs-ignore-file=<file>" "file of regexs to ignore tabs (default '${BLANKS_TABS_IGNORE_FILE}')"
  #yetus_add_option "--whitespace-eol-ignore-list=<list>" "comma-separated regex list of filenames (default '${BLANKS_EOL_IGNORE_LIST}')"
  #yetus_add_option "--whitespace-tabs-ignore-list=<list>" "comma-separated regex list of filenames (default '${BLANKS_TABS_IGNORE_LIST}')"
}

## @description  blanks parse args hook
## @audience     private
## @stability    evolving
## @replaceable  no
function blanks_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --blanks-eol-ignore-file=*)
        delete_parameter "${i}"
        BLANKS_EOL_IGNORE_FILE="${i#*=}"
      ;;
      --blanks-tabs-ignore-file=*)
        delete_parameter "${i}"
        BLANKS_TABS_IGNORE_FILE="${i#*=}"
      ;;
      # next two are for backward compatibility. We will remove them in the future
      --whitespace-eol-ignore-list=*)
        delete_parameter "${i}"
        BLANKS_EOL_IGNORE_LIST="${i#*=}"
      ;;
      --whitespace-tabs-ignore-list=*)
        delete_parameter "${i}"
        BLANKS_TABS_IGNORE_LIST="${i#*=}"
      ;;
    esac
  done
}

function blanks_linecomment_reporter
{
  declare file=$1
  shift
  declare comment=$*
  declare tmpfile="${PATCH_DIR}/wlr.$$.${RANDOM}"

  #shellcheck disable=SC2016
  "${AWK}" -F: -v msg="${comment}" \
    '{print $1":"$2":"msg}' \
    "${file}" \
    > "${tmpfile}"

  bugsystem_linecomments_queue "blanks" "${tmpfile}"
  rm "${tmpfile}"
}

function blanks_postcompile
{
  declare repostatus=$1
  declare count
  declare result=0
  declare -a eolignore
  declare -a tabsignore
  declare -a globalignore
  declare temp1
  declare temp2
  declare tmpfile1="${PATCH_DIR}/bl1.$$.${RANDOM}"
  declare tmpfile2="${PATCH_DIR}/bl2.$$.${RANDOM}"


  if [[ "${repostatus}" = branch ]]; then
    return 0
  fi

  big_console_header "Checking for blanks issues."
  start_clock

  pushd "${BASEDIR}" >/dev/null || return 1

  if [[ -f "${BLANKS_EOL_IGNORE_FILE}" ]]; then
    "${GREP}" -E -v -e '^(#|$|[[:blank:]])' "${BLANKS_EOL_IGNORE_FILE}" > "${tmpfile1}"
    eolignore=("${GREP}" "-v" "-E" "-f" "${tmpfile1}")
  elif [[ -n "${BLANKS_EOL_IGNORE_LIST}" ]]; then
    eolignore=("${GREP}" "-v")
    yetus_comma_to_array temp1 "${BLANKS_EOL_IGNORE_LIST}" ""
    for temp2 in "${temp1[@]}"; do
      eolignore+=("-e" "^$temp2:")
    done
  else
    eolignore=("cat")
  fi

  if [[ -f "${BLANKS_TABS_IGNORE_FILE}" ]]; then
    "${GREP}" -E -v -e '^(#|$|[[:blank:]])' "${BLANKS_TABS_IGNORE_FILE}" > "${tmpfile2}"
    tabsignore=("${GREP}" "-v" "-E" "-f" "${tmpfile2}")
  elif [[ -n "${BLANKS_TABS_IGNORE_LIST}" ]]; then
    tabsignore=("${GREP}" "-v")
    yetus_comma_to_array temp1 "${BLANKS_TABS_IGNORE_LIST}"
    for temp2 in "${temp1[@]}"; do
      tabsignore+=("-e" "^$temp2:")
    done
  else
    tabsignore=("cat")
  fi

  if [[ -n "${EXCLUDE_PATHS_FILE}" ]]; then
    globalignore=("${GREP}" "-v" "-E" "-f" "${EXCLUDE_PATHS_FILE}")
  else
    globalignore=("cat")
  fi

  case "${BUILDMODE}" in
    patch)
       "${GREP}" -E '[[:blank:]]$' \
         "${GITDIFFCONTENT}" \
        | "${globalignore[@]}" \
        | "${eolignore[@]}" > "${PATCH_DIR}/blanks-eol.txt"
      # shellcheck disable=SC2016,SC2086
      "${AWK}" '/\t/ {print $0}' \
          "${GITDIFFCONTENT}" \
        | "${globalignore[@]}" \
        | "${tabsignore[@]}" > "${PATCH_DIR}/blanks-tabs.txt"
    ;;
    full)
      "${GIT}" grep -n -I --extended-regexp '[[:blank:]]$' \
        | "${globalignore[@]}" \
        | "${eolignore[@]}" > "${PATCH_DIR}/blanks-eol.txt"
      # shellcheck disable=SC2086
      "${GIT}" grep -n -I $'\t' \
        | "${globalignore[@]}" \
        | "${tabsignore[@]}" > "${PATCH_DIR}/blanks-tabs.txt"
    ;;
  esac

  rm "${tmpfile2}" "${tmpfile2}" 2>/dev/null

  temp1=$(wc -l "${PATCH_DIR}/blanks-eol.txt")
  count=${temp1%% *}

  if [[ ${count} -gt 0 ]]; then
    if [[ "${BUILDMODE}" = full ]]; then
      add_vote_table_v2 -1 blanks \
        "@@BASE@@/blanks-eol.txt" \
        "${BUILDMODEMSG} has ${count} line(s) that end in blanks."
    else
      add_vote_table_v2 -1 blanks \
        "@@BASE@@/blanks-eol.txt" \
        "${BUILDMODEMSG} has ${count} line(s) that end in blanks. Use git apply --whitespace=fix <<patch_file>>. Refer https://git-scm.com/docs/git-apply"
    fi

    if [[ -n "${BUGLINECOMMENTS}" ]]; then
      blanks_linecomment_reporter "${PATCH_DIR}/blanks-eol.txt" "end of line"
    fi
    ((result=result+1))
  fi

  temp1=$(wc -l "${PATCH_DIR}/blanks-tabs.txt")
  count=${temp1%% *}

  if [[ ${count} -gt 0 ]]; then
    add_vote_table_v2 -1 blanks \
      "@@BASE@@/blanks-tabs.txt" \
      "${BUILDMODEMSG} ${count} line(s) with tabs."
    if [[ -n "${BUGLINECOMMENTS}" ]]; then
      blanks_linecomment_reporter "${PATCH_DIR}/blanks-tabs.txt" "tabs in line"
    fi
    ((result=result+1))
  fi

  popd >/dev/null || return 1

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi

  add_vote_table_v2 +1 blanks "" "${BUILDMODEMSG} has no blanks issues."
  return 0
}
