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

add_test_type rubocop

RUBOCOP_TIMER=0

RUBOCOP=${RUBOCOP:-$(which rubocop 2>/dev/null)}

function rubocop_usage
{
  yetus_add_option "--rubocop=<path>" "path to rubocop executable"
}

function rubocop_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
    --rubocop=*)
      RUBOCOP=${i#*=}
    ;;
    esac
  done
}

function rubocop_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.rb$ ]]; then
    add_test rubocop
  fi
}

function rubocop_precheck
{
  if ! verify_command rubocop "${RUBOCOP}"; then
    add_vote_table 0 rubocop "rubocop was not available."
    delete_test rubocop
  fi
}


function rubocop_preapply
{
  local i

  if ! verify_needed_test rubocop; then
    return 0
  fi

  big_console_header "rubocop plugin: ${PATCH_BRANCH}"

  start_clock

  echo "Running rubocop against identified ruby scripts."
  pushd "${BASEDIR}" >/dev/null
  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.rb$ && -f ${i} ]]; then
      ${RUBOCOP} -f e "${i}" | ${AWK} '!/[0-9]* files? inspected/' >> "${PATCH_DIR}/branch-rubocop-result.txt"
    fi
  done
  popd >/dev/null
  # keep track of how much as elapsed for us already
  RUBOCOP_TIMER=$(stop_clock)
  return 0
}

## @description  Wrapper to call column_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function rubocop_calcdiffs
{
  column_calcdiffs "$@"
}

function rubocop_postapply
{
  declare i
  declare numPrepatch
  declare numPostpatch
  declare diffPostpatch
  declare fixedpatch
  declare statstring

  if ! verify_needed_test rubocop; then
    return 0
  fi

  big_console_header "rubocop plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${RUBOCOP_TIMER}"

  echo "Running rubocop against identified ruby scripts."
  # we re-check this in case one has been added
  pushd "${BASEDIR}" >/dev/null
  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.rb$ && -f ${i} ]]; then
      ${RUBOCOP} -f e "${i}" | ${AWK} '!/[0-9]* files? inspected/' >> "${PATCH_DIR}/patch-rubocop-result.txt"
    fi
  done
  popd >/dev/null

  # shellcheck disable=SC2016
  RUBOCOP_VERSION=$(${RUBOCOP} -v | ${AWK} '{print $NF}')
  add_footer_table rubocop "v${RUBOCOP_VERSION}"

  calcdiffs \
    "${PATCH_DIR}/branch-rubocop-result.txt" \
    "${PATCH_DIR}/patch-rubocop-result.txt" \
    rubocop \
      > "${PATCH_DIR}/diff-patch-rubocop.txt"
  diffPostpatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/diff-patch-rubocop.txt")

  # shellcheck disable=SC2016
  numPrepatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/branch-rubocop-result.txt")

  # shellcheck disable=SC2016
  numPostpatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/patch-rubocop-result.txt")

  ((fixedpatch=numPrepatch-numPostpatch+diffPostpatch))

  statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

  if [[ ${diffPostpatch} -gt 0 ]] ; then
    add_vote_table -1 rubocop "${BUILDMODEMSG} ${statstring}"
    add_footer_table rubocop "@@BASE@@/diff-patch-rubocop.txt"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
    add_vote_table +1 rubocop "${BUILDMODEMSG} ${statstring}"
    return 0
  fi

  add_vote_table +1 rubocop "There were no new rubocop issues."
  return 0
}

function rubocop_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    rubocop_preapply
  else
    rubocop_postapply
  fi
}
