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

# no public APIs here
# SHELLDOC-IGNORE

# shellcheck disable=2034
if [[ "${CIRCLECI}" = true ]] &&
  declare -f compile_cycle >/dev/null; then
  if [[ ${CIRCLE_REPOSITORY_URL} =~ github.com ]]; then
    # github artifacts show up like so:
    #BUILD_URL_ARTIFACTS=https://circle-artifacts.com/gh/username/repo/buildnum/artifacts/0/dir/file
    # but test-patch doesn't support URLs that aren't tied to the build_url.  so that
    # needs to get rewritten first before this can be used

    BUILD_URL="https://circleci.com/gh/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/${CIRCLE_BUILD_NUM}"
    BUILD_URL_CONSOLE=''
    CONSOLE_USE_BUILD_URL=true
    ROBOT=true
    ROBOTTYPE=circleci

    yetus_comma_to_array CPR "${CIRCLE_PULL_REQUESTS}"

    if [[ "${#CIRCLE_PULL_REQUESTS[@]}" -ne 1 ]]; then
      BUILDMODE=full
      USER_PARAMS+=("--empty-patch")
      PATCH_BRANCH="${CIRCLE_BRANCH}"
      pushd "${BASEDIR}" >/dev/null || exit 1
      echo "Attempting to reset Circle CI's understanding of ${CIRCLE_BRANCH}"
      "${GIT}" branch --set-upstream-to=origin/"${CIRCLE_BRANCH}" "${CIRCLE_BRANCH}" || true
      "${GIT}" branch -f  "${CIRCLE_BRANCH}" origin/"${CIRCLE_BRANCH}" || true
      popd >/dev/null || exit 1
    else
      PATCH_OR_ISSUE="${CIRCLE_PULL_REQUEST}"
      USER_PARAMS+=("${CIRCLE_PULL_REQUEST}")
    fi

    add_docker_env \
      CIRCLE_BRANCH \
      CIRCLE_BUILD_NUM \
      CIRCLE_PROJECT_REPONAME \
      CIRCLE_PROJECT_USERNAME \
      CIRCLE_PULL_REQUEST \
      CIRCLE_PULL_REQUESTS \
      CIRCLE_REPOSITORY_URL \
      CIRCLE_SHA1 \
      CIRCLE_TOKEN \
      CIRCLECI

    # shellcheck disable=SC2034
    GIT_BRANCH_SHA=${CIRCLE_SHA1}

    yetus_add_array_element EXEC_MODES Circle_CI
  fi
fi

function circleci_artifact_url
{
  declare apiurl
  declare baseurl

  if [[ -z "${CIRCLECI_ARTIFACTS}" ]]; then
    apiurl="https://circleci.com/api/v1.1/project/github/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/${CIRCLE_BUILD_NUM}/artifacts"

    if "${CURL}" --silent --fail \
            --output "${PATCH_DIR}/circleci.txt" \
            --location \
            "${apiurl}"; then
      baseurl=$("${GREP}" url "${PATCH_DIR}/circleci.txt" | head -1 | cut -f2- -d:)
      baseurl=${baseurl//\"/}
      baseurl=${baseurl%/*}
      baseurl=${baseurl%% }
      rm "${PATCH_DIR}/circleci.txt" 2>/dev/null
      CIRCLECI_ARTIFACTS=${baseurl}
    fi
  fi
  echo "${CIRCLECI_ARTIFACTS}"
}

function circleci_set_plugin_defaults
{
  if [[ ${CIRCLE_REPOSITORY_URL} =~ github.com ]]; then
    if [[ "${#CIRCLE_PULL_REQUESTS[@]}" -eq 1 ]] \
      && declare -f  github_breakup_url >/dev/null 2>&1; then
      github_breakup_url "${CIRCLE_PULL_REQUEST}"
    fi
    GITHUB_REPO=${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}
  fi
}

function circleci_finalreport
{
  add_footer_table "Console output" "${BUILD_URL}"
}

function circleci_pre_git_checkout
{
  pushd "${BASEDIR}" >/dev/null || exit 1
  echo "Attempting to reset Circle CI's understanding of ${PATCH_BRANCH_DEFAULT}"
  "${GIT}" branch --set-upstream-to=origin/"${PATCH_BRANCH_DEFAULT}" "${PATCH_BRANCH_DEFAULT}" || true
  "${GIT}" branch -f "${PATCH_BRANCH_DEFAULT}" origin/"${PATCH_BRANCH_DEFAULT}" || true
  popd >/dev/null || exit 1
}

#function circleci_unittest_footer
#{
#  declare statusjdk=$1
#  declare extra
#
#  add_footer_table "${statusjdk} Test Results" "${BUILD_URL}#tests/containers/0"
#}