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

# SHELLDOC-IGNORE

if [[ "${GITHUB_ACTIONS}" == true ]] &&
  declare -f compile_cycle >/dev/null; then

  echo "::group::Bootstrap"

  # shellcheck disable=SC2034
  ROBOT=true
  # shellcheck disable=SC2034
  PATCH_DIR=${PATCH_DIR:-${GITHUB_WORKSPACE}/yetus}
  # shellcheck disable=SC2034
  PATCH_OR_ISSUE="GHSHA:${GITHUB_SHA}"

  # shellcheck disable=SC2034
  INSTANCE=${GITHUB_RUN_NUMBER}

  # shellcheck disable=SC2034
  ROBOTTYPE=githubactions

  # shellcheck disable=SC2034
  BUILD_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

  # shellcheck disable=SC2034
  BUILD_URL_CONSOLE=/

  # shellcheck disable=SC2034
  CONSOLE_USE_BUILD_URL=true

  # shellcheck disable=SC2034
  GITHUB_REPO="${GITHUB_REPOSITORY}"

  # shellcheck disable=SC2034
  GITHUB_STATUS_USE_HTMLREPORT="false"

  if [[ "${GITHUB_EVENT_NAME}" == push ]]; then
    # shellcheck disable=SC2034
    PATCH_OR_ISSUE=""
    #shellcheck disable=SC2034,SC2153
    PATCH_BRANCH=$(echo "${GITHUB_REF}" | cut -f3- -d/)
    # shellcheck disable=SC2034
    BUILDMODE=full
    add_docker_env BUILDMODE
  elif [[ "${GITHUB_EVENT_NAME}" == pull_request ]]; then
    # shellcheck disable=SC2034
    PATCH_OR_ISSUE=$(echo "${GITHUB_REF}" | cut -f3 -d/)
    PATCH_OR_ISSUE="GH:${PATCH_OR_ISSUE}"
    # shellcheck disable=SC2034
    PATCH_BRANCH=${GITHUB_BASE_REF}
  fi

  add_docker_env \
    GITHUB_ACTIONS \
    GITHUB_BASE_REF \
    GITHUB_EVENT_NAME \
    GITHUB_REF \
    GITHUB_REPOSITORY \
    GITHUB_RUN_NUMBER \
    GITHUB_SHA \
    GITHUB_TOKEN \
    GITHUB_WORKSPACE

  yetus_add_array_element EXEC_MODES GitHubActions
fi

function githubactions_set_plugin_defaults
{
  # shellcheck disable=SC2034
  GITHUB_REPO="${GITHUB_REPOSITORY}"
}

function githubactions_cleanup_and_exit
{
  echo "::endgroup::"
}

## @description  Write a summary report to GitHub Actions Job Summary
## @audience     private
## @stability    evolving
## @replaceable  no
function githubactions_finalreport
{
  declare -i i=0
  declare ourstring
  declare vote
  declare subs
  declare ela
  declare calctime
  declare logfile
  declare comment
  declare url
  declare emoji
  declare loglink

  if [[ -z "${GITHUB_STEP_SUMMARY}" ]]; then
    return 0
  fi

  if [[ ! -w "${GITHUB_STEP_SUMMARY}" ]]; then
    yetus_error "WARNING: GITHUB_STEP_SUMMARY (${GITHUB_STEP_SUMMARY}) is not writable"
    return 0
  fi

  big_console_header "Writing GitHub Actions Job Summary"

  url=$(get_artifact_url)

  {
    if [[ ${RESULT} == 0 ]]; then
      printf '## :confetti_ball: +1 overall\n\n'
    else
      printf '## :broken_heart: -1 overall\n\n'
    fi

    i=0
    until [[ ${i} -ge ${#TP_HEADER[@]} ]]; do
      printf '%s\n\n' "${TP_HEADER[i]}"
      ((i=i+1))
    done

    printf '| Vote | Subsystem | Runtime | Logfile | Comment |\n'
    printf '|:----:|----------:|--------:|:-------:|:--------|\n'

    i=0
    until [[ ${i} -ge ${#TP_VOTE_TABLE[@]} ]]; do
      ourstring=$(echo "${TP_VOTE_TABLE[i]}" | tr -s ' ')
      vote=$(echo "${ourstring}" | cut -f2 -d\| | tr -d ' ')
      subs=$(echo "${ourstring}" | cut -f3 -d\|)
      ela=$(echo "${ourstring}" | cut -f4 -d\|)
      calctime=$(clock_display "${ela}")
      logfile=$(echo "${ourstring}" | cut -f5 -d\| | tr -d ' ')
      comment=$(echo "${ourstring}" | cut -f6 -d\|)

      if [[ "${vote}" = "H" ]]; then
        printf '| | | | | _%s_ |\n' "${comment}"
        ((i=i+1))
        continue
      fi

      # Honor GITHUB_USE_EMOJI_VOTE setting
      if [[ ${GITHUB_USE_EMOJI_VOTE} == true ]]; then
        case ${vote} in
          1|"+1")
            emoji="+1 :green_heart:"
          ;;
          -1)
            emoji="-1 :x:"
          ;;
          0)
            emoji="+0 :ok:"
          ;;
          -0)
            emoji="-0 :warning:"
          ;;
          *)
            emoji=${vote}
          ;;
        esac
      else
        emoji="${vote}"
      fi

      # Format logfile as link if URL is available
      if [[ -n "${logfile}" ]]; then
        if [[ -n "${url}" ]]; then
          loglink=$(echo "${logfile}" | "${SED}" -e "s,@@BASE@@,${url},g")
          loglink="[${logfile/@@BASE@@\//}](${loglink})"
        else
          loglink="${logfile/@@BASE@@\//}"
        fi
      else
        loglink=""
      fi

      printf '| %s | %s | %s | %s | %s |\n' \
        "${emoji}" \
        "${subs}" \
        "${calctime}" \
        "${loglink}" \
        "${comment}"

      ((i=i+1))
    done

    if [[ ${#TP_TEST_TABLE[@]} -gt 0 ]]; then
      printf '\n### Failed Tests\n\n'
      printf '| Reason | Tests |\n'
      printf '|-------:|:------|\n'
      i=0
      until [[ ${i} -ge ${#TP_TEST_TABLE[@]} ]]; do
        echo "${TP_TEST_TABLE[i]}"
        ((i=i+1))
      done
    fi

    printf '\n### Subsystem Report\n\n'
    printf '| Subsystem | Report/Notes |\n'
    printf '|----------:|:-------------|\n'

    i=0
    until [[ ${i} -ge ${#TP_FOOTER_TABLE[@]} ]]; do
      comment=$(echo "${TP_FOOTER_TABLE[i]}" | "${SED}" -e "s,@@BASE@@,${url},g")
      printf '%s\n' "${comment}"
      ((i=i+1))
    done
  } >> "${GITHUB_STEP_SUMMARY}"
}
