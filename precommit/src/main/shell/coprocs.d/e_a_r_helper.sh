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

## @description helper function for echo_and_redirect
## @audience private
## @stability evolving
## @replaceable no
function e_a_r_helper
{
  declare logfile=$1
  shift
  declare params=("${@}")

  echo "Launching yrr_coproc" >> "${COPROC_LOGFILE}"
  # shellcheck disable=SC2034
  coproc yrr_coproc {
    ulimit -Su "${PROC_LIMIT}"
    yetus_run_and_redirect "${logfile}" "${params[@]}"
  }
}