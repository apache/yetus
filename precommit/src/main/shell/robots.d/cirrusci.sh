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

if [[ "${CIRRUS_CI}" == true ]] &&
  declare -f compile_cycle >/dev/null; then

  # shellcheck disable=SC2034
  ROBOT=true
  # shellcheck disable=SC2034
  PATCH_BRANCH_DEFAULT=${CIRRUS_DEFAULT_BRANCH}
  # shellcheck disable=SC2034
  INSTANCE=${CIRRUS_BUILD_ID}
  # shellcheck disable=SC2034
  ROBOTTYPE=cirrusci
  PATCH_DIR=/tmp/yetus-out
  # shellcheck disable=SC2034
  RELOCATE_PATCH_DIR=true

  # shellcheck disable=SC2034
  if [[ "${CIRRUS_PR}" == false ]]; then
    # shellcheck disable=SC2034
    BUILDMODE='patch'
    # shellcheck disable=SC2034
    PATCH_OR_ISSUE=GH:${CIRRUS_PR}
    USER_PARAMS+=("GH:${CIRRUS_PR}")
  else
    BUILDMODE=full
    PATCH_BRANCH=${CIRRUS_BRANCH}
  fi

  # shellcheck disable=SC2034
  GITHUB_REPO=${CIRRUS_REPO_FULL_NAME}

  add_docker_env \
    CI \
    CIRRUS_BASE_SHA \
    CIRRUS_BRANCH \
    CIRRUS_BUILD_ID \
    CIRRUS_CI \
    CIRRUS_DEFAULT_BRANCH \
    CIRRUS_PR \
    CIRRUS_REPO_FULL_NAME \
    CIRRUS_TASK_ID \
    GITHUB_CHECK_SUITE_ID

  # shellcheck disable=SC2034
  GIT_BRANCH_SHA=${CIRRUS_BASE_SHA}

  # shellcheck disable=SC2034
  BUILD_URL="https://cirrus-ci.com/task/${CIRRUS_TASK_ID}"

  # shellcheck disable=SC2034
  BUILD_URL_CONSOLE=""
  # shellcheck disable=SC2034
  CONSOLE_USE_BUILD_URL=true

  if [[ -d ${BASEDIR}/.git ]]; then
    echo "Updating the local git repo to include all branches/tags:"
    pushd "${BASEDIR}" >/dev/null || exit 1
    "${GIT}" config --replace-all remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
    "${GIT}" fetch --tags
    popd >/dev/null || exit 1
  fi

  yetus_add_array_element EXEC_MODES CirrusCI
fi

function cirrusci_set_plugin_defaults
{
  # shellcheck disable=SC2034
  GITHUB_REPO=${CIRRUS_REPO_FULL_NAME}
  # shellcheck disable=SC2034
  JUNIT_RESULTS_XML="${PATCH_DIR}/junit.xml"
}

function cirrusci_finalreport
{
  add_footer_table "Console output" "${BUILD_URL}"
}

function cirrusci_artifact_url
{
  declare dir

  dir=${PATCH_DIR##*/}
  echo "https://api.cirrus-ci.com/v1/artifact/task/${CIRRUS_TASK_ID}/other/${dir}"
}
