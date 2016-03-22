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

add_build_tool nobuild

function nobuild_buildfile
{
  echo
}

function nobuild_executor
{
  echo "true"
}

function nobuild_modules_worker
{
  local status=$1
  local testtype=$2
  modules_workers "${status}" "${testtype}"
}

function nobuild_builtin_personality_modules
{
  local status=$1
  local testtype=$2
  yetus_debug "built-in personality for no build system: ${status} ${testtype}"

  clear_personality_queue
  for module in "${CHANGED_MODULES[@]}"; do
    personality_enqueue_module "${module}"
  done
}

function nobuild_builtin_personality_file_tests
{
  local filename=$1

  yetus_debug "Using built-in no build system personality_file_tests."
  yetus_debug "    given file ${filename}"
}
