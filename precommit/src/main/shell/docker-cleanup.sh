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

# no shelldocs required from this file
# SHELLDOC-IGNORE

# Make sure that bash version meets the pre-requisite

if [[ -z "${BASH_VERSINFO[0]}" ]] \
   || [[ "${BASH_VERSINFO[0]}" -lt 3 ]] \
   || [[ "${BASH_VERSINFO[0]}" -eq 3 && "${BASH_VERSINFO[1]}" -lt 2 ]]; then
  echo "bash v3.2+ is required. Sorry."
  exit 1
fi

this="${BASH_SOURCE-$0}"
BINDIR=$(cd -P -- "$(dirname -- "${this}")" >/dev/null && pwd -P)
BINNAME=${this##*/}
BINNAME=${BINNAME%.sh}
#shellcheck disable=SC2034
STARTINGDIR=$(pwd)
#shellcheck disable=SC2034
USER_PARAMS=("$@")
#shellcheck disable=SC2034
QATESTMODE=false

# dummy functions
function add_vote_table_v2
{
  true
}

function add_footer_table
{
  true
}

function bugsystem_finalreport
{
  true
}

## @description import core library routines
## @audience private
## @stability evolving
function import_core
{
  declare filename

  for filename in "${BINDIR}/core.d"/*; do
    # shellcheck source=SCRIPTDIR/core.d/01-common.sh
    . "${filename}"
  done
}

## @description  import plugins then remove the stuff we don't need
## @audience     public
## @stability    stable
## @replaceable  no
function import_and_clean
{
  importplugins
  yetus_debug "Removing BUILDTOOLS, TESTTYPES, and TESTFORMATS from installed plug-in list"
  #shellcheck disable=SC2034
  BUILDTOOLS=()
  #shellcheck disable=SC2034
  TESTTYPES=()
  #shellcheck disable=SC2034
  TESTFORMATS=()

  #shellcheck disable=SC2034
  DOCKER_CLEANUP_CMD=true
  #shellcheck disable=SC2034
  DOCKERSUPPORT=true
  #shellcheck disable=SC2034
  ROBOT=true
  #shellcheck disable=SC2034
  DOCKERFAIL="fail"
}

## @description  Clean the filesystem as appropriate and then exit
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function cleanup_and_exit
{
  local result=$1

  if [[ ${PATCH_DIR} =~ ^/tmp/yetus
    && -d ${PATCH_DIR} ]]; then
    rm -rf "${PATCH_DIR}"
  fi

  # shellcheck disable=SC2086
  exit ${result}
}

## @description  Setup the default global variables
## @audience     public
## @stability    stable
## @replaceable  no
function setup_defaults
{
  common_defaults
}

## @description  Interpret the command line parameters
## @audience     private
## @stability    stable
## @replaceable  no
## @param        $@
## @return       May exit on failure
function parse_args
{
  declare i

  common_args "$@"

  for i in "$@"; do
    case ${i} in
      --robot)
        delete_parameter "${i}"
        # shellcheck disable=SC2034
        ROBOT=true
      ;;
      --sentinel)
        delete_parameter "${i}"
        # shellcheck disable=SC2034
        ROBOT=true
        # shellcheck disable=SC2034
        SENTINEL=true
        yetus_add_array_element EXEC_MODES Sentinel
      ;;
    esac
  done

  docker_parse_args "$@"
}

## @description  Print the usage information
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_usage
{
  import_and_clean

  echo "${BINNAME} [OPTIONS]"

  yetus_add_option "--debug" "If set, then output some extra stuff to stderr"
  yetus_add_option "--ignore-unknown-options=<bool>" "Continue despite unknown options (default: ${IGNORE_UNKNOWN_OPTIONS})"
  yetus_add_option "--robot" "Assume this is an automated run"
  yetus_add_option "--sentinel" "A very aggressive robot (auto: --robot)"
  docker_usage

  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage
}

## @description  Large display for the user console
## @audience     public
## @stability    stable
## @replaceable  no
## @param        string
## @return       large chunk of text
function big_console_header
{
  local text="$*"
  local spacing=$(( (75+${#text}) /2 ))
  printf '\n\n'
  echo "============================================================================"
  echo "============================================================================"
  printf '%*s\n'  ${spacing} "${text}"
  echo "============================================================================"
  echo "============================================================================"
  printf '\n\n'
}

## @description setup the parameter tracker for param errors
## @audience    private
## @stability   evolving
function setup_parameter_tracker
{
  declare i

  for i in "${USER_PARAMS[@]}"; do
    if [[ "${i}" =~ ^-- ]]; then
      i=${i%=*}
      PARAMETER_TRACKER+=("${i}")
    fi
  done
}

setup_parameter_tracker

import_core

yetus_set_trap_handler generic_signal_handler HUP INT QUIT TERM

setup_defaults

parse_args "$@"

import_and_clean

parse_args_plugins "$@"

if [[ "${#PARAMETER_TRACKER}" -gt 0 ]]; then
  yetus_error "ERROR: Unprocessed flag(s): ${PARAMETER_TRACKER[*]}"
  if [[ "${IGNORE_UNKNOWN_OPTIONS}" == false ]]; then
    cleanup_and_exit 1
  fi
fi

docker_initialize
plugins_initialize

docker_cleanup
RESULT=$?

cleanup_and_exit ${RESULT}
