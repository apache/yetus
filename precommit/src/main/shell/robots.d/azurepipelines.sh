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
if [[ "${TF_BUILD}" = True ]] &&
  declare -f compile_cycle >/dev/null; then
  if [[ ${BUILD_REPOSITORY_URI} =~ github.com ]]; then

    if [[ "${SYSTEM_PULLREQUEST_PULLREQUESTNUMBER}" ]]; then
      BUILDMODE="patch"
      PATCH_OR_ISSUE="GH:${SYSTEM_PULLREQUEST_PULLREQUESTNUMBER}"
      USER_PARAMS+=("GH:${SYSTEM_PULLREQUEST_PULLREQUESTNUMBER}")
      PATCH_BRANCH="${SYSTEM_PULLREQUEST_TARGETBRANCH}"
    else
      BUILDMODE=full
      USER_PARAMS+=("--empty-patch")
      # which will be 'Merge' on PRs for some reason
      PATCH_BRANCH="${BUILD_SOURCEBRANCHNAME}"
    fi
    GITHUB_REPO=${BUILD_REPOSITORY_ID}
    ROBOT=true
    ROBOTTYPE=azurepipelines


    #echo "${SYSTEM_TEAMFOUNDATIONCOLLECTIONURI}_build?definitionId=${SYSTEM_DEFINITIONID}"

    BUILD_URL="${SYSTEM_TEAMFOUNDATIONCOLLECTIONURI}${SYSTEM_TEAMPROJECT}"
    BUILD_URL_CONSOLE="/_build/results?buildId=${BUILD_BUILDID}"
    CONSOLE_USE_BUILD_URL=false

    if [[ -n "${BUILD_SOURCESDIRECTORY}" ]] && [[ -d "${BUILD_SOURCESDIRECTORY}" ]]; then
      BASEDIR=${BUILD_SOURCESDIRECTORY}
    fi

    if [[ -n "${BUILD_ARTIFACTSTAGINGDIRECTORY}" ]] && [[ -d "${BUILD_ARTIFACTSTAGINGDIRECTORY}" ]]; then
      PATCH_DIR=${BUILD_ARTIFACTSTAGINGDIRECTORY}/yetus
    fi

    git_requires_creds

    if [[ "${GIT_OFFLINE}" == false ]]; then
      yetus_error "WARNING: Working around Azure Pipelines branch information"
      pushd "${BASEDIR}" >/dev/null || exit 1
      "${GIT}" remote set-branches origin '*'
      "${GIT}" fetch -v
      popd >/dev/null || exit 1
    fi

    if [[ -z "${PATCH_OR_ISSUE}" ]] && [[ -n "${BRANCH_NAME}" ]]; then
      if [[ "${GIT_OFFLINE}" == false ]]; then
        yetus_error "WARNING: Resetting Jenkins git upstream information"
        pushd "${BASEDIR}" >/dev/null || exit 1
        "${GIT}" branch --set-upstream-to=origin/"${BRANCH_NAME}" "${BRANCH_NAME}"
        popd >/dev/null || exit 1
      fi
      PATCH_BRANCH=${BRANCH_NAME}
    fi

    add_docker_env \
      BUILD_ARTIFACTSTAGINGDIRECTORY \
      BUILD_BUILDID \
      BUILD_REPOSITORY_ID \
      BUILD_REPOSITORY_URI \
      BUILD_SOURCEBRANCHNAME \
      BUILD_SOURCESDIRECTORY \
      SYSTEM_PULLREQUEST_PULLREQUESTNUMBER \
      SYSTEM_PULLREQUEST_TARGETBRANCH \
      SYSTEM_TEAMFOUNDATIONCOLLECTIONURI \
      SYSTEM_TEAMPROJECT \
      SYSTEM_TEAMPROJECTID \
      TF_BUILD

    yetus_add_array_element EXEC_MODES Azure_Pipelines
  fi
fi

function azurepipelines_set_plugin_defaults
{
  if [[ ${BUILD_REPOSITORY_URI} =~ github.com ]]; then
    github_breakup_url "${BUILD_REPOSITORY_URI}"
    GITHUB_REPO=${BUILD_REPOSITORY_ID}
  fi
}

function azurepipelines_finalreport
{
  add_footer_table "Console output" "${BUILD_URL}${BUILD_URL_CONSOLE}"
}