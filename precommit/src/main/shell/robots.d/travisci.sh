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

if [[ "${TRAVIS}" == true ]] &&
  declare -f compile_cycle >/dev/null; then
  # shellcheck disable=SC2034
  ROBOT=true

  # Travis runs some ancient version of docker, so...
  # shellcheck disable=SC2034
  DOCKER_BUILDKIT_SETTING=false
  unset DOCKER_BUILDKIT

  # shellcheck disable=SC2034
  if [[ -n "${ARTIFACTS_PATH}" ]]; then
    PATCH_DIR=${ARTIFACTS_PATH%%:*}
  fi

  # shellcheck disable=SC2034
  INSTANCE=${TRAVIS_BUILD_ID}
  # shellcheck disable=SC2034
  ROBOTTYPE=travisci

  # shellcheck disable=SC2034
  if [[ "${TRAVIS_PULL_REQUEST}" == false ]]; then
    BUILDMODE=full
    PATCH_BRANCH=${TRAVIS_BRANCH}
  else
    # shellcheck disable=SC2034
    BUILDMODE='patch'
    # shellcheck disable=SC2034
    PATCH_OR_ISSUE=GH:${TRAVIS_PULL_REQUEST}
    USER_PARAMS+=("GH:${TRAVIS_PULL_REQUEST}")
  fi

  # shellcheck disable=SC2034
  GITHUB_REPO=${TRAVIS_REPO_SLUG}

  # shellcheck disable=SC2034
  GIT_BRANCH_SHA=${TRAVIS_PULL_REQUEST_SHA}

  add_docker_env \
    TRAVIS \
    TRAVIS_BRANCH \
    TRAVIS_BUILD_ID \
    TRAVIS_BUILD_WEB_URL \
    TRAVIS_PULL_REQUEST \
    TRAVIS_PULL_REQUEST_SHA \
    TRAVIS_REPO_SLUG

  # shellcheck disable=SC2034
  BUILD_URL_CONSOLE=console
  # shellcheck disable=SC2034
  CONSOLE_USE_BUILD_URL=true

  if [[ -d ${BASEDIR}/.git ]]; then
    echo "Updating the local git repo to include all branches/tags:"
    pushd "${BASEDIR}" >/dev/null || exit 1
    "${GIT}" config --replace-all remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
    "${GIT}" fetch --tags
    popd >/dev/null || exit 1
  fi

  yetus_add_array_element EXEC_MODES TravisCI
fi

function travisci_set_plugin_defaults
{
  # shellcheck disable=SC2034
  GITHUB_REPO=${TRAVIS_REPO_SLUG}
}

function travisci_finalreport
{
  add_footer_table "Console output" "${TRAVIS_BUILD_WEB_URL}"
}

#function travisci_verify_patchdir
#{
#  declare commentfile=$1
#}

#function travisci_unittest_footer
#{
#  declare statusjdk=$1
#}
