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

add_test_type perlcritic

PERLCRITIC_TIMER=0

PERLCRITIC=${PERLCRITIC:-$(command -v perlcritic 2>/dev/null)}

function perlcritic_usage
{
  yetus_add_option "--perlcritic=<file>" "path to perlcritic executable"
}

function perlcritic_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
    --perlcritic=*)
      delete_parameter "${i}"
      PERLCRITIC=${i#*=}
    ;;
    esac
  done
}

function perlcritic_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.p[lm]$ ]]; then
    add_test perlcritic
  fi
}

function perlcritic_precheck
{
  if ! verify_command "Perl::Critic" "${PERLCRITIC}"; then
    add_vote_table_v2 0 perlcritic "" "Perl::Critic was not available."
    delete_test perlcritic
  fi
}


function perlcritic_preapply
{
  local i

  if ! verify_needed_test perlcritic; then
    return 0
  fi

  big_console_header "Perl::Critic plugin: ${PATCH_BRANCH}"

  start_clock

  echo "Running perlcritic against identified perl scripts/modules."
  pushd "${BASEDIR}" >/dev/null || return 1
  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.p[lm]$ && -f ${i} ]]; then
      "${PERLCRITIC}" --verbose 1 --nocolor "${i}" 2>/dev/null >> "${PATCH_DIR}/branch-perlcritic-result.txt"
    fi
  done
  popd >/dev/null || return 1
  # keep track of how much as elapsed for us already
  PERLCRITIC_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call column_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function perlcritic_calcdiffs
{
  column_calcdiffs "$@"
}

function perlcritic_postapply
{
  declare i

  if ! verify_needed_test perlcritic; then
    return 0
  fi

  big_console_header "Perl::Critic plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${PERLCRITIC_TIMER}"

  echo "Running perlcritic against identified perl scripts/modules."
  # we re-check this in case one has been added
  pushd "${BASEDIR}" >/dev/null || return 1
  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.p[lm]$ && -f ${i} ]]; then
      "${PERLCRITIC}" --verbose 1 --nocolor "${i}" 2>/dev/null >> "${PATCH_DIR}/patch-perlcritic-result.txt"
    fi
  done
  popd >/dev/null || return 1

  PERLCRITIC_VERSION=$(${PERLCRITIC} --version 2>/dev/null)
  add_version_data perlcritic "${PERLCRITIC_VERSION}"

  root_postlog_compare \
    perlcritic \
    "${PATCH_DIR}/branch-perlcritic-result.txt" \
    "${PATCH_DIR}/patch-perlcritic-result.txt"
}

function perlcritic_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    perlcritic_preapply
  else
    perlcritic_postapply
  fi
}
