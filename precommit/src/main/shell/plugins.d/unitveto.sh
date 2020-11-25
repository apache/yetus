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

add_test_type unitveto

UNITVETO_RE=${UNITVETO_RE:-}
UNITVETO_LOGFILE="results-unitveto.txt"

function unitveto_filefilter
{
  declare filename=$1

  if [[ -n "${UNITVETO_RE}"
     && ${filename} =~ ${UNITVETO_RE} ]]; then
    yetus_debug "unitveto: ${filename} matched"
    echo "${filename}:1:0:unitveto:matches ${UNITVETO_RE}" \
      >> "${PATCH_DIR}/${UNITVETO_LOGFILE}"
    add_test unitveto
  fi
}

function unitveto_usage
{
  yetus_add_option "--unitveto-re=<regex>" "Regex to automatically -1 due to manual test requirements"
}

function unitveto_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --unitveto-re=*)
        delete_parameter "${i}"
        UNITVETO_RE=${i#*=}
      ;;
    esac
  done
}

function unitveto_patchfile
{
  if ! verify_needed_test unit; then
    return 0
  fi

  if ! verify_needed_test unitveto; then
    return 0
  fi

  add_vote_table_v2 -1 unitveto "@@BASE@@/${UNITVETO_LOGFILE}" "Patch requires manual testing."
  bugsystem_linecomments_queue unitveto "${PATCH_DIR}/${UNITVETO_LOGFILE}"
  return 1
}
