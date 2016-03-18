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

add_test_type javac
add_test_type javadoc

yetus_add_entry JDK_TEST_LIST javadoc

JAVA_INITIALIZED=false

function initialize_java
{
  local i
  local jdkdir
  local tmplist

  if [[ ${JAVA_INITIALIZED} == true ]]; then
    return
  else
    JAVA_INITIALIZED=true
  fi

  # if we are in pre-docker mode, don't do any of
  # this work since it's all going to be wrong anyway
  if [[ "${DOCKERSUPPORT}" = "true" ]]; then
    return 0
  fi

  if declare -f maven_add_install >/dev/null 2>&1; then
    maven_add_install javadoc
  fi

  if [[ -z ${JAVA_HOME:-} ]]; then
    case ${OSTYPE} in
      Darwin)
        if [[ -z "${JAVA_HOME}" ]]; then
          if [[ -x /usr/libexec/java_home ]]; then
            JAVA_HOME="$(/usr/libexec/java_home)"
            export JAVA_HOME
          else
            export JAVA_HOME=/Library/Java/Home
          fi
        fi
      ;;
      *)
        yetus_error "WARNING: JAVA_HOME not defined. Disabling java tests."
        delete_test javac
        delete_test javadoc
        return 1
      ;;
    esac
  fi

  JAVA_HOME=$(yetus_abs "${JAVA_HOME}")

  for i in ${JDK_DIR_LIST}; do
    if [[ -d "${i}" ]]; then
      jdkdir=$(yetus_abs "${i}")
      if [[ ${jdkdir} != "${JAVA_HOME}" ]]; then
        tmplist="${tmplist} ${jdkdir}"
      fi
    else
      yetus_error "WARNING: Cannot locate JDK directory ${i}: ignoring"
    fi
  done

  JDK_DIR_LIST="${tmplist} ${JAVA_HOME}"
  JDK_DIR_LIST=${JDK_DIR_LIST/ }
}

function javac_initialize
{
  initialize_java
}

function javadoc_initialize
{
  initialize_java
}

## @description  Verify that ${JAVA_HOME} is defined
## @audience     public
## @stability    stable
## @replaceable  no
## @return       1 - no JAVA_HOME
## @return       0 - JAVA_HOME defined
function javac_precheck
{
  declare javaversion
  declare listofjdks
  declare i

  start_clock

  if [[ -z ${JAVA_HOME:-} ]]; then
    yetus_error "ERROR: JAVA_HOME is not defined."
    add_vote_table -1 pre-patch "JAVA_HOME is not defined."
    return 1
  fi

  javaversion=$(report_jvm_version "${JAVA_HOME}")
  add_footer_table "Default Java" "${javaversion}"

  if [[ -n ${JDK_DIR_LIST}
     && ${JDK_DIR_LIST} != "${JAVA_HOME}" ]]; then
    for i in ${JDK_DIR_LIST}; do
      javaversion=$(report_jvm_version "${i}")
      listofjdks="${listofjdks} ${i}:${javaversion}"
    done
    add_footer_table "Multi-JDK versions" "${listofjdks}"
  fi
  return 0
}

function javac_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ \.java$ ]]; then
   yetus_debug "tests/javac: ${filename}"
   add_test javac
   add_test compile
  fi
}

function javadoc_filefilter
{
  local filename=$1

  if [[ ${filename} =~ \.java$ ]]; then
   yetus_debug "tests/javadoc: ${filename}"
   add_test javadoc
  fi
}

## @description
## @audience     private
## @stability    stable
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function javac_compile
{
  declare codebase=$1
  declare multijdkmode=$2

  if ! verify_needed_test javac; then
    return 0
  fi

  if [[ ${codebase} = patch ]]; then
    yetus_debug "javac: calling generic_postlog_compare compile javac ${multijdkmode}"
    generic_postlog_compare compile javac "${multijdkmode}"
  fi
}

## @description  Count and compare the number of JavaDoc warnings pre- and post- patch
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function javadoc_rebuild
{
  declare codebase=$1
  declare multijdkmode

  if verify_multijdk_test javadoc; then
    multijdkmode=true
  else
    multijdkmode=false
  fi

  if [[ "${codebase}" = branch ]]; then
    generic_pre_handler javadoc "${multijdkmode}"
  else
    generic_post_handler javadoc javadoc "${multijdkmode}" true
  fi
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function javac_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC2016,SC2046
  ${GREP} "^.*.java:[0-9]*:" "${input}" > "${output}"
}

## @description  Helper for generic_logfilter
## @audience     private
## @stability    evolving
## @replaceable  no
function javadoc_logfilter
{
  declare input=$1
  declare output=$2

  #shellcheck disable=SC2016,SC2046
  ${GREP} "^.*.java:[0-9]*:" "${input}" > "${output}"
}
