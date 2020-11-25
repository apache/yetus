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

add_bugsystem slack

## @description  Usage info for slack plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function slack_usage
{
  yetus_add_option "--slack-webhook-url=<url>" "Slack Webhook URL"
}

## @description  Option parsing for slack plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function slack_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --slack-webhook-url=*)
        delete_parameter "${i}"
        SLACK_WEBHOOK_URL=${i#*=}
      ;;
    esac
  done
}

## @description  Write result to a slack channel
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function slack_finalreport
{
  declare result=$1
  declare tempfile="${PATCH_DIR}/slack.$$.${RANDOM}"

  if [[ -z "${SLACK_WEBHOOK_URL}" ]]; then
    return 0
  fi

  big_console_header "Writing a comment to Slack"

  # shellcheck disable=SC2028
  {
    echo "{"
    echo "\"icon_emoji\":\":shell:\","
    printf "\"text\":\""
    if [[ "${BUILDMODE}" == patch ]]; then
      if [[ ${result} == 0 ]]; then
        echo "${PATCH_OR_URL}: *+1 overall* :confetti_ball:\n"
      else
        echo "${PATCH_OR_URL}: *-1 overall* :broken_heart:\n"
      fi
    else
      if [[ ${result} == 0 ]]; then
        echo "${PROJECT_NAME}/${PATCH_BRANCH}: *+1 overall* :confetti_ball:\n"
      else
        echo "${PROJECT_NAME}/${PATCH_BRANCH}: *-1 overall* :broken_heart:\n"
      fi
    fi
    if [[ -n "${BUILD_URL}" ]]; then
      echo "See the <${BUILD_URL}|build URL> for more information.\n"
    fi
    echo "\","
    echo "\"username\":\"Apache Yetus\""
    echo "}"
  } > "${tempfile}"

  # Let's pull the PR JSON for later use
  "${CURL}" -X POST \
      --silent --fail \
      -H "Content-Type: application/json" \
      -d @"${tempfile}" \
      --location \
        "${SLACK_URL}"

  rm "${tempfile}" 2>/dev/null
  return 0
}
