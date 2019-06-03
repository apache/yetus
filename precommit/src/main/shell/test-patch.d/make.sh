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

add_build_tool make

MAKE=$(command -v make 2>/dev/null)
MAKEFILE=Makefile

## @description  make usage hook
## @audience     private
## @stability    evolving
## @replaceable  no
function make_usage
{
  yetus_add_option "--make-cmd=<file>" "The 'make' command to use (default: '${MAKE}')"
  yetus_add_option "--make-file=<filename>" "The name of the file the make cmd should work on (default: '${MAKEFILE}')"
  yetus_add_option "--make-use-git-clean" "Instead of 'make clean' use 'git clean' to reset the source checkout"
}

## @description  precheck make
## @audience     private
## @stability    evolving
## @replaceable  no
function make_precheck
{
  declare make_version
  if ! verify_command make "${MAKE}"; then
    add_vote_table_v2 -1 make "" "make was not available."
    return 1
  fi
  # finally let folks know what version they'll be dealing with.
  if make_version=$(set -o pipefail; ${MAKE} --version 2>/dev/null | head -n 1  2>/dev/null) && [ -n "${make_version}" ]; then
    add_version_data make "${make_version}"
  fi
  return 0
}

## @description  make argument parser
## @audience     private
## @stability    evolving
## @param        args
function make_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --make-cmd=*)
        delete_parameter "${i}"
        MAKE=${i#*=}
      ;;
      --make-file=*)
        delete_parameter "${i}"
        MAKEFILE=${i#*=}
      ;;
      --make-use-git-clean)
        delete_parameter "${i}"
        MAKE_GITCLEAN=true
      ;;
    esac
  done
}

## @description  get the name of the make build filename
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       make build file
function make_buildfile
{
  echo "${MAKEFILE}"
}

## @description  get the name of the make binary
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       filename
## @param        testname
function make_executor
{
  echo "${MAKE} ${MAKE_ARGS[*]}"
}

## @description  make worker
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       status
## @param        repostatus
## @param        test
function make_modules_worker
{
  declare repostatus=$1
  declare tst=$2
  shift 2

  # shellcheck disable=SC2034
  UNSUPPORTED_TEST=false

  case ${tst} in
    compile)
      modules_workers "${repostatus}" "${tst}"
    ;;
    distclean)
      if [[ ${MAKE_GITCLEAN} = true ]];then
        git_clean
      else
        modules_workers "${repostatus}" distclean clean
      fi
    ;;
    unit)
      modules_workers "${repostatus}" unit test
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

## @description  make module queuer
## @audience     private
## @stability    evolving
## @replaceable  no
function make_builtin_personality_modules
{
  declare repostatus=$1
  declare testtype=$2

  declare module

  yetus_debug "Using builtin personality_modules"
  yetus_debug "Personality: ${repostatus} ${testtype}"

  clear_personality_queue

  for module in "${CHANGED_MODULES[@]}"; do
    personality_enqueue_module "${module}"
  done
}

## @description  make test determiner
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        filename
function make_builtin_personality_file_tests
{
  declare filename=$1

  yetus_debug "Using builtin make personality_file_tests"

  if [[ ${filename} =~ \.c$
       || ${filename} =~ \.cc$
       || ${filename} =~ \.h$
       || ${filename} =~ \.hh$
       || ${filename} =~ \.hh\.in$
       || ${filename} =~ \.proto$
       || ${filename} =~ \.make$
       || ${filename} =~ Makefile$
       ]]; then
    yetus_debug "tests/units: ${filename}"
    add_test compile
    add_test unit
  fi
}
