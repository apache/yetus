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
#shellcheck disable=SC2034
ISODATESTART=$(date +"%Y-%m-%dT%H:%M:%SZ")

## @description import core library routines
## @audience private
## @stability evolving
function import_core
{
  declare filename

  for filename in "${BINDIR}/core.d"/*; do
    # shellcheck disable=SC1091
    # shellcheck source=core.d/01-common.sh
    . "${filename}"
  done
}

## @description  import plugins then remove the stuff we don't need
## @audience     public
## @stability    stable
## @replaceable  no
function import_including_github
{
  #shellcheck disable=SC2034
  ENABLED_PLUGINS='github'
  importplugins
  yetus_debug "Removing BUILDTOOLS, TESTTYPES, and TESTFORMATS from installed plug-in list"
  #shellcheck disable=SC2034
  BUILDTOOLS=()
  #shellcheck disable=SC2034
  TESTTYPES=()
  #shellcheck disable=SC2034
  TESTFORMATS=()
  #shellcheck disable=SC2034
  BUGSYSTEMS=('github')
  #shellcheck disable=SC2034
  BUGLINECOMMENTS='github'
  #shellcheck disable=SC2034
  GITHUB_STATUS_RECOVER_TOOL=true
  GITHUB_CHECK_ANNOTATIONS=true
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
      --github-annotations=*)
        delete_parameter "${i}"
        GITHUB_CHECK_ANNOTATIONS="${i#*=}"
      ;;
    esac
  done
}

## @description  Print the usage information
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_usage
{
  import_including_github
  github_usage

  echo "${BINNAME} [OPTIONS]"

  yetus_add_option "--github-annotations=<bool>" "Enable GitHub Checks Annoations [default: ${GITHUB_CHECK_ANNOTATIONS}]"
  yetus_add_option "--curl-cmd=<cmd>" "The 'curl' command to use (default 'curl')"
  yetus_add_option "--debug" "If set, then output some extra stuff to stderr"
  yetus_add_option "--grep-cmd=<cmd>" "The 'grep' command to use (default 'grep')"
  yetus_add_option "--ignore-unknown-options=<bool>" "Continue despite unknown options (default: ${IGNORE_UNKNOWN_OPTIONS})"
  yetus_add_option "--patch-dir=<dir>" "The directory for working and output files (default '/tmp/test-patch-${PROJECT_NAME}/pid')"

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

trap "cleanup_and_exit 1" HUP INT QUIT TERM

setup_parameter_tracker

import_core

setup_defaults

parse_args "$@"

import_including_github

parse_args_plugins "$@"

if [[ "${#PARAMETER_TRACKER}" -gt 0 ]]; then
  yetus_error "ERROR: Unprocessed flag(s): ${PARAMETER_TRACKER[*]}"
  if [[ "${IGNORE_UNKNOWN_OPTIONS}" == false ]]; then
    cleanup_and_exit 1
  fi
fi

github_status_recovery
