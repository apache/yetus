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
if [[ "${CI}" = true ]] && [[ "${SEMAPHORE}" = true ]] &&
  declare -f compile_cycle >/dev/null; then

  ROBOT=true
  ROBOTTYPE=semaphoreci
  INSTANCE=${SEMAPHORE_JOB_ID}

  if [[ -e ${SEMAPHORE_GIT_DIR}/.git ]]; then
    BASEDIR=${SEMAPHORE_GIT_DIR}
  fi

  case "${SEMAPHORE_GIT_REF_TYPE}" in
    branch)
      BUILDMODE=full
      USER_PARAMS+=("--empty-patch")
      PATCH_BRANCH=${SEMAPHORE_GIT_BRANCH}
      ;;
    tag)
      BUILDMODE=full
      USER_PARAMS+=("--empty-patch")
      PATCH_BRANCH=${SEMAPHORE_GIT_TAG}
      ;;
    pull-request)
      PATCH_OR_ISSUE="GH:${SEMAPHORE_GIT_PR_NUMBER}"
      ;;
  esac

  yetus_add_array_element EXEC_MODES SemaphoreCI
  yetus_add_array_element EXEC_MODES ResetRepo
  yetus_add_array_element EXEC_MODES Robot
  yetus_add_array_element EXEC_MODES UnitTests

  add_docker_env \
    CI \
    SEMAPHORE \
    SEMAPHORE_GIT_BRANCH \
    SEMAPHORE_GIT_DIR \
    SEMAPHORE_GIT_PR_NUMBER \
    SEMAPHORE_GIT_REF_TYPE \
    SEMAPHORE_GIT_SHA \
    SEMAPHORE_GIT_TAG \
    SEMAPHORE_GIT_URL \
    SEMAPHORE_JOB_ID

  GITHUB_REPO=${SEMAPHORE_GIT_REPO_SLUG}
fi

function semaphoreci_set_plugin_defaults
{
    github_breakup_url "${SEMAPHORE_GIT_URL}"
}