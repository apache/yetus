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

personality_plugins "all"

## @description  Globals specific to this personality
## @audience     private
## @stability    evolving
function personality_globals
{
  # shellcheck disable=SC2034
  BUILDTOOL=maven
  #shellcheck disable=SC2034
  PATCH_BRANCH_DEFAULT=main
  #shellcheck disable=SC2034
  JIRA_ISSUE_RE='^YETUS-[0-9]+$'
  #shellcheck disable=SC2034
  GITHUB_REPO_DEFAULT="apache/yetus"
}

## @description  Queue up modules for this personality
## @audience     private
## @stability    evolving
## @param        repostatus
## @param        testtype
function personality_modules
{
  declare repostatus=$1
  declare testtype=$2

  yetus_debug "Personality: ${repostatus} ${testtype}"

  clear_personality_queue

  case ${testtype} in
    mvninstall)
      if [[ "${repostatus}" = branch || "${BUILDMODE}" = full ]]; then
        clear_personality_queue
        personality_enqueue_module .
        return
      fi
    ;;
    *)
    ;;
  esac

  if declare -f "${BUILDTOOL}_builtin_personality_modules" >/dev/null; then
    "${BUILDTOOL}_builtin_personality_modules" "$@"
  fi
}