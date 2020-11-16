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

# Make sure that bash version meets the pre-requisite

if [[ -z "${BASH_VERSINFO[0]}" ]] \
   || [[ "${BASH_VERSINFO[0]}" -lt 3 ]] \
   || [[ "${BASH_VERSINFO[0]}" -eq 3 && "${BASH_VERSINFO[1]}" -lt 2 ]]; then
  echo "bash v3.2+ is required. Sorry."
  exit 1
fi

## @description  Queue up comments to write into bug systems
## @description  that have code review support, if such support
## @description  enabled/available.
## @description  File should be in the form of "file:line[:column]:comment"
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        plugin
## @param        filename
function bugsystem_linecomments_queue
{
  declare plugin=$1
  declare fn=$2
  declare line
  declare linenum
  declare text
  declare columncheck
  declare column
  declare rol
  declare file

  if [[ -z "${BUGLINECOMMENTS}" ]]; then
    return 0
  fi

  for line in "${VOTE_FILTER[@]}"; do
    if [[ "${plugin}" == "${line}" ]]; then
      return 0
    fi
  done

  pushd "${BASEDIR}" >/dev/null || return 1
  while read -r line; do
    file=${line%%:*}

    if [[ ! -e "${file}" ]]; then
      continue
    fi

    rol=${line/#${file}:}
    file=${file#./}
    linenum=${rol%%:*}
    rol=${rol/#${linenum}:}
    columncheck=${rol%%:*}
    if [[ "${columncheck}" =~ ^[0-9]+$ ]]; then
      column=${columncheck}
      text=${rol/#${column}:}
    else
      column="0"
      text=${rol}
    fi

    echo "${file}:${linenum}:${column}:${plugin}:${text}" >> "${PATCH_DIR}/results-full.txt"

  done < "${fn}"

  popd >/dev/null || return 1

}

## @description  Write all of the bugsystem linecomments
## @audience     public
## @stability    evolving
## @replaceable  no
function bugsystem_linecomments_trigger
{
  declare plugin
  declare fn
  declare line
  declare linenum
  declare text
  declare column

  if [[ ! -f "${PATCH_DIR}/results-full.txt" ]]; then
    return 0
  fi

  # sort the file such that all files and lines are now next to each other
  sort -k1,1 -k2,2n -k3,3n -k4,4 "${PATCH_DIR}/results-full.txt" > "${PATCH_DIR}/linecomments-sorted.txt"
  mv "${PATCH_DIR}/linecomments-sorted.txt" "${PATCH_DIR}/results-full.txt"

  while read -r line;do
    fn=${line%%:*}
    fn=${fn#./}  # strip off any leading ./
    rol=${line/#${fn}:}
    linenum=${rol%%:*}
    rol=${rol/#${linenum}:}
    column=${rol%%:*}
    rol=${rol/#${column}:}
    plugin=${rol%%:*}
    text=${rol/#${plugin}:}

    for bugs in ${BUGLINECOMMENTS}; do
      if declare -f "${bugs}_linecomments" >/dev/null;then
        "${bugs}_linecomments" "${fn}" "${linenum}" "${column}" "${plugin}" "${text}"
      fi
    done
  done < "${PATCH_DIR}/results-full.txt"

  for bugs in ${BUGLINECOMMENTS}; do
    if declare -f "${bugs}_linecomments_end" >/dev/null;then
      "${bugs}_linecomments_end"
    fi
  done
}
