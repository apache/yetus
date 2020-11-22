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



## @description  Pick a personality_modules function
## @description  tests that build support should call this
## @description  to make sure they get queued correct by the
## @description  personality or the build tool
## @audience     public
## @stability    evolving
## @replaceable  no
function personality_modules_wrapper
{
  declare status=$1
  declare testtype=$2

  if declare -f "${PROJECT_NAME}_personality_modules" >/dev/null; then
    "${PROJECT_NAME}_personality_modules" "$@"
  elif declare -f personality_modules >/dev/null; then
    personality_modules "$@"
  elif declare -f "${BUILDTOOL}_builtin_personality_modules" >/dev/null; then
    "${BUILDTOOL}_builtin_personality_modules" "$@"
  else
    yetus_debug "built-in personality: ${status} ${testtype}"

    clear_personality_queue
    for module in "${CHANGED_MODULES[@]}"; do
      personality_enqueue_module "${module}"
    done
  fi
}

## @description  Pick a personality_file_tests function
## @description  tests that build support should call this
## @description  to make sure they get queued correct by the
## @description  personality or the build tool
## @audience     public
## @stability    evolving
## @replaceable  no
function personality_file_tests_wrapper
{
  if declare -f "${PROJECT_NAME}_personality_file_tests" >/dev/null; then
    "${PROJECT_NAME}personality_file_tests" "$@"
  elif declare -f personality_file_tests >/dev/null; then
    personality_file_tests "$@"
  elif declare -f "${BUILDTOOL}_builtin_personality_file_tests" >/dev/null; then
    "${BUILDTOOL}_builtin_personality_file_tests" "$@"
  else
    # no pre-determined tests
    :
  fi
}