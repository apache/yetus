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

add_build_tool gradle

declare -a GRADLE_ARGS=()

function gradle_usage
{
  yetus_add_option "--gradle-cmd=<cmd>" "The 'gradle' command to use (default 'gradle')"
  yetus_add_option "--gradlew-cmd=<cmd>" "The 'gradlew' command to use (default 'basedir/gradlew')"
}

function gradle_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
      --gradle-cmd=*)
        GRADLE=${i#*=}
      ;;
      --gradlew-cmd=*)
        GRADLEW=${i#*=}
      ;;
    esac
  done

  # if we requested offline, pass that to mvn
  if [[ ${OFFLINE} == "true" ]]; then
    GRADLE_ARGS=("${GRADLE_ARGS[@]}" --offline)
  fi

  GRADLE=${GRADLE:-gradle}
  GRADLEW=${GRADLEW:-"${BASEDIR}/gradlew"}
}

function gradle_initialize
{
  if [[ "${BUILDTOOL}" = gradle ]]; then
    # shellcheck disable=SC2034
    BUILDTOOLCWD=basedir
  fi

  # we need to do this before docker kicks in
  if [[ -e "${HOME}/.gradle"
     && ! -d "${HOME}/.gradle" ]]; then
    yetus_error "ERROR: ${HOME}/.gradle is not a directory."
    return 1
  elif [[ ! -e "${HOME}/.gradle" ]]; then
    yetus_debug "Creating ${HOME}/.gradle"
    mkdir -p "${HOME}/.gradle"
  fi
}

function gradle_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ build\.gradle$
     || ${filename} =~ gradlew$
     || ${filename} =~ gradle\.properties$
     || ${filename} =~ wrapper\.gradle$ ]]; then
    yetus_debug "tests/compile: ${filename}"
    add_test compile
  fi
}

function gradle_buildfile
{
  echo "gradlew"
}

function gradle_executor
{
  echo "${GRADLEW}" "${GRADLE_ARGS[@]}"
}

## @description  Bootstrap gradle
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function gradle_precompile
{
  declare repostatus=$1
  declare result=0

  if [[ ${BUILDTOOL} != gradle ]]; then
    return 0
  fi

  if [[ "${repostatus}" = branch ]]; then
    # shellcheck disable=SC2153
    big_console_header "gradle boostrap: ${PATCH_BRANCH}"
  else
    big_console_header "gradle bootstrap: ${BUILDMODE}"
  fi

  personality_modules "${repostatus}" gradleboot

  pushd "${BASEDIR}" >/dev/null
  echo_and_redirect "${PATCH_DIR}/${repostatus}-gradle-bootstrap.txt" gradle -b bootstrap.gradle
  popd >/dev/null

  modules_workers "${repostatus}" gradleboot
  result=$?
  modules_messages "${repostatus}" gradleboot true
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function gradle_javac_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC2016,SC2046
  ${GREP} "\.java" "${input}" > "${output}"
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function gradle_javadoc_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC2016,SC2046
  ${GREP} "javadoc.*\.java" "${input}" > "${output}"
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function gradle_scaladoc_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC2016,SC2046
  ${GREP} "^\[ant:scaladoc\] /.*\.scala" "${input}" > "${output}"
}

function gradle_modules_worker
{
  declare repostatus=$1
  declare tst=$2
  shift 2

  # shellcheck disable=SC2034
  UNSUPPORTED_TEST=false

  case ${tst} in
    checkstyle)
      modules_workers "${repostatus}" "${tst}" checkstyleMain checkstyleTest
    ;;
    compile)
      modules_workers "${repostatus}" "${tst}"
    ;;
    distclean)
      modules_workers "${repostatus}" clean
    ;;
    javadoc)
      modules_workers "${repostatus}" "${tst}" javadoc
    ;;
    scaladoc)
      modules_workers "${repostatus}" "${tst}" scaladoc
    ;;
    unit)
      modules_workers "${repostatus}" "${tst}" test
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

function gradle_builtin_personality_modules
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

function gradle_builtin_personality_file_tests
{
  local filename=$1

  yetus_debug "Using builtin gradle personality_file_tests"

  if [[ ${filename} =~ src/main/webapp ]]; then
    yetus_debug "tests/webapp: ${filename}"
  elif [[ ${filename} =~ \.sh
       || ${filename} =~ \.cmd
       || ${filename} =~ src/main/scripts
       || ${filename} =~ src/test/scripts
       ]]; then
    yetus_debug "tests/shell: ${filename}"
  elif [[ ${filename} =~ \.c$
       || ${filename} =~ \.cc$
       || ${filename} =~ \.h$
       || ${filename} =~ \.hh$
       || ${filename} =~ \.proto$
       || ${filename} =~ \.cmake$
       || ${filename} =~ CMakeLists.txt
       ]]; then
    yetus_debug "tests/units: ${filename}"
    add_test cc
    add_test unit
  elif [[ ${filename} =~ \.scala$ ]]; then
    add_test scalac
    add_test scaladoc
    add_test unit
  elif [[ ${filename} =~ build.xml$
       || ${filename} =~ pom.xml$
       || ${filename} =~ \.java$
       ]]; then
    yetus_debug "tests/javadoc+units: ${filename}"
    add_test javac
    add_test javadoc
    add_test unit
  elif [[ ${filename} =~ src/main ]]; then
    yetus_debug "tests/generic+units: ${filename}"
    add_test compile
    add_test unit
  fi

  if [[ ${filename} =~ src/test ]]; then
    yetus_debug "tests"
    add_test unit
  fi

  if [[ ${filename} =~ \.java$ ]]; then
    add_test findbugs
  fi
}

function gradle_docker_support
{
  DOCKER_EXTRAARGS=("${DOCKER_EXTRAARGS[@]}" "-v" "${HOME}/.gradle:${HOME}/.gradle")
}
