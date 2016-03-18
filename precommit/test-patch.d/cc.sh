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

add_test_type cc

CC_EXT_RE='(c|cc|cpp|cxx|c\+\+|h|hh|hpp|hxx|h\+\+)'

function cc_filefilter
{
  declare filename=$1

  shopt -s nocasematch
  if [[ ${filename} =~ \.${CC_EXT_RE}$ ]]; then
    shopt -u nocasematch
    yetus_debug "tests/cc: ${filename}"
    add_test cc
    add_test compile
  fi
  shopt -u nocasematch
}

## @description  check for C/C++ compiler errors
## @audience     private
## @stability    stable
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function cc_compile
{
  declare codebase=$1
  declare multijdkmode=$2

  if ! verify_needed_test cc; then
    return 0
  fi

  if [[ ${codebase} = patch ]]; then
    generic_postlog_compare compile cc "${multijdkmode}"
  fi
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function cc_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC2016,SC2046
  ${GREP} -i -E "^.*\.${CC_EXT_RE}\:[[:digit:]]*\:" "${input}" > "${output}"
}
