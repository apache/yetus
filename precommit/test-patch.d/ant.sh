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

if [[ -z "${ANT_HOME:-}" ]]; then
  ANT=ant
else
  ANT=${ANT_HOME}/bin/ant
fi

add_build_tool ant

declare -a ANT_ARGS=("-noinput")

function ant_usage
{
  yetus_add_option "--ant-cmd=<cmd>" "The 'ant' command to use (default \${ANT_HOME}/bin/ant, or 'ant')"
}

function ant_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
      --ant-cmd=*)
        ANT=${i#*=}
      ;;
    esac
  done

  # if we requested offline, pass that to ant
  if [[ ${OFFLINE} == "true" ]]; then
    ANT_ARGS=("${ANT_ARGS[@]}" -Doffline=)
  fi
}

function ant_initialize
{
  # we need to do this before docker kicks in
  if [[ -e "${HOME}/.ivy2"
     && ! -d "${HOME}/.ivy2" ]]; then
    yetus_error "ERROR: ${HOME}/.ivy2 is not a directory."
    return 1
  elif [[ ! -e "${HOME}/.ivy2" ]]; then
    yetus_debug "Creating ${HOME}/.ivy2"
    mkdir -p "${HOME}/.ivy2"
  fi
}

function ant_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ build\.xml$
     || ${filename} =~ ivy\.xml$ ]]; then
    yetus_debug "tests/compile: ${filename}"
    add_test compile
  fi
}

function ant_buildfile
{
  echo "build.xml"
}

function ant_executor
{
  echo "${ANT}" "${ANT_ARGS[@]}"
}

function ant_modules_worker
{
  declare repostatus=$1
  declare tst=$2
  shift 2

  # shellcheck disable=SC2034
  UNSUPPORTED_TEST=false

  case ${tst} in
    findbugs)
      modules_workers "${repostatus}" findbugs findbugs
    ;;
    compile)
      modules_workers "${repostatus}" compile
    ;;
    distclean)
      modules_workers "${repostatus}" distclean clean
    ;;
    javadoc)
      modules_workers "${repostatus}" javadoc clean javadoc
    ;;
    unit)
      modules_workers "${repostatus}" unit
    ;;
    *)
      # shellcheck disable=SC2034
      UNSUPPORTED_TEST=true
      if [[ ${repostatus} = patch ]]; then
        add_footer_table "${tst}" "not supported by the ${BUILDTOOL} plugin"
      fi
      yetus_error "WARNING: ${tst} is unsupported by ${BUILDTOOL}"
      return 1
    ;;
  esac
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function ant_javac_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC2016
  ${GREP} "\[javac\] /" "${input}" > "${output}"
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function ant_javadoc_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC2016
  ${GREP} "\[javadoc\] /" "${input}" > "${output}"
}

function ant_builtin_personality_modules
{
  local repostatus=$1
  local testtype=$2

  local module

  yetus_debug "Using builtin personality_modules"
  yetus_debug "Personality: ${repostatus} ${testtype}"

  clear_personality_queue

  for module in "${CHANGED_MODULES[@]}"; do
    personality_enqueue_module "${module}"
  done
}

function ant_builtin_personality_file_tests
{
  local filename=$1

  yetus_debug "Using builtin ant personality_file_tests"

  if [[ ${filename} =~ \.sh
       || ${filename} =~ \.cmd
       ]]; then
    yetus_debug "tests/shell: ${filename}"
  elif [[ ${filename} =~ \.c$
       || ${filename} =~ \.cc$
       || ${filename} =~ \.h$
       || ${filename} =~ \.hh$
       || ${filename} =~ \.proto$
       || ${filename} =~ src/test
       || ${filename} =~ \.cmake$
       || ${filename} =~ CMakeLists.txt
       ]]; then
    yetus_debug "tests/units: ${filename}"
    add_test javac
    add_test unit
  elif [[ ${filename} =~ build.xml
       || ${filename} =~ ivy.xml
       || ${filename} =~ \.java$
       ]]; then
      yetus_debug "tests/javadoc+units: ${filename}"
      add_test javac
      add_test javadoc
      add_test unit
  fi

  if [[ ${filename} =~ \.java$ ]]; then
    add_test findbugs
  fi
}

function ant_docker_support
{
  DOCKER_EXTRAARGS=("${DOCKER_EXTRAARGS}" "-v" "${HOME}/.ivy2:${HOME}/.ivy2")
}
