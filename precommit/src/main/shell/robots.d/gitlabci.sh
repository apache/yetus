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
if [[ "${GITLAB_CI}" = true ]] &&
  declare -f compile_cycle >/dev/null; then
  CONSOLE_USE_BUILD_URL=true
  PATCH_DIR=/tmp/yetus-out
  RELOCATE_PATCH_DIR=true
  ROBOT=true
  ROBOTTYPE=gitlabci
  INSTANCE=${CI_JOB_ID}
  BUILD_URL=${CI_JOB_URL}
  BUILD_URL_CONSOLE="/"
  GITLAB_REPO=${CI_PROJECT_PATH}
  BUILD_URL_ARTIFACTS=/artifacts/file/yetus-out
  PATCH_OR_ISSUE="GLSHA:${CI_COMMIT_SHA}"
  USER_PARAMS+=("GLSHA:${CI_COMMIT_SHA}")

  add_docker_env \
    CI_COMMIT_SHA \
    CI_JOB_ID \
    CI_JOB_URL \
    CI_PROJECT_PATH \
    GITLAB_CI

  yetus_add_array_element EXEC_MODES Gitlab_CI
  yetus_add_array_element EXEC_MODES ResetRepo
  yetus_add_array_element EXEC_MODES Robot
  yetus_add_array_element EXEC_MODES UnitTests
fi

function gitlabci_set_plugin_defaults
{
    # shellcheck disable=2034
    GITLAB_REPO=${CI_PROJECT_PATH}
}

function gitlabci_finalreport
{
  add_footer_table "Console output" "${BUILD_URL}"
}

function gitlabci_artifact_url
{
  echo "${BUILD_URL}${BUILD_URL_ARTIFACTS}"
}