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

declare -a MAVEN_ARGS=("--batch-mode")

if [[ -z "${MAVEN_HOME:-}" ]]; then
  MAVEN=mvn
else
  MAVEN=${MAVEN_HOME}/bin/mvn
fi

MAVEN_CUSTOM_REPOS=false
MAVEN_CUSTOM_REPOS_DIR="${HOME}/yetus-m2"

add_test_type mvnsite
add_test_type mvneclipse
add_build_tool maven

function maven_usage
{
  echo "maven specific:"
  echo "--mvn-cmd=<cmd>            The 'mvn' command to use (default \${MAVEN_HOME}/bin/mvn, or 'mvn')"
  echo "--mvn-custom-repos         Use per-project maven repos"
  echo "--mvn-custom-repos-dir=dir Location of repos, default is \'${MAVEN_CUSTOM_REPOS_DIR}\'"
  echo "--mvn-settings=file        File to use for settings.xml"
}

function maven_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
      --mvn-cmd=*)
        MAVEN=${i#*=}
      ;;
      --mvn-custom-repos)
        MAVEN_CUSTOM_REPOS=true
      ;;
      --mvn-custom-repos-dir=*)
        MAVEN_CUSTOM_REPOS_DIR=${i#*=}
      ;;
      --mvn-settings=*)
        MAVEN_SETTINGS=${i#*=}
        if [[ -f ${MAVEN_SETTINGS} ]]; then
          MAVEN_ARGS=("${MAVEN_ARGS[@]}" "--settings=${MAVEN_SETTINGS}")
        else
          yetus_error "WARNING: ${MAVEN_SETTINGS} not found. Ignorning."
        fi
      ;;
    esac
  done

  if [[ ${OFFLINE} == "true" ]]; then
    MAVEN_ARGS=("${MAVEN_ARGS[@]}" --offline)
  fi
}

function maven_initialize
{
  # we need to do this before docker does it as root

  if [[ ! ${MAVEN_CUSTOM_REPOS_DIR} =~ ^/ ]]; then
    yetus_error "ERROR: --mvn-custom-repos-dir must be an absolute path."
    return 1
  fi

  if [[ ${MAVEN_CUSTOM_REPOS} = true ]]; then
    MAVEN_LOCAL_REPO="${MAVEN_CUSTOM_REPOS_DIR}"
    if [[ -e "${MAVEN_CUSTOM_REPOS_DIR}"
       && ! -d "${MAVEN_CUSTOM_REPOS_DIR}" ]]; then
      yetus_error "ERROR: ${MAVEN_CUSTOM_REPOS_DIR} is not a directory."
      return 1
    elif [[ ! -d "${MAVEN_CUSTOM_REPOS_DIR}" ]]; then
      yetus_debug "Creating ${MAVEN_CUSTOM_REPOS_DIR}"
      mkdir -p "${MAVEN_CUSTOM_REPOS_DIR}"
    fi
  fi

  if [[ -e "${HOME}/.m2"
     && ! -d "${HOME}/.m2" ]]; then
    yetus_error "ERROR: ${HOME}/.m2 is not a directory."
    return 1
  elif [[ ! -e "${HOME}/.m2" ]]; then
    yetus_debug "Creating ${HOME}/.m2"
    mkdir -p "${HOME}/.m2"
  fi
}

function maven_precheck
{
  declare logfile="${PATCH_DIR}/mvnrepoclean.log"
  declare line

  if [[ ! ${MAVEN_CUSTOM_REPOS_DIR} =~ ^/ ]]; then
    yetus_error "ERROR: --mvn-custom-repos-dir must be an absolute path."
    return 1
  fi

  if [[ ${MAVEN_CUSTOM_REPOS} = true ]]; then
    MAVEN_LOCAL_REPO="${MAVEN_CUSTOM_REPOS_DIR}/${PROJECT_NAME}-${PATCH_BRANCH}-${INSTANCE}"
    if [[ -e "${MAVEN_LOCAL_REPO}"
       && ! -d "${MAVEN_LOCAL_REPO}" ]]; then
      yetus_error "ERROR: ${MAVEN_LOCAL_REPO} is not a directory."
      return 1
    fi

    if [[ ! -d "${MAVEN_LOCAL_REPO}" ]]; then
      yetus_debug "Creating ${MAVEN_LOCAL_REPO}"
      mkdir -p "${MAVEN_LOCAL_REPO}"
      if [[ $? -ne 0 ]]; then
        yetus_error "ERROR: Unable to create ${MAVEN_LOCAL_REPO}"
        return 1
      fi
    fi
    touch "${MAVEN_LOCAL_REPO}"

    # if we have a local settings.xml file, we copy it.
    if [[ -f "${HOME}/.m2/settings.xml" ]]; then
      cp -p "${HOME}/.m2/settings.xml" "${MAVEN_LOCAL_REPO}"
    fi
    MAVEN_ARGS=("${MAVEN_ARGS[@]}" "-Dmaven.repo.local=${MAVEN_LOCAL_REPO}")

    # let's do some cleanup while we're here

    find "${MAVEN_CUSTOM_REPOS_DIR}" \
      -name '*-*-*' \
      -type d \
      -mtime +30 \
      -maxdepth 1 \
      -print \
        > "${logfile}"

    while read -r line; do
      echo "Removing old maven repo ${line}"
      rm -rf "${line}"
    done < "${logfile}"
  fi
}

function maven_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ pom\.xml$ ]]; then
    yetus_debug "tests/compile: ${filename}"
    add_test compile
  fi
}

function maven_buildfile
{
  echo "pom.xml"
}

function maven_executor
{
  echo "${MAVEN}" "${MAVEN_ARGS[@]}"
}

function mvnsite_filefilter
{
  local filename=$1

  if [[ ${BUILDTOOL} = maven ]]; then
    if [[ ${filename} =~ src/site ]]; then
      yetus_debug "tests/mvnsite: ${filename}"
      add_test mvnsite
    fi
  fi
}

function maven_modules_worker
{
  declare repostatus=$1
  declare tst=$2

  # shellcheck disable=SC2034
  UNSUPPORTED_TEST=false

  case ${tst} in
    findbugs)
      modules_workers "${repostatus}" findbugs test-compile findbugs:findbugs -DskipTests=true
    ;;
    compile)
      modules_workers "${repostatus}" compile clean test-compile -DskipTests=true
    ;;
    distclean)
      modules_workers "${repostatus}" distclean clean -DskipTests=true
    ;;
    javadoc)
      modules_workers "${repostatus}" javadoc clean javadoc:javadoc -DskipTests=true
    ;;
    scaladoc)
      modules_workers "${repostatus}" scaladoc clean scala:doc -DskipTests=true
    ;;
    unit)
      modules_workers "${repostatus}" unit clean test -fae
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

function maven_javac_count_probs
{
  local warningfile=$1

  #shellcheck disable=SC2016,SC2046
  ${GREP} '\[WARNING\]' "${warningfile}" | ${AWK} '{sum+=1} END {print sum}'
}

function maven_scalac_count_probs
{
  echo 0
}

## @description  Helper for check_patch_javadoc
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function maven_javadoc_count_probs
{
  local warningfile=$1

  #shellcheck disable=SC2016,SC2046
  ${GREP} -E "^[0-9]+ warnings?$" "${warningfile}" | ${AWK} '{sum+=$1} END {print sum}'
}

function maven_builtin_personality_modules
{
  local repostatus=$1
  local testtype=$2

  local module

  yetus_debug "Using builtin personality_modules"
  yetus_debug "Personality: ${repostatus} ${testtype}"

  clear_personality_queue

  # this always makes sure the local repo has a fresh
  # copy of everything per pom rules.
  if [[ ${repostatus} == branch
     && ${testtype} == mvninstall ]];then
     personality_enqueue_module .
     return
   fi

  for module in ${CHANGED_MODULES}; do
    # shellcheck disable=SC2086
    personality_enqueue_module ${module}
  done
}

function maven_builtin_personality_file_tests
{
  local filename=$1

  yetus_debug "Using builtin mvn personality_file_tests"

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
  elif [[ ${filename} =~ \.scala$
       || ${filename} =~ src/scala ]]; then
    add_test scalac
    add_test scaladoc
    add_test unit
  elif [[ ${filename} =~ build.xml$
       || ${filename} =~ pom.xml$
       || ${filename} =~ \.java$
       || ${filename} =~ src/main
       ]]; then
      yetus_debug "tests/javadoc+units: ${filename}"
      add_test javac
      add_test javadoc
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

## @description  Confirm site pre-patch
## @audience     private
## @stability    stable
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function mvnsite_postcompile
{
  declare repostatus=$1
  declare result=0

  if [[ ${BUILDTOOL} != maven ]]; then
    return 0
  fi

  verify_needed_test mvnsite
  if [[ $? == 0 ]];then
    return 0
  fi

  if [[ "${repostatus}" = branch ]]; then
    big_console_header "Pre-patch ${PATCH_BRANCH} maven site verification"
  else
    big_console_header "Patch maven site verification"
  fi


  personality_modules "${repostatus}" mvnsite
  modules_workers "${repostatus}" mvnsite clean site site:stage
  result=$?
  modules_messages "${repostatus}" mvnsite true
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Make sure Maven's eclipse generation works.
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function mvneclipse_postcompile
{
  declare repostatus=$1
  declare result=0

  if [[ ${BUILDTOOL} != maven ]]; then
    return 0
  fi

  verify_needed_test javac
  if [[ $? == 0 ]]; then
    return 0
  fi

  if [[ "${repostatus}" = branch ]]; then
    big_console_header "Pre-patch ${PATCH_BRANCH} maven eclipse verification"
  else
    big_console_header "Patch maven eclipse verification"
  fi

  personality_modules "${repostatus}" mvneclipse
  modules_workers "${repostatus}" mvneclipse eclipse:clean eclipse:eclipse
  result=$?
  modules_messages "${repostatus}" mvneclipse true
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Verify mvn install works
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function maven_precompile
{
  declare repostatus=$1
  declare result=0

  if [[ ${BUILDTOOL} != maven ]]; then
    return 0
  fi

  verify_needed_test javadoc
  result=$?

  verify_needed_test javac
  ((result = result + $? ))
  if [[ ${result} == 0 ]]; then
    return 0
  fi

  if [[ "${repostatus}" = branch ]]; then
    big_console_header "Pre-patch ${PATCH_BRANCH} maven install"
  else
    big_console_header "Patch maven install"
  fi

  personality_modules "${repostatus}" mvninstall
  modules_workers "${repostatus}" mvninstall -fae clean install -DskipTests=true -Dmaven.javadoc.skip=true
  result=$?
  modules_messages "${repostatus}" mvninstall true
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

function maven_docker_support
{
  echo "-v ${HOME}/.m2:${HOME}/.m2" > "${PATCH_DIR}/buildtool-docker-params.txt"

  if [[ ${MAVEN_CUSTOM_REPOS} = true ]]; then
    echo "-v ${MAVEN_CUSTOM_REPOS_DIR}:${MAVEN_CUSTOM_REPOS_DIR}" \
      >> "${PATCH_DIR}/buildtool-docker-params.txt"
  fi
}
