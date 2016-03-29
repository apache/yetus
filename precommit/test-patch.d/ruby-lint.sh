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

add_test_type ruby_lint

RUBY_LINT_TIMER=0

RUBY_LINT=${RUBY_LINT:-$(which ruby-lint 2>/dev/null)}

function ruby_lint_usage
{
  yetus_add_option "--ruby-lint=<path>" "path to ruby-lint executable"
}

function ruby_lint_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
    --ruby-lint=*)
      RUBY_LINT=${i#*=}
    ;;
    esac
  done
}

function ruby_lint_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.rb$ ]]; then
    add_test ruby_lint
  fi
}

function ruby_lint_precheck
{
  if ! verify_command "Ruby-lint" "${RUBY_LINT}"; then
    add_vote_table 0 ruby-lint "Ruby-lint was not available."
    delete_test ruby_lint
  fi
}

function ruby_lint_preapply
{
  local i

  if ! verify_needed_test ruby_lint; then
    return 0
  fi

  big_console_header "ruby-lint plugin: ${PATCH_BRANCH}"

  start_clock

  echo "Running ruby-lint against identified ruby scripts."
  pushd "${BASEDIR}" >/dev/null
  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.rb$ && -f ${i} ]]; then
      ${RUBY_LINT} -p syntastic "${i}" | sort -t : -k 1,1 -k 3,3n -k 4,4n >> "${PATCH_DIR}/branch-ruby-lint-result.txt"
    fi
  done
  popd >/dev/null
  # keep track of how much as elapsed for us already
  RUBY_LINT_TIMER=$(stop_clock)
  return 0
}

## @description  Calculate the differences between the specified files
## @description  using columns and output it to stdout
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function ruby_lint_calcdiffs
{
  declare orig=$1
  declare new=$2
  declare tmp=${PATCH_DIR}/pl.$$.${RANDOM}
  declare j

  # first, strip filenames:line:
  # this keeps column: in an attempt to increase
  # accuracy in case of multiple, repeated errors
  # since the column number shouldn't change
  # if the line of code hasn't been touched
  # shellcheck disable=SC2016
  cut -f4- -d: "${orig}" > "${tmp}.branch"
  # shellcheck disable=SC2016
  cut -f4- -d: "${new}" > "${tmp}.patch"

  # compare the errors, generating a string of line
  # numbers. Sorry portability: GNU diff makes this too easy
  ${DIFF} --unchanged-line-format="" \
     --old-line-format="" \
     --new-line-format="%dn " \
     "${tmp}.branch" \
     "${tmp}.patch" > "${tmp}.lined"

  # now, pull out those lines of the raw output
  # shellcheck disable=SC2013
  for j in $(cat "${tmp}.lined"); do
    # shellcheck disable=SC2086
    head -${j} "${new}" | tail -1
  done

  rm "${tmp}.branch" "${tmp}.patch" "${tmp}.lined" 2>/dev/null
}

function ruby_lint_postapply
{
  declare i
  declare numPrepatch
  declare numPostpatch
  declare diffPostpatch
  declare fixedpatch
  declare statstring

  if ! verify_needed_test ruby_lint; then
    return 0
  fi

  big_console_header "ruby-lint plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${RUBY_LINT_TIMER}"

  echo "Running ruby-lint against identified ruby scripts."
  # we re-check this in case one has been added
  pushd "${BASEDIR}" >/dev/null
  for i in "${CHANGED_FILES[@]}"; do
    if [[ ${i} =~ \.rb$ && -f ${i} ]]; then
      ${RUBY_LINT} -p syntastic "${i}" | sort -t : -k 1,1 -k 3,3n -k 4,4n >> "${PATCH_DIR}/patch-ruby-lint-result.txt"
    fi
  done
  popd >/dev/null

  # shellcheck disable=SC2016
  RUBY_LINT_VERSION=$(${RUBY_LINT} -v | ${AWK} '{print $2}')
  add_footer_table ruby-lint "${RUBY_LINT_VERSION}"

  calcdiffs \
    "${PATCH_DIR}/branch-ruby-lint-result.txt" \
    "${PATCH_DIR}/patch-ruby-lint-result.txt" \
      ruby_lint \
      > "${PATCH_DIR}/diff-patch-ruby-lint.txt"
  diffPostpatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/diff-patch-ruby-lint.txt")

  # shellcheck disable=SC2016
  numPrepatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/branch-ruby-lint-result.txt")

  # shellcheck disable=SC2016
  numPostpatch=$(${AWK} -F: 'BEGIN {sum=0} 4<NF {sum+=1} END {print sum}' "${PATCH_DIR}/patch-ruby-lint-result.txt")

  ((fixedpatch=numPrepatch-numPostpatch+diffPostpatch))

  statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

  if [[ ${diffPostpatch} -gt 0 ]] ; then
    add_vote_table -1 ruby-lint "${BUILDMODEMSG} ${statstring}"
    add_footer_table ruby-lint "@@BASE@@/diff-patch-ruby-lint.txt"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
    add_vote_table +1 ruby-lint "${BUILDMODEMSG} ${statstring}"
    return 0
  fi

  add_vote_table +1 ruby-lint "There were no new ruby-lint issues."
  return 0
}

function ruby_lint_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    ruby_lint_preapply
  else
    ruby_lint_postapply
  fi
}
