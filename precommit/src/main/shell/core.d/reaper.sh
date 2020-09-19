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

REAPER_MODE=off   # off, report, kill
declare -i REAPER_TOTAL_COUNT=0
REAPER_DOCKER_ONLY=true
REAPER_ZOMBIE_MODULES=()
REAPER_ZOMBIE_LOGS=()
declare -a REAPER_NAMES


## @description  Add a regex to the reaper's checklist
## @description  NOTE: Users WILL override anything added before
## @description  argument parsing!
## @stability    evolving
## @audience     public
## @replaceable  no
function reaper_add_name
{
  yetus_add_array_element REAPER_NAMES "$1"
}

## @description  Reaper-specific usage
## @stability    stable
## @audience     private
## @replaceable  no
function reaper_usage
{
  yetus_add_option "--reapermode={off,report,kill}" "Set unit test reaper mode (default: '${REAPER_MODE}')"
  yetus_add_option "--reaperdockeronly=<bool>" "Only run the reaper in --docker (default: ${REAPER_DOCKER_ONLY})"
  yetus_add_option "--reapernames=<list>" "List of regexs to search (default build tool dependent)"
}

## @description  Reaper-specific argument parsing
## @stability    stable
## @audience     private
## @replaceable  no
## @param        arguments
function reaper_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --reapermode=*)
        delete_parameter "${i}"
        REAPER_MODE=${i#*=}
      ;;
      --reaperdockeronly=*)
        delete_parameter "${i}"
        REAPER_DOCKER_ONLY=${i#*=}
      ;;
      --reapernames=*)
        delete_parameter "${i}"
        yetus_comma_to_array REAPER_NAMES "${i#*=}"
      ;;
    esac
  done

  # Running the reaper outside of Dockermode is very dangerous

  if [[ "${REAPER_DOCKER_ONLY}" = "true" && ${DOCKERMODE} = "false" ]]; then
    REAPER_MODE="off"
    return
  fi

  # make sure REAPER_MODE is something valid and turn us on
  # as necessary
  if [[ "${REAPER_MODE}" = "report" || "${REAPER_MODE}" = "kill" ]]; then
    add_test_format reaper
    yetus_add_array_element EXEC_MODES Reaper
  else
    REAPER_MODE="off"
  fi

}

## @description  Initialize the reaper
## @stability    stable
## @audience     private
## @replaceable  yes
## @param        arguments
function reaper_initialize
{
  determine_user
}



## @description  Reaper coprocessor function that
## @description  runs outside the law
## @stability    evolving
## @audience     private
## @replaceable  yes
function reaper_coproc_func
{
  declare line
  declare i
  declare module
  declare filefrag
  declare cmd
  declare args
  declare pid
  declare -a pidlist
  declare -i count

  echo "Reaper watching for: ${REAPER_NAMES[*]}" >> "${PATCH_DIR}/reaper.txt"

  while true; do
    read -r cmd
    case ${cmd} in
      reap)

        read -r module
        read -r logfile

        while read -r line; do
          ((count=count+1))
          for i in "${REAPER_NAMES[@]}"; do
            echo "${line}" | ${GREP} -E "${i}" >> "${PATCH_DIR}/${logfile}"
          done
        done < <(ps -u "${USER_ID}" -o pid= -o args=)

        pidlist=()
        count=0
        while read -r line; do
          ((count=count+1))
          pid=$(echo "${line}" | cut -f1 -d' ')
          args=$(echo "${line}" | cut -f2- -d' ')
          if [[ "${REAPER_MODE}" = "kill" ]]; then
            pidlist+=("${pid}")
            echo "Killing ${pid} ${args}" >> "${PATCH_DIR}/reaper.txt" 2>&1
          fi
        done < <(cat "${PATCH_DIR}/${logfile}")

        # tell our parent how many
        # doing this now means killing in the background
        echo "${count}"

        if [[ ${count} -eq 0 ]]; then
          rm "${PATCH_DIR}/${logfile}"
        fi

        for i in "${pidlist[@]}"; do
          if [[ "${REAPER_MODE}" = "kill" ]]; then
            pid_kill "${i}" >> "${PATCH_DIR}/reaper.txt" 2>&1
          fi
        done
      ;;
      exit)
        exit 0
      ;;
    esac
  done
}

## @description  Run the reaper
## @stability    evolving
## @audience     private
## @replaceable  yes
## @param        module
## @param        testlog
## @param        testfrag
function reaper_post_exec
{
  declare module=$1
  declare filefrag=$2
  declare count
  declare myfile="${filefrag}-reaper.txt"
  declare killmsg=""

  case "${REAPER_MODE}" in
    off)
      return 0
    ;;
    kill)
      killmsg=" and killed"
    ;;
  esac

  yetus_debug "Checking for unreaped processes:"

  # give some time for things to die naturally
  sleep 2

  #shellcheck disable=SC2154,SC2086
  printf 'reap\n%s\n%s\n' "${module}" "${myfile}" >&${reaper_coproc[1]}

  #shellcheck disable=SC2154,SC2086
  read -r count <&${reaper_coproc[0]}

  if [[ ${count} -gt 0 ]]; then
    ((REAPER_TOTAL_COUNT=REAPER_TOTAL_COUNT+count))
    printf '\nFound%s %s left over processes\n\n' "${killmsg}" "${count}"
    REAPER_ZOMBIE_MODULES+=("${module}:${count}")
    REAPER_ZOMBIE_LOGS+=("@@BASE@@/${myfile}")
    return 1
  fi

  return 0
}

## @description  Reaper output to the user
## @stability    evolving
## @audience     private
## @replaceable  yes
## @param       jdkname
function reaper_finalize_results
{
  declare jdk=$1
  declare fn

  if [[ "${REAPER_MODE}" = "off" ]]; then
    return 0
  fi

  if [[ ${#REAPER_ZOMBIE_MODULES[@]} -gt 0 ]] ; then
    populate_test_table "${jdk}Unreaped Processes" "${REAPER_ZOMBIE_MODULES[@]}"
    for fn in "${REAPER_ZOMBIE_LOGS[@]}"; do
      add_footer_table "Unreaped Processes Log" "${fn}"
    done
    REAPER_ZOMBIE_MODULES=()
    REAPER_ZOMBIE_LOGS=()
  fi
}

## @description  Reaper output to the user
## @stability    evolving
## @audience     private
## @replaceable  yes
## @param        jdkname
function reaper_total_count
{

  if [[ "${REAPER_MODE}" = "off" ]]; then
    return 0
  fi

  if [[ ${REAPER_TOTAL_COUNT} -gt 0 ]]; then
    add_vote_table_v2 -0 reaper "" "Unreaped process count: ${REAPER_TOTAL_COUNT}"
  fi
}
