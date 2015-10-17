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

function cc_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.c$
      || ${filename} =~ \.cc$
      || ${filename} =~ \.cpp$
      || ${filename} =~ \.cxx$
      || ${filename} =~ \.h$
      || ${filename} =~ \.hh$
     ]]; then
   yetus_debug "tests/cc: ${filename}"
   add_test cc
   add_test compile
  fi
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

  verify_needed_test cc
  if [[ $? = 0 ]]; then
    return 0
  fi

  if [[ ${codebase} = patch ]]; then
    generic_postlog_compare compile cc "${multijdkmode}"
  fi
}

function cc_count_probs
{
  declare warningfile=$1

  #shellcheck disable=SC2016,SC2046
  ${GREP} -E '^.*\.(c|cc|h|hh)\:[[:digit:]]*\:' "${warningfile}" | ${AWK} '{sum+=1} END {print sum}'
}
