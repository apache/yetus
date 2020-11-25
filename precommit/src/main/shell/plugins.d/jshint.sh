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

add_test_type jshint

JSHINT_TIMER=0
JSHINT=${JSHINT:-$(command -v jshint 2>/dev/null)}

function jshint_usage
{
  yetus_add_option "--jshint-cmd=<file>" "The 'jshint' command to use (default: ${JSHINT})"
}

## @description  parse maven build tool args
## @replaceable  yes
## @audience     public
## @stability    stable
function jshint_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --jshint-cmd=*)
        delete_parameter "${i}"
        JSHINT=${i#*=}
      ;;
    esac
  done
}

function jshint_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.js$ ]] ||
     [[ ${filename} =~ .jshintignore ]] ||
     [[ ${filename} =~ .jshintrc ]]; then
    add_test jshint
  fi
}

function jshint_precheck
{
  if ! verify_command "jshint" "${JSHINT}"; then
    add_vote_table_v2 0 jshint "" "jshint was not available."
    delete_test jshint
  fi

  cat > "${PATCH_DIR}/jshintreporter.js" << EOF
"use strict";

module.exports = {
  reporter: function (res) {
    var len = res.length;
    var str = "";

    res.forEach(function (r) {
      var file = r.file;
      var err = r.error;

      str += file          + ":" +
             err.line      + ":" +
             err.character + ":" +
             err.code      + ":" +
             err.reason + "\\n";
    });

    if (str) {
      process.stdout.write(str + "\\n" + len + " error" +
        ((len === 1) ? "" : "s") + "\\n");
    }
  }
};
EOF
}

function jshint_logic
{
  declare repostatus=$1
  declare j
  declare full="${PATCH_DIR}/${repostatus}-jshint-result.full.txt"
  declare filter="${PATCH_DIR}/${repostatus}-jshint-result.txt"

  pushd "${BASEDIR}" >/dev/null || return 1
  "${JSHINT}" \
    --extract=auto \
    --reporter="${PATCH_DIR}/jshintreporter.js" \
    . \
    > "${full}"

  # pull out the files we care about
  for j in "${CHANGED_FILES[@]}"; do
    "${GREP}" "^${j}:" "${full}" \
      >> "${filter}"
  done

  popd > /dev/null || return 1
}

function jshint_preapply
{
  if ! verify_needed_test jshint; then
    return 0
  fi

  big_console_header "jshint plugin: ${PATCH_BRANCH}"

  start_clock

  jshint_logic branch

  # keep track of how much as elapsed for us already
  JSHINT_TIMER=$(stop_clock)
  return 0
}

## filename:line:character:code:error msg
function jshint_calcdiffs
{
  column_calcdiffs "$@"
}

function jshint_postapply
{
  declare version

  if ! verify_needed_test jshint; then
    return 0
  fi

  big_console_header "jshint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${JSHINT_TIMER}"

  jshint_logic patch

  version=$("${JSHINT}" --version 2>&1)
  add_version_data jshint "${version#*v}"

  root_postlog_compare \
    jshint \
    "${PATCH_DIR}/branch-jshint-result.txt" \
    "${PATCH_DIR}/patch-jshint-result.txt"
}

function jshint_precompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    jshint_preapply
  else
    jshint_postapply
  fi
}
