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