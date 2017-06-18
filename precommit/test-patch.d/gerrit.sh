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

# this bug system handles GERRIT.
# Personalities can override the following variables:

add_bugsystem gerrit



function gerrit_usage
{
  yetus_add_option "--gerrit-password=<pw>" "The password for the 'jira' command"
  yetus_add_option "--gerrit-user=<user>" "The user for the 'jira' command"
  yetus_add_option "--gerrit-location=<hostname>" "The URL of gerrit"
  yetus_add_option "--gerrit-port=<port>" "The port of gerrit"
  yetus_add_option "--gerrit-patchset=<patchset>" "The patchset being tested"
  yetus_add_option "--gerrit-changenumber=<changenumber>" "The change Number of the change"
}

function gerrit_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --gerrit-password=*)
        GERRIT_PASSWD=${i#*=}
      ;;
      --gerrit-user=*)
        GERRIT_USER=${i#*=}
      ;;
      --gerrit)
        GERRIT=true
        yetus_debug "Setting Gerrit to TRUE"
      ;;
      --gerrit-location=*)
        GERRIT_ADDRESS=${i#*=}
        yetus_debug "Gerrit Address is ${GERRIT_ADDRESS}"
      ;;
      --gerrit-port=*)
        GERRIT_PORT=${i#*=}
        yetus_debug "Gerrit Port is ${GERRIT_PORT}"
      ;;
      --gerrit-patchset=*)
        GERRIT_PATCHSET_NUMBER=${i#*=}
        yetus_debug "Gerrit Patchset is ${GERRIT_PATCHSET_NUMBER}"
      ;;
      --gerrit-changenumber=*)
        GERRIT_CHANGENUMBER=${i#*=}
        yetus_debug "Gerrit Change Number is ${GERRIT_CHANGENUMBER}"
      ;;
    esac
  done
}

function gerrit_locate_patch
{

  declare input=$1
  declare output=$2
  declare gerritauth

  if [[ "${OFFLINE}" == true ]]; then
    yetus_debug "gerrit_locate_patch: offline, skipping"
    return 1
  fi

  yetus_debug "The changeID is : ${input}"
  yetus_debug "Gerrit URL : ${GERRIT_ADDRESS}"
  yetus_debug "Storing the patch at : ${output}"

  #create URL to download from. Always use the current revision. Gets the latest
  GERRIT_REVISION=${GERRIT_PATCHSET_NUMBER:-current}
  URL="https://${GERRIT_ADDRESS}/changes/${input}/revisions/${GERRIT_REVISION}/patch?zip"
  yetus_debug "URL to download from ${URL}"

  # the actual patch file
  ${CURL} --silent --fail \
          --output "${output}.zip" \
          "${URL}"
  if [[ $? != 0 ]]; then
    yetus_debug "gerrit_locate_patch: not a gerrit changeID"
    return 1
  fi

  unzip ${output}.zip -d ${output}-zip
  mv -v ${output}-zip/*.diff ${output}

  return 0
}

function gerrit_finalreport
{
  declare result=$1
  declare i
  declare commentfile=${PATCH_DIR}/gerritcommentfile
  declare comment
  declare vote
  declare ourstring
  declare ela
  declare subs
  declare comment
  declare calctime

  big_console_header "Adding comment to Gerrit"

  if [[ "${OFFLINE}" == true ]]; then
      yetus_debug "gerrit_update_review: offline, skipping"
      return 1
  fi

  rm "${commentfile}" 2>/dev/null

  echo "'" >>  "${commentfile}"

  if [[ ${result} == 0 ]]; then
    echo "| (/) *+1 overall* |" >> "${commentfile}"
    overall=+1
  else
    echo "| (x) *-1 overall* |" >> "${commentfile}"
    overall=-1
  fi

  printf "\n\n" >>  "${commentfile}"

  i=0
  until [[ $i -eq ${#TP_HEADER[@]} ]]; do
    printf "%s\n" "${TP_HEADER[${i}]}" >> "${commentfile}"
    ((i=i+1))
  done

  echo "|| Vote || Subsystem || Runtime || Comment ||" >> "${commentfile}"

  i=0
  until [[ $i -eq ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\| | tr -d ' ')
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    calctime=$(clock_display "${ela}")
    comment=$(echo "${ourstring}"  | cut -f5 -d\|)

    printf "| %s | %s | %s | %s |\n" \
      "${vote}"  "${subs}" "${calctime}" "${comment}" \
      >> "${commentfile}"
    ((i=i+1))
  done

  if [[ ${#TP_TEST_TABLE[@]} -gt 0 ]]; then
    printf "\n\n" >>  "${commentfile}"

    echo "|| Reason || Tests ||" >>  "${commentfile}"
    i=0
    until [[ $i -eq ${#TP_TEST_TABLE[@]} ]]; do
      printf "%s\n" "${TP_TEST_TABLE[${i}]}" >> "${commentfile}"
      ((i=i+1))
    done
  fi

  { echo "\\\\" ; echo "\\\\"; } >>  "${commentfile}"

  echo "|| Subsystem || Report/Notes ||" >> "${commentfile}"
  i=0
  until [[ $i -eq ${#TP_FOOTER_TABLE[@]} ]]; do
    comment=$(echo "${TP_FOOTER_TABLE[${i}]}" |
              ${SED} -e "s,@@BASE@@,${BUILD_URL}${BUILD_URL_ARTIFACTS},g")
    printf "%s\n" "${comment}" >> "${commentfile}"
    ((i=i+1))
  done

  printf "\n\nThis message was automatically generated.\n\n" >> "${commentfile}"

  echo  "'" >> "${commentfile}"

  yetus_debug "Gerrit comment placed at : ${commentfile}"
  yetus_debug "Hostname : ${GERRIT_ADDRESS} and Port Number : ${GERRIT_PORT}"

  if [[ -z ${GERRIT_CHANGENUMBER} ]]; then
    yetus_debug "Gerrit change number is needed for posting comment."
    return 0
  fi
  if [[ -z ${GERRIT_PATCHSET_NUMBER} ]]; then
    yetus_debug "Gerrit patchset number is needed for posting comment."
    return 0
  fi

 GERRIT_USER=${GERRIT_USER:-jenkins}
  ssh -p ${GERRIT_PORT} ${GERRIT_USER}@${GERRIT_ADDRESS}  gerrit review \
  ${GERRIT_CHANGENUMBER},${GERRIT_PATCHSET_NUMBER} \
   --verified ${overall} -m "$(cat ${commentfile})"

}
