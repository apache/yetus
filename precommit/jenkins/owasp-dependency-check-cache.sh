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

INSTALL_URL_DEFAULT="http://dl.bintray.com/jeremy-long/owasp/dependency-check-3.1.2-release.zip"

set -e
function usage {
  echo "Usage: ${0} [options] /path/to/data/cache/directory"
  echo ""
  echo "    --dependency-check /path/to/exec  Optionally point to 'dependency-check' cli."
  echo "    --install /path/to/dir            download and cache dependency-check cli."
  echo "    --install-url url                 where the cli download is."
  echo "                                          default: ${INSTALL_URL_DEFAULT}"
  echo "    --verbose /path/to/log            log verbose debug information at given path."
  echo "    --help                            show this usage message."
  exit 1
}
# if no args specified, show usage
if [ $# -lt 1 ]; then
  usage
fi

# Get arguments
declare dependency_check
declare install
declare install_url="${INSTALL_URL_DEFAULT}"
declare cache_dir
declare -a verbose
while [ $# -gt 0 ]
do
  case "$1" in
    --dependency-check) shift; dependency_check=$1; shift;;
    # make this an absolute path
    --install) shift; install="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"; shift;;
    --install-url) shift; install_url=$1; shift;;
    --verbose) shift; verbose=(--log "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"); shift;;
    --) shift; break;;
    -*) usage ;;
    *)  break;;  # terminate while loop
  esac
done

# Should still have the required arg
if [ $# -lt 1 ]; then
  usage
fi
# Absolute path
cache_dir="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"

# If we didn't point to an exec, check for install cache
if [ -z "${dependency_check}" ] && [ -n "${install}" ]; then
  # if we have things cached, just point at it otherwise do an install
  if [ ! -x "${install}/dependency-check/bin/dependency-check.sh" ]; then
    if [ ! -d "${install}" ]; then
      mkdir "${install}"
    fi
    echo "Downloading '${install_url}' to '${install}'" >&2
    curl --location -o "${install}/dependency-check.zip" "${install_url}"
    unzip "${install}/dependency-check.zip" -d "${install}"
    rm -f "${install}/dependency-check.zip"
  fi
  dependency_check="${install}/dependency-check/bin/dependency-check.sh"
fi

# if we don't point at something by now, give the path a try
if [ -z "${dependency_check}" ]; then
  dependency_check=$(which dependency-check)
fi
echo "Dependency check CLI version: $("${dependency_check}" --version)"
"${dependency_check}" --updateonly --data "${cache_dir}" "${verbose[@]}"
echo "Done updating cache in '${cache_dir}'"
