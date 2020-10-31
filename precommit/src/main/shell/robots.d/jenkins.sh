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

# Work around JENKINS-55752 / YETUS-786
JENKINS_URL=${JENKINS_URL:-${HUDSON_URL}}

# we need two for Jenkins because users may
# use the jenkins-cli which will also read JENKINS_URL
# shellcheck disable=SC2034
if [[ -n "${JENKINS_URL}" && -n "${EXECUTOR_NUMBER}" ]] &&
  declare -f compile_cycle >/dev/null; then
  ROBOT=true
  INSTANCE=${EXECUTOR_NUMBER}
  ROBOTTYPE=jenkins
  JENKINS_CUSTOM_HOMEDIR=false
  BUILDMODE=full
  USER_PARAMS+=("--empty-patch")

  # if we are running in an Jenkins docker container
  # spawned by using agent, then there is a good chance
  # that the user running the test is in a bad state:
  # no password entry, no home directory, etc.
  if [[ "${HOME}" == / ]]; then
    if ! id "(id -u)" >/dev/null 2>&1; then
      HOME=/tmp/yetus-home.${RANDOM}
      JENKINS_CUSTOM_HOMEDIR=true
      yetus_error "WARNING: Invalid HOME env defined by Jenkins, setting to ${HOME}"
      if ! mkdir -p "${HOME}"; then
        yetus_error "ERROR: Cannot mkdir ${HOME}.  Exiting."
        exit 1
      fi
    fi
  fi

  git_requires_creds

  if [[ "${GIT_OFFLINE}" == false ]]; then
    yetus_error "WARNING: Working around Jenkins branch information"
    pushd "${BASEDIR}" >/dev/null || exit 1
    "${GIT}" remote set-branches origin '*'
    "${GIT}" fetch -v
    popd >/dev/null || exit 1
  fi

  # BUILD_URL comes from Jenkins already
  BUILD_URL_CONSOLE=console
  # shellcheck disable=SC2034
  CONSOLE_USE_BUILD_URL=true

  # shellcheck disable=SC2034,SC2154
  if [[ -n "${ghprbPullId}" ]]; then
    # GitHub Pull Request Builder Plugin
    PATCH_OR_ISSUE="GH:${ghprbPullId}"
  fi

  # shellcheck disable=SC2034,SC2154
  if [[ -n "${ghprbPullLink}" ]]; then
    # GitHub Pull Request Builder Plugin
    PATCH_OR_ISSUE="${ghprbPullLink}"
  fi

  # shellcheck disable=SC2034,SC2154
  if [[ -n "${CHANGE_URL}" ]]; then
    # GitHub Branch Source Plugin, among others
    # likely to be more accurate than ghprbPullId
    # since it is a full URL
    PATCH_OR_ISSUE="${CHANGE_URL}"
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
    BRANCH_NAME \
    BUILD_URL \
    CHANGE_URL \
    EXECUTOR_NUMBER \
    ghprbPullId \
    ghprbPullLink \
    GIT_URL \
    JENKINS_URL

  yetus_add_array_element EXEC_MODES Jenkins
fi

function jenkins_set_plugin_defaults
{
  if [[ -n "${GIT_URL}" ]]; then
    if [[ "${GIT_URL}" =~ github ]] \
      && declare -f  github_breakup_url >/dev/null 2>&1; then
       github_breakup_url "${GIT_URL}"
    elif [[ "${GIT_URL}" =~ gitlab ]] \
      && declare -f  gitlab_breakup_url >/dev/null 2>&1; then
       gitlab_breakup_url "${GIT_URL}"
    fi
  fi

  if [[ -n "${ghprbPullLink}" ]]; then
    if [[ "${ghprbPullLink}" =~ github ]] \
      && declare -f  github_breakup_url >/dev/null 2>&1; then
       github_breakup_url "${ghprbPullLink}"
    fi
  fi

  if [[ -n "${CHANGE_URL}" ]]; then
    if [[ "${CHANGE_URL}" =~ github ]] \
      && declare -f  github_breakup_url >/dev/null 2>&1; then
       github_breakup_url "${CHANGE_URL}"
    elif [[ "${CHANGE_URL}" =~ gitlab ]] \
      && declare -f  gitlab_breakup_url >/dev/null 2>&1; then
       gitlab_breakup_url "${CHANGE_URL}"
    fi
  fi

  if [[ "${JENKINS_CUSTOM_HOMEDIR}" == true ]]; then
    # maven defaults to '(cwd)/?/.m2' if user isn't in
    # /etc/passwd.  So force maven custom repos to at least
    # give us a chance. also need to put this in user params
    # in case of re-exec
    USER_PARAMS+=("--mvn-custom-repos")
    yetus_error "WARNING: Setting --mvn-custom-repos due to previously invalid home directory"
    # shellcheck disable=SC2034
    MAVEN_CUSTOM_REPOS=true
  fi
}

function jenkins_verify_patchdir
{
  declare commentfile=$1
  declare extra

  if [[ -n ${NODE_NAME} ]]; then
    extra=" (Jenkins node ${NODE_NAME})"
  fi
  echo "Jenkins${extra} information at ${BUILD_URL}${BUILD_URL_CONSOLE} may provide some hints. " >> "${commentfile}"
}

function jenkins_unittest_footer
{
  declare statusjdk=$1
  declare extra

  add_footer_table "${statusjdk} Test Results" "${BUILD_URL}testReport/"
}

function jenkins_finalreport
{
  add_footer_table "Console output" "${BUILD_URL}${BUILD_URL_CONSOLE}"
}

function jenkins_artifact_url
{
  echo "${BUILD_URL}${BUILD_URL_ARTIFACTS}"
}
