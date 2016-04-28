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

# Run all plugins
personality_plugins "all"

## @description  Globals specific to this personality
## @audience     private
## @stability    evolving
function personality_globals
{
  # shellcheck disable=SC2034
  BUILDTOOL=maven
  #shellcheck disable=SC2034
  PATCH_BRANCH_DEFAULT=master
  #shellcheck disable=SC2034
  JIRA_ISSUE_RE='^ACCUMULO-[0-9]+$'
  #shellcheck disable=SC2034
  GITHUB_REPO="apache/accumulo"
  #shellcheck disable=SC2034
  PATCH_NAMING_RULE="http://accumulo.apache.org/git.html#contributors"
  # We want to invoke the 'check' goal, not the default 'checkstyle'. We define
  # our own checkstyle rules which isn't possible via 'checkstyle' configuration
  #shellcheck disable=SC2034
  CHECKSTYLE_GOAL="check"
}

## @description  Queue up modules for this personality
## @audience     private
## @stability    evolving
## @param        repostatus
## @param        testtype
function personality_modules
{
  local repostatus=$1
  local testtype=$2

  yetus_debug "Personality: ${repostatus} ${testtype}"
  clear_personality_queue

  if [[ ${testtype} ==  'unit' ]]; then
    # Run all tests, not just the tests in the modules affected
    yetus_debug "Overriding to run all unit tests"

    personality_enqueue_module .
    return
  fi

  # Make sure we re-add the changed modules if we didn't short-circuit out
  for module in "${CHANGED_MODULES[@]}"; do
    personality_enqueue_module "${module}"
  done
}
