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

# this bug system handles GERRIT.  Personalities
# can override the following variables:

add_bugsystem gerrit



function gerrit_usage
{
  yetus_add_option "--gerrit-password=<pw>" "The password for the 'jira' command"
  yetus_add_option "--gerrit-user=<user>" "The user for the 'jira' command"
  yetus_add_option "--gerrit-location=<hostname:port>" "The URL of gerrit"
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
  URL="https://${GERRIT_ADDRESS}/changes/${input}/revisions/current/patch?zip"
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

  add_footer_table "Gerrit ChangeID : ${input} Gerrit Host : ${GERRIT_ADDRESS}"

  return 0
}

