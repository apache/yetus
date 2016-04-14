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

add_bugsystem bugzilla

# personalities can override the following settings:
BUGZILLA_BASE_URL="https://bz.apache.org/bugzilla"

function bugzilla_usage
{
  yetus_add_option "--bugzilla-base-url=<url>" "The URL of the bugzilla server"
}

function bugzilla_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --bugzilla-base-url=*)
        BUGZILLA_BASE_URL=${i#*=}
      ;;
    esac
  done
}

function bugzilla_determine_issue
{
  declare input=$1

  if [[ ! "${input}" =~ ^BZ: ]]; then
    return 1
  fi

  if [[ -n "${BUGZILLA_ISSUE}" ]]; then
    return 0
  fi

  # shellcheck disable=SC2016
  BUGZILLA_ISSUE=$(echo "${input}" | cut -f2 -d: )

  # shellcheck disable=SC2034
  ISSUE=${input}
  add_footer_table "Bugzilla Issue" "${BUGZILLA_ISSUE}"
  return 0
}

## @description  Try to guess the branch being tested using a variety of heuristics
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success, with PATCH_BRANCH updated appropriately
## @return       1 on failure
function bugzilla_determine_branch
{
  return 1
}

function bugzilla_http_fetch
{
  declare input=$1
  declare output=$2

  if [[ -z "${BUGZILLA_BASE_URL}" ]]; then
    return 1
  fi

  ${CURL} --silent --fail \
          --output "${output}" \
          --location \
         "${BUGZILLA_BASE_URL}/${input}"
}


function bugzilla_locate_patch
{
  declare input=$1
  declare fileloc=$2
  declare relativeurl

  if [[ -z "${BUGZILLA_BASE_URL}" ]]; then
    return 1
  fi

  bugzilla_determine_issue "${input}"
  if [[ $? != 0 || -z "${BUGZILLA_ISSUE}" ]]; then
    return 1
  fi

  yetus_debug "bugzilla_locate_patch: trying ${BUGZILLA_BASE_URL}/show_bug.cgi?id=${BUGZILLA_ISSUE}"

  if [[ "${OFFLINE}" == true ]]; then
    yetus_debug "bugzilla_locate_patch: offline, skipping"
    return 1
  fi

  bugzilla_http_fetch "show_bug.cgi?id=${BUGZILLA_ISSUE}" "${PATCH_DIR}/bugzilla"

  if [[ $? != 0 ]]; then
    yetus_debug "bugzilla_locate_patch: not a Bugzilla."
    return 1
  fi

  #shellcheck disable=SC2016
  relativeurl=$(${AWK} '/action=diff/ && match($0,"attachment\.cgi.id=[0-9]*"){print substr($0,RSTART,RLENGTH)}' \
           "${PATCH_DIR}/bugzilla" | \
        tail -1)
  PATCHURL="${BUGZILLA_BASE_URL}${relativeurl}"
  #relativeurl="${relativeurl}&action=diff&context=patch&collapsed=&headers=1&format=raw"
  echo "${input} patch is being downloaded at $(date) from"
  echo "${PATCHURL}"
  add_footer_table "Bugzilla Patch URL" "${PATCHURL}"
  bugzilla_http_fetch "${relativeurl}" "${fileloc}"
  if [[ $? != 0 ]];then
    yetus_error "ERROR: ${input}/${PATCHURL} could not be downloaded."
    cleanup_and_exit 1
  fi
  return 0
}

## @description Write the contents of a file to Bugzilla
## @param     filename
## @stability stable
## @audience  public
function bugzilla_write_comment
{
  return 0
}

## @description  Print out the finished details to Bugzilla
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function bugzilla_finalreport
{
  return 0
}
