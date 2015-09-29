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

## @description  Print a message to stderr
## @audience     public
## @stability    stable
## @replaceable  no
## @param        string
function yetus_error
{
  echo "$*" 1>&2
}

## @description  Print a message to stderr if --debug is turned on
## @audience     public
## @stability    stable
## @replaceable  no
## @param        string
function yetus_debug
{
  if [[ "${YETUS_SHELL_SCRIPT_DEBUG}" = true ]]; then
    echo "[$(date) DEBUG]: $*" 1>&2
  fi
}

## @description  Given variable $1 delete $2 from it
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_delete_entry
{
  if [[ ${!1} =~ \ ${2}\  ]] ; then
    yetus_debug "Removing ${2} from ${1}"
    eval "${1}"=\""${!1// ${2} }"\"
  fi
}

## @description  Given variable $1 add $2 to it
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_add_entry
{
  if [[ ! ${!1} =~ \ ${2}\  ]] ; then
    yetus_debug "Adding ${2} to ${1}"
    #shellcheck disable=SC2140
    eval "${1}"=\""${!1} ${2} "\"
  fi
}

## @description  Given variable $1 determine if $2 is in it
## @audience     public
## @stability    stable
## @replaceable  no
## @returns      1 = yes, 0 = no
function yetus_verify_entry
{
  [[ ! ${!1} =~ \ ${2}\  ]]
}

## @description  run the command, sending stdout and stderr to the given filename
## @audience     public
## @stability    stable
## @param        filename
## @param        command
## @param        [..]
## @replaceable  no
## @returns      $?
function yetus_run_and_redirect
{
  declare logfile=$1
  shift

  # to the log
  {
    date
    echo "cd $(pwd)"
    echo "${*}"
  } >> "${logfile}"
  # run the actual command
  "${@}" >> "${logfile}" 2>&1
}
