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

if [[ -n "${JENKINS_URL}" ]]; then
  # shellcheck disable=SC2034
  ROBOT=true
  # shellcheck disable=SC2034
  INSTANCE=${EXECUTOR_NUMBER}
  # shellcheck disable=SC2034
  ROBOTTYPE=jenkins

  # BUILD_URL comes from Jenkins already
  BUILD_URL_CONSOLE=console
  # shellcheck disable=SC2034
  CONSOLE_USE_BUILD_URL=true

  add_docker_env BUILD_URL \
    EXECUTOR_NUMBER \
    JENKINS_URL

  yetus_add_entry EXEC_MODES Jenkins
fi

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