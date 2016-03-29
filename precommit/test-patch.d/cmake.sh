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
# WITHOUT WARRCMAKEIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

add_build_tool cmake

CMAKE=cmake
CMAKE_BUILD_DIR="build"
CMAKE_ROOT_BUILD=true

## @description  cmake usage hook
## @audience     private
## @stability    evolving
## @replaceable  no
function cmake_usage
{
  yetus_add_option "--cmake-build-dir=<cmd>" "build directory off of each module to use (default: ${CMAKE_BUILD_DIR})"
  yetus_add_option "--cmake-cmd=<cmd>" "The 'cmake' command to use (default 'cmake')"
  yetus_add_option "--cmake-root-build=<bool>" "Only build off of root, don't use modules (default: ${CMAKE_ROOT_BUILD})"
}

## @description  cmake argument parser
## @audience     private
## @stability    evolving
## @param        args
function cmake_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --cmake-build-dir=*)
        CMAKE_BUILD_DIR=${i#*=}
      ;;
      --cmake-cmd=*)
        CMAKE=${i#*=}
      ;;
      --cmake-root-build=*)
        CMAKE_ROOT_BUILD=${i#*=}
      ;;
    esac
  done
}

## @description  initialize cmake
## @audience     private
## @stability    evolving
## @replaceable  no
function cmake_initialize
{
  if ! declare -f make_executor > /dev/null; then
    yetus_error "ERROR: cmake requires make to be enabled."
    return 1
  fi

}

## @description  cmake module manipulation
## @audience     private
## @stability    evolving
## @replaceable  no
function cmake_reorder_modules
{
  if [[ "${CMAKE_ROOT_BUILD}" = true ]]; then
    #shellcheck disable=SC2034
    BUILDTOOLCWD="@@@BASEDIR@@@/${CMAKE_BUILD_DIR}"
    #shellcheck disable=SC2034
    CHANGED_MODULES=(".")
    #shellcheck disable=SC2034
    CHANGED_UNION_MODULES="."
  else
    #shellcheck disable=SC2034
    BUILDTOOLCWD="@@@MODULEDIR@@@/${CMAKE_BUILD_DIR}"
  fi
}

## @description  get the name of the cmake build filename
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       cmake build file
function cmake_buildfile
{
  echo "CMakeLists.txt"
}

## @description  get the name of the cmake binary
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       filename
## @param        cmake params
function cmake_executor
{
  if [[ $1 = "CMakeLists.txt" ]]; then
    echo "${CMAKE}"
  else
    make_executor "$@"
  fi
}

## @description  precompile for cmake
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       status
## @param        repostatus
function cmake_precompile
{
  declare repostatus=$1
  declare result=0

  if [[ ${BUILDTOOL} != cmake ]]; then
    return 0
  fi

  if [[ "${repostatus}" = branch ]]; then
    # shellcheck disable=SC2153
    big_console_header "cmake CMakeLists.txt: ${PATCH_BRANCH}"
  else
    big_console_header "cmake CMakeLists.txt: ${BUILDMODE}"
  fi

  personality_modules "${repostatus}" CMakeLists.txt

  modules_workers "${repostatus}" CMakeLists.txt @@@MODULEDIR@@@
  result=$?
  modules_messages "${repostatus}" CMakeLists.txt true
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

## @description  cmake worker
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       status
## @param        repostatus
## @param        test
function cmake_modules_worker
{
  make_modules_worker "$@"
}

## @description  cmake module queuer
## @audience     private
## @stability    evolving
## @replaceable  no
function cmake_builtin_personality_modules
{
  make_builtin_personality_modules "$@"
}

## @description  cmake test determiner
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        filename
function cmake_builtin_personality_file_tests
{
  declare filename=$1

  if [[ ${filename} =~ CMakeLists.txt$ ]]; then
    yetus_debug "tests/units: ${filename}"
    add_test compile
    add_test unit
  else
    make_builtin_personality_file_tests "${filename}"
  fi
}
