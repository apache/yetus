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

if [[ "${BUILDKITE}" == true ]] &&
  declare -f compile_cycle >/dev/null; then
  # shellcheck disable=SC2034
  ROBOT=true

  add_bugsystem buildkiteannotate

  # shellcheck disable=SC2034
  if [[ -n "${BUILDKITE_ARTIFACT_PATHS}" ]]; then
    PATCH_DIR=${BUILDKITE_ARTIFACT_PATHS%%;*}/yetus
  fi

  # shellcheck disable=SC2034
  INSTANCE=${BUILDKITE_BUILD_ID}
  # shellcheck disable=SC2034
  ROBOTTYPE=buildkite
  # shellcheck disable=SC2034
  BUILD_URL="${BUILDKITE_BUILD_URL}"

  # shellcheck disable=SC2034
  if [[ "${BUILDKITE_PULL_REQUEST}" == false ]]; then
    BUILDMODE=full
    PATCH_BRANCH=${BUILDKITE_BRANCH}
  else
    # shellcheck disable=SC2034
    BUILDMODE='patch'

    case ${BUILDKITE_PIPELINE_PROVIDER} in
      github)
        PATCH_OR_ISSUE=GH:${BUILDKITE_PULL_REQUEST}
        USER_PARAMS+=("GH:${BUILDKITE_PULL_REQUEST}")
      ;;
      gitlab)
        # shellcheck disable=SC2034
        PATCH_OR_ISSUE=GL:${BUILDKITE_PULL_REQUEST}
        USER_PARAMS+=("GL:${BUILDKITE_PULL_REQUEST}")
      ;;
    esac
  fi

  add_docker_env \
    BUILDKITE \
    BUILDKITE_BUILD_ID \
    BUILDKITE_BUILD_URL \
    BUILDKITE_BRANCH \
    BUILDKITE_PIPELINE_PROVIDER \
    BUILDKITE_PULL_REQUEST \
    BUILDKITE_REPO

  # shellcheck disable=SC2034
  BUILD_URL_CONSOLE=""
  # shellcheck disable=SC2034
  CONSOLE_USE_BUILD_URL=false

  if [[ -d ${BASEDIR}/.git ]]; then
    echo "Updating the local git repo to include all branches/tags:"
    pushd "${BASEDIR}" >/dev/null || exit 1
    "${GIT}" config --replace-all remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
    "${GIT}" fetch --tags
    popd >/dev/null || exit 1
  fi

  yetus_add_array_element EXEC_MODES Buildkite
fi

function buildkite_finalreport
{
  add_footer_table "Console output" "${BUILDKITE_BUILD_URL}"
}

function buildkite_artifact_url
{
  echo "artifact:/${PATCH_DIR}"
}

function buildkiteannotate_finalreport
{
  declare result=$1
  declare i
  declare recoverydir="${PATCH_DIR}/buildkite-recovery"
  declare comment
  declare url
  declare ela
  declare subs
  declare logfile
  declare calctime
  declare vote
  declare emoji
  declare buildkite_style

  mkdir -p "${recoverydir}"
  commentfile="${recoverydir}/buildkite-recovery.md"

  big_console_header "Creating Buildkite annotation"

  rm "${commentfile}" 2>/dev/null

  url=$(get_artifact_url)

  if [[ ${result} == 0 ]]; then
    echo ":confetti_ball: **+1 overall**" >> "${commentfile}"
    echo "success" > "${recoverydir}/style.txt"
  else
    echo ":broken_heart: **-1 overall**" >> "${commentfile}"
    echo "error" > "${recoverydir}/style.txt"
  fi
  printf '\n\n\n\n' >>  "${commentfile}"

  i=0
  until [[ ${i} -ge ${#TP_HEADER[@]} ]]; do
    printf '%s\n\n' "${TP_HEADER[${i}]}" >> "${commentfile}"
    ((i=i+1))
  done

  {
    printf '\n\n'
    echo "| Vote | Subsystem | Runtime |  Logfile | Comment |"
    echo "|:----:|----------:|--------:|:--------:|:-------:|"
  } >> "${commentfile}"

  i=0
  until [[ ${i} -ge ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\| | tr -d ' ')
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    calctime=$(clock_display "${ela}")
    logfile=$(echo "${ourstring}" | cut -f5 -d\| | tr -d ' ')
    comment=$(echo "${ourstring}"  | cut -f6 -d\|)

    if [[ "${vote}" = "H" ]]; then
      echo "|||| _${comment}_ |" >> "${commentfile}"
      ((i=i+1))
      continue
    fi

    emoji=""
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
      H)
        # this never gets called (see above) but this is here so others know the color is taken
        emoji=""
      ;;
      *)
        # usually this should not happen but let's keep the old vote result if it happens
        emoji=${vote}
      ;;
    esac

    if [[ -n "${logfile}" ]]; then
      t1=${logfile/@@BASE@@/}
      t2=$(echo "${logfile}" | "${SED}" -e "s,@@BASE@@,${url},g")
      t2="[${t1}](${t2})"
    else
      t2=""
    fi

    printf '| %s | %s | %s | %s | %s |\n' \
      "${emoji}" \
      "${subs}" \
      "${calctime}" \
      "${t2}" \
      "${comment}" \
      >> "${commentfile}"

    ((i=i+1))
  done

  if [[ ${#TP_TEST_TABLE[@]} -gt 0 ]]; then
    {
      printf '\n\n'
      echo "| Reason | Tests |"
      echo "|-------:|:------|"
    } >> "${commentfile}"
    i=0
    until [[ ${i} -ge ${#TP_TEST_TABLE[@]} ]]; do
      echo "${TP_TEST_TABLE[${i}]}" >> "${commentfile}"
      ((i=i+1))
    done
  fi

  {
    printf '\n\n'
    echo "| Subsystem | Report/Notes |"
    echo "|----------:|:-------------|"
  } >> "${commentfile}"

  i=0
  until [[ $i -ge ${#TP_FOOTER_TABLE[@]} ]]; do
    comment=$(echo "${TP_FOOTER_TABLE[${i}]}" | "${SED}" -e "s,@@BASE@@,${url},g")
    printf '%s\n' "${comment}" >> "${commentfile}"
    ((i=i+1))
  done

  buildkite_recovery
}

function buildkite_recovery
{
  declare buildkite_style
  declare recoverydir="${PATCH_DIR}/buildkite-recovery"

  buildkite_agent=$(command -v buildkite-agent 2>/dev/null)

  commentfile="${recoverydir}/buildkite-recovery.md"

  if [[ -z "${buildkite_agent}" ]]; then
    yetus_error "ERROR: buildkite-agent is not available. Skipping Buildkite annotation."
    return 0
  fi

  if [[ ! -f "${recoverydir}/style.txt" ]]; then
    yetus_error "WARNING: No buildkite status to recovery. Maybe it was successful?"
    return 0
  fi

  big_console_header "Uploading Buildkite artifacts"

  buildkite-agent artifact upload "${PATCH_DIR}/*"

  big_console_header "Adding Buildkite annotation"

  buildkite_style=$(cat "${recoverydir}/style.txt")

  "${buildkite_agent}" annotate --style "${buildkite_style}" < "${commentfile}"
  rm -rf "${recoverydir}"
}