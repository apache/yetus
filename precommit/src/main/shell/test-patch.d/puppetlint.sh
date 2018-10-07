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

add_test_type puppetlint

PUPPETLINT_TIMER=0

PUPPETLINT=${PUPPETLINT:-$(command -v puppet-lint 2>/dev/null)}

# NOTE: Changing may mean using a different calcdiff algo
PUPPETLINT_LOGFORMAT='%{path}:%{line}:%{column}:%{KIND}:%{check}:%{message}'

function puppetlint_usage
{
  yetus_add_option "--puppetlint=<path>" "path to puppet-lint executable"
}

function puppetlint_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
    --puppetlint=*)
      PUPPETLINT=${i#*=}
    ;;
    esac
  done
}

function puppetlint_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ manifests/.*\.pp$ ]]; then
    add_test puppetlint
  fi
}

function puppetlint_precheck
{
  if ! verify_command puppetlint "${PUPPETLINT}"; then
    add_vote_table 0 puppetlint "puppetlint was not available."
    delete_test puppetlint
  fi
}

## @description  Wrapper to call column_calcdiffs
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function puppetlint_calcdiffs
{
  column_calcdiffs "$@"
}

function puppetlint_postcompile
{
  declare repostatus=$1
  declare result
  declare i
  declare numPrepatch
  declare numPostpatch
  declare diffPostpatch
  declare fixedpatch
  declare statstring

  if ! verify_needed_test puppetlint; then
    return 0
  fi

  big_console_header "puppetlint plugin"

  start_clock

  if [[ "${repostatus}" == "patch" && -n "${PUPPETLINT_TIMER}" ]]; then
    # add our previous elapsed to our new timer
    # by setting the clock back
    offset_clock "${PUPPETLINT_TIMER}"
  fi

  pushd "${BASEDIR}" >/dev/null || return 1
  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ manifests/.*\.pp$ && -f ${i} ]]; then
      ${PUPPETLINT} --log-format "${PUPPETLINT_LOGFORMAT}" "${i}" >> "${PATCH_DIR}/${repostatus}-puppetlint-result.txt"
      ((result=result+1))
    fi
  done
  popd >/dev/null || return 1

  if [[ "${repostatus}" == branch ]]; then
    PUPPETLINT_TIMER=$(stop_clock)
    return "${result}"
  fi

  # shellcheck disable=SC2016
  PUPPETLINT_VERSION=$(${PUPPETLINT} -v | ${AWK} '{print $NF}')

  add_footer_table puppetlint "v${PUPPETLINT_VERSION}"

  calcdiffs \
    "${PATCH_DIR}/branch-puppetlint-result.txt" \
    "${PATCH_DIR}/patch-puppetlint-result.txt" \
    puppetlint \
      > "${PATCH_DIR}/diff-patch-puppetlint.txt"
  diffPostpatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/diff-patch-puppetlint.txt")

  # shellcheck disable=SC2016
  numPrepatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/branch-puppetlint-result.txt")

  # shellcheck disable=SC2016
  numPostpatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/patch-puppetlint-result.txt")

  ((fixedpatch=numPrepatch-numPostpatch+diffPostpatch))

  statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

  if [[ ${diffPostpatch} -gt 0 ]] ; then
    add_vote_table -1 puppetlint "${BUILDMODEMSG} ${statstring}"
    add_footer_table puppetlint "@@BASE@@/diff-patch-puppetlint.txt"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
    add_vote_table +1 puppetlint "${BUILDMODEMSG} ${statstring}"
    return 0
  fi

  add_vote_table +1 puppetlint "There were no new puppetlint issues."
  return 0
}
