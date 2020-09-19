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

# there are no public APIs here
# SHELLDOC-IGNORE

add_bugsystem briefreport

BRIEFOUT_LONGRUNNING=3600

## @description  Usage info for briefreport plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function briefreport_usage
{
  yetus_add_option "--brief-report-file=<file>" "Save a very brief, plain text report to a file"
  yetus_add_option "--brief-report-long=<seconds>" "Time in seconds to use as long running subsystem threshold (Default: ${BRIEFOUT_LONGRUNNING})"

}

## @description  Option parsing for briefreport plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function briefreport_parse_args
{
  declare i
  declare fn

  for i in "$@"; do
    case ${i} in
      --brief-report-file=*)
        delete_parameter "${i}"
        fn=${i#*=}
      ;;
      --brief-report-long=*)
        delete_parameter "${i}"
        BRIEFOUT_LONGRUNNING=${i#*=}
      ;;
    esac
  done

  if [[ -n "${fn}" ]]; then
    if : > "${fn}"; then
      BRIEFOUT_REPORTFILE_ORIG="${fn}"
      BRIEFOUT_REPORTFILE=$(yetus_abs "${BRIEFOUT_REPORTFILE_ORIG}")
    else
      yetus_error "WARNING: cannot create brief text report file ${fn}. Ignoring."
    fi
  fi
}

## @description  Give access to the brief text report file in docker mode
## @audience     private
## @stability    evolving
## @replaceable  no
function briefreport_docker_support
{
  if [[ -n ${BRIEFOUT_REPORTFILE} ]]; then
    DOCKER_EXTRAARGS+=("-v" "${BRIEFOUT_REPORTFILE}:${DOCKER_WORK_DIR}/brief.txt")
    USER_PARAMS+=("--brief-report-file=${DOCKER_WORK_DIR}/brief.txt")
  fi
}

## @description  Only print selected information to a report file
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
## @return       0 on success
## @return       1 on failure
function briefreport_finalreport
{
  declare result=$1
  shift
  declare i=0
  declare ourstring
  declare vote
  declare subs
  declare ela
  declare version
  declare -a failed
  declare -a long
  declare -a filtered
  declare hours
  declare newtime
  declare fn
  declare logfile

  if [[ -z "${BRIEFOUT_REPORTFILE}" ]]; then
    return
  fi

  big_console_header "Writing Brief Text Report to ${BRIEFOUT_REPORTFILE}"

  if [[ ${result} == 0 ]]; then
    printf '\n\n+1 overall\n\n' > "${BRIEFOUT_REPORTFILE}"
  else
    printf '\n\n-1 overall\n\n' > "${BRIEFOUT_REPORTFILE}"
  fi

  i=0
  until [[ $i -ge ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\|)
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    logfile=$(echo "${ourstring}" | cut -f5 -d\| | tr -d ' ')

    if [[ "${vote}" = "H" ]]; then
       ((i=i+1))
       continue
     fi

    if [[ ${vote// } = -1 ]]; then
      failed=("${failed[@]}" "${subs}")
    fi

    if [[ ${vote// } = -0 ]]; then
      filtered=("${filtered[@]}" "${subs}")
    fi

    if [[ ${ela// } -gt ${BRIEFOUT_LONGRUNNING} ]]; then
      long=("${long[@]}" "${subs}")
    fi

    ((i=i+1))
  done

  #shellcheck disable=SC2207
  tmparray=($(printf '%s\n' "${failed[@]}" | sort -u))
  failed=("${tmparray[@]}")
  #shellcheck disable=SC2207
  tmparray=($(printf '%s\n' "${filtered[@]}" | sort -u))
  filtered=("${tmparray[@]}")
  #shellcheck disable=SC2207
  tmparray=($(printf '%s\n' "${long[@]}" | sort -u))
  long=("${tmparray[@]}")

  if [[ ${#failed[@]} -gt 0 ]]; then
    {
      echo ""
      echo "The following subsystems voted -1:"
      echo "    ${failed[*]}"
      echo ""
    } >> "${BRIEFOUT_REPORTFILE}"
  fi

  if [[ ${#filtered[@]} -gt 0 ]]; then
    {
      echo ""
      echo "The following subsystems voted -1 but"
      echo "were configured to be filtered/ignored:"
      echo "    ${filtered[*]}"
      echo ""
    } >> "${BRIEFOUT_REPORTFILE}"
  fi

  if [[ ${#long[@]} -gt 0 ]]; then
    {
      echo ""
      echo "The following subsystems are considered long running:"
      printf "(runtime bigger than "
      # We would use clock_display here, but we don't have the
      # restrictions that the vote_table has on size plus
      # we're almost certainly going to be measured in hours
      if [[ ${BRIEFOUT_LONGRUNNING} -ge 3600 ]]; then
        hours=$((BRIEFOUT_LONGRUNNING/3600))
        newtime=$((BRIEFOUT_LONGRUNNING-hours*3600))
        printf "%sh %02sm %02ss" ${hours} $((newtime/60)) $((newtime%60))
      else
        printf "%sm %02ss" $((BRIEFOUT_LONGRUNNING/60)) $((BRIEFOUT_LONGRUNNING%60))
      fi
      echo ")"
      echo "    ${long[*]}"
      echo ""
    } >> "${BRIEFOUT_REPORTFILE}"
  fi

  if [[ ${#TP_TEST_TABLE[@]} -gt 0 ]]; then
    {
      echo ""
      echo "Specific tests:"
    } >> "${BRIEFOUT_REPORTFILE}"

    i=0
    until [[ $i -gt ${#TP_TEST_TABLE[@]} ]]; do
      ourstring=$(echo "${TP_TEST_TABLE[${i}]}" | tr -s ' ')
      vote=$(echo "${ourstring}" | cut -f2 -d\|)
      subs=$(echo "${ourstring}"  | cut -f3 -d\|)
      {
        if [[ -n "${vote// }" ]]; then
          echo ""
          printf '   %s:\n' "${vote}"
          echo ""
          vote=""
        fi
        printf '      %s\n' "${subs}"
      } >> "${BRIEFOUT_REPORTFILE}"
      ((i=i+1))
    done
  fi

  if [[ -f "${BINDIR}/../VERSION" ]]; then
    version=$(cat "${BINDIR}/../VERSION")
  elif [[ -f "${BINDIR}/VERSION" ]]; then
    version=$(cat "${BINDIR}/VERSION")
  fi

  url=$(get_artifact_url)

  i=0
  until [[ $i -ge ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    logfile=$(echo "${ourstring}" | cut -f5 -d\| | tr -d ' ')

    if [[ -z "${logfile}" ]]; then
       ((i=i+1))
       continue
    fi

    logentry=$(echo "${logfile}" | "${SED}" -e "s,@@BASE@@,${PATCH_DIR},g")
    fn="${logentry// }"

    if [[ -f ${fn} ]]; then
      # shellcheck disable=SC2016
      size=$(du -sh "${fn}" | "${AWK}" '{print $1}')
    fi
    if [[ -n "${url}" ]]; then
      comment=$(echo "${logfile}" |"${SED}" -e "s,@@BASE@@,${url},g")
    fi
    {
      if [[ "${subs}" != "${vote}" ]]; then
        echo ""
        printf '   %s:\n' "${subs// }"
        echo ""
        vote=${subs}
      fi
      printf '      %s [%s]\n' "${comment}" "${size}"
    } >> "${BRIEFOUT_REPORTFILE}"

    ((i=i+1))
  done

  {
   echo ""
   echo "Powered by" "Apache Yetus ${version}   https://yetus.apache.org"
   echo ""
  } >> "${BRIEFOUT_REPORTFILE}"

}
