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

WHITESPACE_EOL_IGNORE_LIST=
WHITESPACE_TABS_IGNORE_LIST=Makefile

add_test_type whitespace

## @description  whitespace usage hook
## @audience     private
## @stability    evolving
## @replaceable  no
function whitespace_usage
{
  yetus_add_option "--whitespace-eol-ignore-list=<list>" "comma-separated regex list of filenames to ignore on checking whitespaces at EOL (default '${WHITESPACE_EOL_IGNORE_LIST}')"
  yetus_add_option "--whitespace-tabs-ignore-list=<list>" "comma-separated regex list of filenames to ignore on checking tabs in a file (default '${WHITESPACE_TABS_IGNORE_LIST}')"
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
        yetus_comma_to_array WHITESPACE_EOL_IGNORE_LIST "${i#*=}"
      ;;
      --whitespace-tabs-ignore-list=*)
        yetus_comma_to_array WHITESPACE_TABS_IGNORE_LIST "${i#*=}"
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

  while read -r line; do
    {
      # shellcheck disable=SC2086
      printf "%s" "$(echo ${line} | cut -f1-2 -d:)"
      echo "${comment}"
    } >> "${tmpfile}"
  done < "${file}"

  bugsystem_linecomments "whitespace:" "${tmpfile}"
  rm "${tmpfile}"
}

function whitespace_postcompile
{
  declare repostatus=$1
  declare count
  declare result=0
  declare eolignore
  declare tabsignore

  if [[ "${repostatus}" = branch ]]; then
    return 0
  fi

  big_console_header "Checking for whitespace issues."
  start_clock

  pushd "${BASEDIR}" >/dev/null

  eolignore=$(printf -- "-e ^%s: " "${WHITESPACE_EOL_IGNORE_LIST[@]}")
  tabsignore=$(printf -- "-e ^%s: " "${WHITESPACE_TABS_IGNORE_LIST[@]}")

  case "${BUILDMODE}" in
    patch)
      # shellcheck disable=SC2016,SC2086
      ${AWK} '/\t/ {print $0}' \
          "${GITDIFFCONTENT}" \
        | ${GREP} -v ${tabsignore} >> "${PATCH_DIR}/whitespace-tabs.txt"

      # shellcheck disable=SC2086
       ${GREP} -E '[[:blank:]]$' \
         "${GITDIFFCONTENT}" \
        | ${GREP} -v ${eolignore} >> "${PATCH_DIR}/whitespace-eol.txt"
    ;;
    full)
      # shellcheck disable=SC2086
      ${GIT} grep -n -I --extended-regexp '[[:blank:]]$' \
        | "${GREP}" -v ${eolignore} \
         >> "${PATCH_DIR}/whitespace-eol.txt"
      # shellcheck disable=SC2086
      ${GIT} grep -n -I $'\t' \
        | "${GREP}" -v ${tabsignore} \
        >> "${PATCH_DIR}/whitespace-tabs.txt"
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

    whitespace_linecomment_reporter "${PATCH_DIR}/whitespace-eol.txt" "end of line"
    add_footer_table whitespace "@@BASE@@/whitespace-eol.txt"
    ((result=result+1))
  fi

  # shellcheck disable=SC2016
  count=$(wc -l "${PATCH_DIR}/whitespace-tabs.txt" | ${AWK} '{print $1}')

  if [[ ${count} -gt 0 ]]; then
    add_vote_table -1 whitespace "${BUILDMODEMSG} ${count}"\
      " line(s) with tabs."
    add_footer_table whitespace "@@BASE@@/whitespace-tabs.txt"
    whitespace_linecomment_reporter "${PATCH_DIR}/whitespace-tabs.txt" "tabs in line"
    ((result=result+1))
  fi

  if [[ ${result} -gt 0 ]]; then
    popd >/dev/null
    return 1
  fi

  popd >/dev/null
  add_vote_table +1 whitespace "${BUILDMODEMSG} has no whitespace issues."
  return 0
}
