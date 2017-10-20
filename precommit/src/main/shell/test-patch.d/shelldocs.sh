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

add_test_type shelldocs

SHELLDOCS_TIMER=0

SHELLDOCS=${SHELLDOCS}
if [[ -z ${SHELLDOCS} ]]; then
  for shelldocsexec in "${BINDIR}/shelldocs" "${BINDIR}/../shelldocs/shelldocs.py"; do
    if [[ -f ${shelldocsexec} && -x ${shelldocsexec} ]]; then
      SHELLDOCS=${shelldocsexec}
      break
    fi
  done
fi

SHELLDOCS_SPECIFICFILES=""

function shelldocs_usage
{
  yetus_add_option "--shelldocs=<path>" "path to shelldocs executable"
}

function shelldocs_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
    --shelldocs=*)
      SHELLDOCS=${i#*=}
    ;;
    esac
  done
}

# if it ends in an explicit .sh, then this is shell code.
# if it doesn't have an extension, we assume it is shell code too
function shelldocs_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.sh$ ]]; then
    add_test shelldocs
    SHELLDOCS_SPECIFICFILES="${SHELLDOCS_SPECIFICFILES} ./${filename}"
  fi

  if [[ ! ${filename} =~ \. ]]; then
    add_test shelldocs
  fi
}

function shelldocs_precheck
{
  if ! verify_command "shelldocs" "${SHELLDOCS}"; then
    add_vote_table 0 shelldocs "Shelldocs was not available."
    delete_test shelldocs
  fi
}

function shelldocs_private_findbash
{
  declare i
  declare value
  declare list

  while read -r line; do
    value=$(find "${line}" ! -name '*.cmd' -type f \
      | ${GREP} -E -v '(.orig$|.rej$)')

    for i in ${value}; do
      if [[ ! ${i} =~ \.sh(\.|$)
          && ! $(head -n 1 "${i}") =~ ^#! ]]; then
        yetus_debug "Shelldocs skipped: ${i}"
        continue
      fi
      list="${list} ${i}"
    done
  done < <(find . -type d -name bin -o -type d -name sbin -o -type d -name scripts -o -type d -name libexec -o -type d -name shellprofile.d)
  # shellcheck disable=SC2086
  echo ${list} ${SHELLDOCS_SPECIFICFILES} | tr ' ' '\n' | sort -u
}

function shelldocs_preapply
{
  declare i

  if ! verify_needed_test shelldocs; then
    return 0
  fi

  big_console_header "shelldocs plugin: ${PATCH_BRANCH}"

  start_clock

  echo "Running shelldocs against all identifiable shell scripts"
  pushd "${BASEDIR}" >/dev/null
  for i in $(shelldocs_private_findbash); do
    if [[ -f ${i} ]]; then
      ${SHELLDOCS} --input "${i}" --lint >> "${PATCH_DIR}/branch-shelldocs-result.txt"
    fi
  done
  popd > /dev/null

  # keep track of how much as elapsed for us already
  SHELLDOCS_TIMER=$(stop_clock)
  return 0
}

function shelldocs_postapply
{
  declare i
  declare numPrepatch
  declare numPostpatch
  declare diffPostpatch
  declare fixedpatch
  declare statstring

  if ! verify_needed_test shelldocs; then
    return 0
  fi

  big_console_header "shelldocs plugin: ${BUILDMODE}"

  start_clock

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${SHELLDOCS_TIMER}"

  echo "Running shelldocs against all identifiable shell scripts"
  # we re-check this in case one has been added
  for i in $(shelldocs_private_findbash); do
    if [[ -f ${i} ]]; then
      ${SHELLDOCS} --input "${i}" --lint >> "${PATCH_DIR}/patch-shelldocs-result.txt"
    fi
  done

  calcdiffs \
    "${PATCH_DIR}/branch-shelldocs-result.txt" \
    "${PATCH_DIR}/patch-shelldocs-result.txt" \
    shelldocs \
      > "${PATCH_DIR}/diff-patch-shelldocs.txt"

  # shellcheck disable=SC2016
  numPrepatch=$(wc -l "${PATCH_DIR}/branch-shelldocs-result.txt" | ${AWK} '{print $1}')

  # shellcheck disable=SC2016
  numPostpatch=$(wc -l "${PATCH_DIR}/patch-shelldocs-result.txt" | ${AWK} '{print $1}')

  # shellcheck disable=SC2016
  diffPostpatch=$(wc -l "${PATCH_DIR}/diff-patch-shelldocs.txt" | ${AWK} '{print $1}')

  ((fixedpatch=numPrepatch-numPostpatch+diffPostpatch))

  statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

  if [[ ${diffPostpatch} -gt 0 ]] ; then
    add_vote_table -1 shelldocs "${BUILDMODEMSG} ${statstring}"
    add_footer_table shelldocs "@@BASE@@/diff-patch-shelldocs.txt"
    bugsystem_linecomments "shelldocs" "${PATCH_DIR}/diff-patch-shelldocs.txt"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
    add_vote_table +1 shelldocs "${BUILDMODEMSG} ${statstring}"
    return 0
  fi

  add_vote_table +1 shelldocs "There were no new shelldocs issues."
  return 0
}

function shelldocs_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    shelldocs_preapply
  else
    shelldocs_postapply
  fi
}
