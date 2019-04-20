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

# SHELLDOC-IGNORE

add_test_type golang

GOEXE=$(command -v go 2>/dev/null)

## @description  Usage info for slack plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function golang_usage
{
  yetus_add_option "--golang-go=<cmd>" "Location of the go binary (default: \"${GOEXE:-not found}\")"
}

## @description  Option parsing for slack plugin
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
      ;;
    esac
  done
}

## @description  discover files to check
## @audience     private
## @stability    stable
## @replaceable  no
## @return       0 on sugolangess
## @return       1 on failure
function golang_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.go$ ]]; then
    yetus_debug "tests/golang: ${filename}"
    add_test golang
    add_test compile
  fi
}

## @description  check for golang compiler errors
## @audience     private
## @stability    stable
## @replaceable  no
## @return       0 on sugolangess
## @return       1 on failure
function golang_compile
{
  declare codebase=$1
  declare multijdkmode=$2

  if ! verify_needed_test golang; then
    return 0
  fi

  if [[ ${codebase} = patch ]]; then
    generic_postlog_compare compile golang "${multijdkmode}"
  fi
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function golang_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC1117
  "${GREP}" -i -E "^.*\.go\:[[:digit:]]*\:" "${input}" > "${output}"
}

function golang_postapply
{
  if [[ -z "${GOEXE}" ]]; then
    # shellcheck disable=SC2016
    version=$("${GOEXE}" version 2>&1 | "${AWK}" '{print $3}' 2>&1)
    add_version_data golang "${version#* }"
  fi
}
