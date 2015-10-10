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

add_test_format ctest

CTEST_FAILED_TESTS=""

## @description  initialize ctest
## @audience     private
## @stability    evolving
## @replaceable  no
function ctest_initialize
{
  # shellcheck disable=SC2034
  CTEST_OUTPUT_ON_FAILURE=true
}

## @description  ctest log processor
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        module
## @param        logfile
## @param        filefragment
## @return       status
function ctest_process_tests
{
  # shellcheck disable=SC2034
  declare module=$1
  # shellcheck disable=SC2034
  declare buildlogfile=$2
  declare filefrag=$3
  declare result=0
  declare module_failed_tests
  declare filenames
  declare shortlog
  declare reallog

  filenames=$(find "${BASEDIR}" -type f -name LastTestsFailed.log)

  if [[ -n "${filenames}" ]]; then
    for shortlog in ${filenames}; do
      #shellcheck disable=2086
      reallog="$(dirname ${shortlog})/LastTest.log"
      if [[ -f "${reallog}" ]]; then
        module_failed_tests=$(cut -f2 -d: "${shortlog}")
        cp "${reallog}" "${PATCH_DIR}/patch-${filefrag}.ctest"
        CTEST_LOGS="${CTEST_LOGS} @@BASE@@/patch-${filefrag}.ctest"
        CTEST_FAILED_TESTS="${CTEST_FAILED_TESTS} ${module_failed_tests}"
        ((result=result+1))
      fi
    done
  fi

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  cmake test table results
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        jdk
function ctest_finalize_results
{
  declare jdk=$1

  if [[ -n "${CTEST_FAILED_TESTS}" ]] ; then
    # shellcheck disable=SC2086
    populate_test_table "${jdk}Failed CTEST tests" ${CTEST_FAILED_TESTS}
    CTEST_FAILED_TESTS=""
    add_footer_table "CTEST logs" "${CTEST_LOGS}"
  fi
}
