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

function process_counter_coproc_start
{
  if [[ "${OSTYPE}" = Linux && "${DOCKERMODE}" = true ]]; then
    # this is really only even remotely close to
    # accurate under Docker, for the time being.

    echo "Launching process_counter_coproc" >> "${COPROC_LOGFILE}"
    # shellcheck disable=SC2034
    coproc process_counter_coproc {
      declare threadcount
      declare maxthreadcount
      declare cmd

      sleep 2
      while true; do
        threadcount=$(ps -L -u "${USER_ID}" -o lwp 2>/dev/null | wc -l)
        if [[ ${threadcount} -gt ${maxthreadcount} ]]; then
          maxthreadcount="${threadcount}"
          echo "${maxthreadcount}" > "${PATCH_DIR}/threadcounter.txt"
        fi
        read -r -t 2 cmd
        case "${cmd}" in
          exit)
            exit 0
          ;;
        esac
      done
    }
  fi
}
