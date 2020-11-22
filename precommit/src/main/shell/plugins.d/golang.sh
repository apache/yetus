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

add_test_type golang

GOEXE=$(command -v go 2>/dev/null)

declare -a GOMOD_DIRS
GOMOD_DIRS_CONTROL=reset

## @description  Usage info for go plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function golang_usage
{
  yetus_add_option "--golang-go=<file>" "Location of the go binary (default: \"${GOEXE:-not found}\")"
}

## @description  Option parsing for go plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function golang_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --golang-go=*)
        GOEXE=${i#*=}
        delete_parameter "${i}"
      ;;
    esac
  done
}

## @description  find all non-vendor directories that have a go.mod file
## @audience     public
## @stability    evolving
## @replaceable  yes
function golang_gomod_find
{
  declare input

  if [[ "${GOMOD_DIRS_CONTROL}" == reset ]]; then
    GOMOD_DIRS=()
    while read -r; do
      if [[ ! "${REPLY}" =~ /vendor/ ]] &&
         [[ ! "${REPLY}" =~ ^vendor ]]; then
        input=${REPLY%%/go.mod}
        GOMOD_DIRS+=("${input}")
      fi
    done < <(find "${BASEDIR}" -name go.mod)
    GOMOD_DIRS_CONTROL=filled
  fi
}


## @description  Determine if a file is in GOMOD_DIRS[@]
## @audience     public
## @stability    evolving
## @replaceable  yes
## @return       all matching dirs
function golang_gomod_file
{
  declare fn=${1}

  yetus_find_deepest_directory GOMOD_DIRS "${BASEDIR}/${fn}"
}


## @description  discover files to check
## @audience     private
## @stability    stable
## @replaceable  yes
function golang_filefilter
{
  declare filename=$1

  golang_gomod_find

  if [[ "${filename}" =~ \.(c|h|go|s|cc)$ ]] ||
     [[ "${filename}" =~ go.mod$ ]]; then
    if golang_gomod_file "${filename}" >/dev/null; then
      yetus_debug "tests/golang: ${filename}"
      add_test golang
      add_test compile
    fi
  fi
}

## @description  check for golang compiler errors
## @audience     private
## @stability    stable
## @replaceable  no
function golang_precompile
{
  GOMOD_DIRS_CONTROL=reset
}

## @description  check for golang compiler errors
## @audience     private
## @stability    stable
## @replaceable  no
function golang_compile
{
  declare codebase=$1
  declare multijdkmode=$2

  if ! verify_needed_test golang; then
    return 0
  fi

  if [[ ${codebase} = patch ]]; then
    module_postlog_compare compile golang "${multijdkmode}"
  fi
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  yes
function golang_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC1117
  "${GREP}" -i -E "^.*\.go\:[[:digit:]]*\:" "${input}" > "${output}"
}

## @description  go post
## @audience     private
## @stability    evolving
## @replaceable  yes
function golang_postapply
{
  if [[ -z "${GOEXE}" ]]; then
    # shellcheck disable=SC2016
    version=$("${GOEXE}" version 2>&1 | "${AWK}" '{print $3}' 2>&1)
    add_version_data golang "${version#* }"
  fi
}

## @description  set volumes and options as appropriate for maven
## @audience     private
## @stability    evolving
## @replaceable  yes
function golang_docker_support
{
  add_docker_env CGO_LDFLAGS
  add_docker_env CGO_ENABLED
  add_docker_env GO111MODULE
  add_docker_env GOPATH
}


## @description  set volumes and options as appropriate for maven
## @audience     private
## @stability    evolving
## @replaceable  yes
function golang_clean
{
  git_checkout_force
}