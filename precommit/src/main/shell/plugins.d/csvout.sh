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

add_bugsystem csvout

## @description  Usage info for csvout plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function csvout_usage
{
  yetus_add_option "--csv-report-file=<file>" "Save the final report to an CSV-formated file"
}

## @description  Option parsing for csvout plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function csvout_parse_args
{
  declare i
  declare fn

  for i in "$@"; do
    case ${i} in
      --csv-report-file=*)
        delete_parameter "${i}"
        fn=${i#*=}
      ;;
    esac
  done

  if [[ -n "${fn}" ]]; then
    if : > "${fn}"; then
      CSVOUT_REPORTFILE_ORIG="${fn}"
      CSVOUT_REPORTFILE=$(yetus_abs "${CSVOUT_REPORTFILE_ORIG}")
    else
      yetus_error "WARNING: cannot create CSV report file ${fn}. Ignoring."
    fi
  fi
}

## @description  Give access to the CSV report file in docker mode
## @audience     private
## @stability    evolving
## @replaceable  no
function csvout_docker_support
{
  # if for some reason the report file is in PATCH_DIR, then if
  # PATCH_DIR gets cleaned out we lose access to the file on the 'outside'
  # so we put it into the workdir which never gets cleaned.

  if [[ -n ${CSVOUT_REPORTFILE} ]]; then
    DOCKER_EXTRAARGS+=("-v" "${CSVOUT_REPORTFILE}:${DOCKER_WORK_DIR}/report.csv")
    USER_PARAMS+=("--csv-report-file=${DOCKER_WORK_DIR}/report.csv")
  fi
}

## @description  Write out an CSV version of the final report to a file
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function csvout_report_writer
{
  declare result=$1
  shift
  declare i=0
  declare ourstring
  declare vote
  declare subs
  declare ela
  declare comment

  if [[ -z "${CSVOUT_REPORTFILE}" ]]; then
    return
  fi

  : >  "${CSVOUT_REPORTFILE}"
  i=0
  until [[ $i -ge ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[i]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\|)
    vote=$(yetus_trim "${vote}")
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    subs=$(yetus_trim "${subs}")
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    ela=$(yetus_trim "${ela}")
    comment=$(echo "${ourstring}"  | cut -f6 -d\|)
    comment=$(yetus_trim "${comment}")

    echo "${vote},${subs},${ela},${comment}" >> "${CSVOUT_REPORTFILE}"
    ((i=i+1))
  done
}

## @description  Write out the CSV version of the final report to a file
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function csvout_finalreport
{
  declare result=$1

  if [[ -z "${CSVOUT_REPORTFILE}" ]]; then
    return
  fi

  big_console_header "Writing CSV to ${CSVOUT_REPORTFILE}"

  csvout_report_writer "${result}" "${CSVOUT_REPORTFILE}"
}
