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

WHITESPACE_EOL_IGNORE_LIST=
WHITESPACE_TABS_IGNORE_LIST='.*Makefile.*','.*\.go'

add_test_type whitespace

## @description  whitespace usage hook
## @audience     private
## @stability    evolving
## @replaceable  no
function whitespace_usage
{
  yetus_add_option "--whitespace-eol-ignore-list=<list>" "comma-separated regex list of filenames (default '${WHITESPACE_EOL_IGNORE_LIST}')"
  yetus_add_option "--whitespace-tabs-ignore-list=<list>" "comma-separated regex list of filenames (default '${WHITESPACE_TABS_IGNORE_LIST}')"
}

## @description  whitespace parse args hook
## @audience     private
## @stability    evolving
## @replaceable  no
function whitespace_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --whitespace-eol-ignore-list=*)
        WHITESPACE_EOL_IGNORE_LIST="${i#*=}"
      ;;
      --whitespace-tabs-ignore-list=*)
        WHITESPACE_TABS_IGNORE_LIST="${i#*=}"
      ;;
    esac
  done
}

function whitespace_linecomment_reporter
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

  bugsystem_linecomments_queue "whitespace" "${tmpfile}"
  rm "${tmpfile}"
}

function whitespace_postcompile
{
  declare repostatus=$1
  declare count
  declare result=0
  declare -a eolignore
  declare -a tabsignore
  declare temp1
  declare temp2

  if [[ "${repostatus}" = branch ]]; then
    return 0
  fi

  big_console_header "Checking for whitespace issues."
  start_clock

  pushd "${BASEDIR}" >/dev/null || return 1

  if [[ -n "${WHITESPACE_EOL_IGNORE_LIST}" ]]; then
    eolignore=("${GREP}" "-v")
    yetus_comma_to_array temp1 "${WHITESPACE_EOL_IGNORE_LIST}"
    for temp2 in "${temp1[@]}"; do
      eolignore+=("-e" "^$temp2:")
    done
  else
    eolignore=("cat")
  fi

  if [[ -n "${WHITESPACE_TABS_IGNORE_LIST}" ]]; then
    tabsignore=("${GREP}" "-v")
    yetus_comma_to_array temp1 "${WHITESPACE_TABS_IGNORE_LIST}"
    for temp2 in "${temp1[@]}"; do
      tabsignore+=("-e" "^$temp2:")
    done
  else
    tabsignore=("cat")
  fi

  case "${BUILDMODE}" in
    patch)
       "${GREP}" -E '[[:blank:]]$' \
         "${GITDIFFCONTENT}" \
        | "${eolignore[@]}" > "${PATCH_DIR}/whitespace-eol.txt"
      # shellcheck disable=SC2016,SC2086
      "${AWK}" '/\t/ {print $0}' \
          "${GITDIFFCONTENT}" \
        | "${tabsignore[@]}" > "${PATCH_DIR}/whitespace-tabs.txt"
    ;;
    full)
      "${GIT}" grep -n -I --extended-regexp '[[:blank:]]$' \
        | "${eolignore[@]}" > "${PATCH_DIR}/whitespace-eol.txt"
      # shellcheck disable=SC2086
      "${GIT}" grep -n -I $'\t' \
        | "${tabsignore[@]}" > "${PATCH_DIR}/whitespace-tabs.txt"
    ;;
  esac

  # shellcheck disable=SC2016
  count=$(wc -l "${PATCH_DIR}/whitespace-eol.txt" | ${AWK} '{print $1}')

  if [[ ${count} -gt 0 ]]; then
    if [[ "${BUILDMODE}" = full ]]; then
      add_vote_table -1 whitespace "${BUILDMODEMSG} has ${count} line(s) that end in whitespace."
    else
      add_vote_table -1 whitespace \
        "${BUILDMODEMSG} has ${count} line(s) that end in whitespace. Use git apply --whitespace=fix <<patch_file>>. Refer https://git-scm.com/docs/git-apply"
    fi

    if [[ -n "${BUGLINECOMMENTS}" ]]; then
      whitespace_linecomment_reporter "${PATCH_DIR}/whitespace-eol.txt" "end of line"
    fi
    add_footer_table whitespace "@@BASE@@/whitespace-eol.txt"
    ((result=result+1))
  fi

  # shellcheck disable=SC2016
  count=$(wc -l "${PATCH_DIR}/whitespace-tabs.txt" | ${AWK} '{print $1}')

  if [[ ${count} -gt 0 ]]; then
    add_vote_table -1 whitespace "${BUILDMODEMSG} ${count}"\
      " line(s) with tabs."
    add_footer_table whitespace "@@BASE@@/whitespace-tabs.txt"
    if [[ -n "${BUGLINECOMMENTS}" ]]; then
      whitespace_linecomment_reporter "${PATCH_DIR}/whitespace-tabs.txt" "tabs in line"
    fi
    ((result=result+1))
  fi

  popd >/dev/null || return 1

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi

  add_vote_table +1 whitespace "${BUILDMODEMSG} has no whitespace issues."
  return 0
}
