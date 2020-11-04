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

declare -a MAVEN_ARGS

if [[ -z "${MAVEN_HOME:-}" ]]; then
  MAVEN=mvn
else
  MAVEN=${MAVEN_HOME}/bin/mvn
fi

MAVEN_CUSTOM_REPOS=false
MAVEN_CUSTOM_REPOS_DIR="@@@WORKSPACE@@@/yetus-m2"
MAVEN_DEPENDENCY_ORDER=true
MAVEN_FOUND_ROOT_POM=false
MAVEN_JAVADOC_GOALS=("javadoc:javadoc")
MAVEN_ONLY_CHANGED_TESTS=false

add_test_type mvnsite
add_build_tool maven

## @description  Add the given test type as requiring a mvn install during the branch phase
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test
function maven_add_install
{
    yetus_add_array_element MAVEN_NEED_INSTALL "${1}"
}

## @description  Remove the given test type as requiring a mvn install
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test
function maven_delete_install
{
  yetus_del_array_element MAVEN_NEED_INSTALL "${1}"
}

## @description  replace the custom repo with either home or workspace if jenkins.
## @description  is configured. this gets called in a few places since different
## @description  circumstances dictate a few places where it may be needed.
## @audience     private
## @stability    evolving
function maven_ws_replace
{
  declare previous=${MAVEN_CUSTOM_REPOS_DIR}

  if [[ ${ROBOTTYPE} == jenkins ]] && [[ -n "${WORKSPACE}" ]]; then
    MAVEN_CUSTOM_REPOS_DIR=$(echo "${MAVEN_CUSTOM_REPOS_DIR}" | "${SED}" -e "s,@@@WORKSPACE@@@,${WORKSPACE},g" )
  else
    MAVEN_CUSTOM_REPOS_DIR=$(echo "${MAVEN_CUSTOM_REPOS_DIR}" | "${SED}" -e "s,@@@WORKSPACE@@@,${HOME},g" )
  fi
  if [[ "${previous}" != "${MAVEN_CUSTOM_REPOS_DIR}" ]]; then
    # put this in the array so that if docker is run, this is already resolved
    USER_PARAMS=("${USER_PARAMS[@]}" "--mvn-custom-repos-dir=${MAVEN_CUSTOM_REPOS_DIR}")
  fi
}

## @description  maven usage message
## @audience     private
## @stability    evolving
function maven_usage
{
  maven_ws_replace
  yetus_add_option "--mvn-cmd=<file>" "The 'mvn' command to use (default \${MAVEN_HOME}/bin/mvn, or 'mvn')"
  yetus_add_option "--mvn-custom-repos" "Use per-project maven repos"
  yetus_add_option "--mvn-custom-repos-dir=<dir>" "Location of repos, default is '${MAVEN_CUSTOM_REPOS_DIR}'"
  yetus_add_option "--mvn-deps-order=<bool>" "Disable maven's auto-dependency module ordering (Default: '${MAVEN_DEPENDENCY_ORDER}')"
  yetus_add_option "--mvn-javadoc-goals=<list>" "The comma-separated javadoc goals (Default: 'javadoc:javadoc')"
  yetus_add_option "--mvn-only-changed-tests=<bool>" "If only Java test files are changed, just test them (Default: '${MAVEN_ONLY_CHANGED_TESTS}')"
  yetus_add_option "--mvn-settings=file" "File to use for settings.xml"
}

## @description  parse maven build tool args
## @replaceable  yes
## @audience     public
## @stability    stable
function maven_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
      --mvn-cmd=*)
        delete_parameter "${i}"
        MAVEN=${i#*=}
      ;;
      --mvn-custom-repos)
        delete_parameter "${i}"
        MAVEN_CUSTOM_REPOS=true
      ;;
      --mvn-custom-repos-dir=*)
        delete_parameter "${i}"
        MAVEN_CUSTOM_REPOS_DIR=${i#*=}
      ;;
      --mvn-deps-order=*)
        delete_parameter "${i}"
        MAVEN_DEPENDENCY_ORDER=${i#*=}
      ;;
      --mvn-javadoc-goals=*)
        delete_parameter "${i}"
        yetus_comma_to_array MAVEN_JAVADOC_GOALS "${i#*=}"
      ;;
      ----mvn-only-changed-tests=*)
        delete_parameter "${i}"
        MAVEN_ONLY_CHANGED_TESTS=${i#*=}
      ;;
      --mvn-settings=*)
        delete_parameter "${i}"
        MAVEN_SETTINGS=${i#*=}
        if [[ -f ${MAVEN_SETTINGS} ]]; then
          MAVEN_ARGS=("${MAVEN_ARGS[@]}" "--settings=${MAVEN_SETTINGS}")
        else
          yetus_error "WARNING: ${MAVEN_SETTINGS} not found. Ignoring."
        fi
      ;;
    esac
  done

  if [[ ${OFFLINE} == "true" ]]; then
    MAVEN_ARGS=("${MAVEN_ARGS[@]}" --offline)
  fi

  maven_ws_replace
}

## @description  initialize the maven build tool
## @replaceable  yes
## @audience     public
## @stability    stable
function maven_initialize
{
  # we need to do this before docker does it as root

  maven_add_install compile
  maven_add_install mvnsite
  maven_add_install unit

  # Tell the reaper about the maven surefire plugin
  reaper_add_name surefirebooter

  # we need to do this before docker does it as root
  maven_ws_replace

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
      if ! mkdir -p "${MAVEN_CUSTOM_REPOS_DIR}"; then
        yetus_error "ERROR: Cannot create ${MAVEN_CUSTOM_REPOS_DIR}"
        return 1
      fi
    fi
  fi

  if [[ -e "${HOME}/.m2"
     && ! -d "${HOME}/.m2" ]]; then
    yetus_error "ERROR: ${HOME}/.m2 is not a directory."
    return 1
  elif [[ ! -e "${HOME}/.m2" ]]; then
    yetus_debug "Creating ${HOME}/.m2"
    if ! mkdir -p "${HOME}/.m2"; then
      yetus_error "ERROR: ${HOME}/.m2 cannot be created. " \
        "See --mvn-custom-repos and --mvn-custom-repos-dir to set a different location."
        return 1
    fi
  fi
}

## @audience     private
## @stability    stable
function mvnsite_precheck
{
  if ! verify_plugin_enabled 'maven'; then
    yetus_error "ERROR: to run the mvnsite test you must ensure the 'maven' plugin is enabled."
    return 1
  fi
}

## @audience     private
## @stability    stable
function maven_precheck
{
  declare logfile="${PATCH_DIR}/mvnrepoclean.log"
  declare line
  declare maven_version

  if ! verify_plugin_enabled 'maven'; then
    yetus_error "ERROR: you can't specify maven as the buildtool if you don't enable the plugin."
    return 1
  fi

  if ! verify_command maven "${MAVEN}"; then
    add_vote_table_v2 -1 maven "" "ERROR: maven was not available."
    return 1
  fi

  if [[ ! ${MAVEN_CUSTOM_REPOS_DIR} =~ ^/ ]]; then
    yetus_error "ERROR: --mvn-custom-repos-dir must be an absolute path."
    return 1
  fi

  MAVEN_ARGS=("${MAVEN_ARGS[@]}" "--batch-mode")

  if [[ ${MAVEN_CUSTOM_REPOS} = true ]]; then
    MAVEN_LOCAL_REPO="${MAVEN_CUSTOM_REPOS_DIR}/${PROJECT_NAME}-${PATCH_BRANCH}-${BUILDMODE}-${INSTANCE}"
    if [[ -e "${MAVEN_LOCAL_REPO}"
       && ! -d "${MAVEN_LOCAL_REPO}" ]]; then
      yetus_error "ERROR: ${MAVEN_LOCAL_REPO} is not a directory."
      return 1
    fi

    if [[ ! -d "${MAVEN_LOCAL_REPO}" ]]; then
      yetus_debug "Creating ${MAVEN_LOCAL_REPO}"
      if ! mkdir -p "${MAVEN_LOCAL_REPO}"; then
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
      -maxdepth 1 \
      -name '*-*-*' \
      -type d \
      -mtime +30 \
      -print \
        > "${logfile}"

    while read -r line; do
      echo "Removing old maven repo ${line}"
      rm -rf "${line}"
    done < "${logfile}"
  fi

  # finally let folks know what version they'll be dealing with.
  # In Maven 3.5.x and 3.6.x, mvn --version contains control characters
  # even in batch mode. Passing strings command to remove these.
  maven_version=$("${MAVEN}" "${MAVEN_ARGS[@]}" --offline --version 2>/dev/null \
    | head -n 1 2>/dev/null \
    | strings \
    | cut -d' ' -f3)
  add_version_data maven "${maven_version}"
}

## @description  maven trigger
## @audience     private
## @stability    evolving
function maven_filefilter
{
  declare filename=$1

  if [[ ${filename} =~ pom\.xml$ ]]; then
    yetus_debug "tests/compile: ${filename}"
    add_test compile
    if [[ "${filename}" =~ ^pom\.xml$ ]]; then
      MAVEN_FOUND_ROOT_POM=true
    fi
  fi
}

## @description  maven build file
## @audience     private
## @stability    evolving
function maven_buildfile
{
  echo "pom.xml"
}

## @description  execute maven
## @audience     private
## @stability    evolving
function maven_executor
{
  echo "${MAVEN}" "${MAVEN_ARGS[@]}"
}

## @description  mvn site trigger
## @audience     private
## @stability    evolving
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

## @description  maven version of the modules_worker routine
## @audience     public
## @stability    stable
function maven_modules_worker
{
  declare repostatus=$1
  declare tst=$2
  declare maven_unit_test_filter

  maven_unit_test_filter="$(maven_unit_test_filter)"
  # shellcheck disable=SC2034
  UNSUPPORTED_TEST=false

  case ${tst} in
    compile)
      modules_workers "${repostatus}" compile clean test-compile -DskipTests=true
    ;;
    distclean)
      modules_workers "${repostatus}" distclean clean -DskipTests=true
    ;;
    javadoc)
      modules_workers "${repostatus}" javadoc clean "${MAVEN_JAVADOC_GOALS[@]}" -DskipTests=true
    ;;
    scaladoc)
      modules_workers "${repostatus}" scaladoc clean scala:doc -DskipTests=true
    ;;
    spotbugs)
      modules_workers "${repostatus}" spotbugs test-compile spotbugs:spotbugs -DskipTests=true
    ;;
    unit)
      if [[ -n "${maven_unit_test_filter}" ]]; then
        modules_workers "${repostatus}" unit clean test -fae "${maven_unit_test_filter}"
      else
        modules_workers "${repostatus}" unit clean test -fae
      fi
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

## @description  process javac output from maven
## @audience     private
## @stability    evolving
function maven_javac_logfilter
{
  declare input=$1
  declare output=$2

  # [WARNING] fullpath:[linenum,column] message

  "${GREP}" -E '\[(ERROR|WARNING)\] /.*\.java:' "${input}" \
    | "${SED}" -E -e 's,\[(ERROR|WARNING)\] ,,' \
                  -e "s,^${BASEDIR}/,," \
                  -e "s#:\[([[:digit:]]+),([[:digit:]]+)\] #:\1:\2:#" \
                  -e "s#:\[([[:digit:]]+)\] #:\1:0:#" \
    > "${output}"

    # shortpath:linenum:column:message
}

## @description  Helper for check_patch_javadoc
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function maven_javadoc_logfilter
{
  declare input=$1
  declare output=$2

  # [WARNING] fullpath:linenum:message

  "${GREP}" -E '\[(ERROR|WARNING)\] /.*\.java:' "${input}" \
    | "${SED}" -E -e 's,\[(ERROR|WARNING)\] ,,g' \
                  -e "s,^${BASEDIR}/,," \
    > "${output}"

  # shortpath:linenum:message

}

## @description  handle diffing maven javac errors
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function maven_javac_calcdiffs
{
  column_calcdiffs "${@}"
}

## @description  handle diffing maven javadoc errors
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function maven_javadoc_calcdiffs
{
  error_calcdiffs "${@}"
}

## @description  maven personality handler
## @audience     private
## @stability    evolving
## @replaceable  yes
function maven_builtin_personality_modules
{
  declare repostatus=$1
  declare testtype=$2
  declare module

  yetus_debug "Using builtin personality_modules"
  yetus_debug "Personality: ${repostatus} ${testtype}"

  clear_personality_queue

  # this always makes sure the local repo has a fresh
  # copy of everything per pom rules.
  if [[ ${repostatus} == branch
        && ${testtype} == mvninstall ]] ||
     [[ "${BUILDMODE}" = full ]];then
    personality_enqueue_module .
    return
  fi

  for module in "${CHANGED_MODULES[@]}"; do
    personality_enqueue_module "${module}"
  done
}

## @description  maven default test triggers
## @audience     private
## @stability    evolving
## @replaceable  yes
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
    add_test spotbugs
  fi
}

## @description  Maven unit test filter file string
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       string
function maven_unit_test_filter()
{
  declare filtered
  declare line
  declare file
  declare dir
  declare pkg
  declare class
  declare sclass
  declare -a testonly

  if [[ -n "${UNIT_TEST_FILTER_FILE}" ]]; then
    while read -r line || [[ -n "${line}" ]]; do
      if [[ -z $line ]]; then
        continue
      fi

      filtered="${filtered}${line},"
    done < "${UNIT_TEST_FILTER_FILE}"
  elif [[ "${BUILDMODE}" != 'full' ]] &&
       [[ "${MAVEN_ONLY_CHANGED_TESTS}" == true ]]; then
    for file in "${CHANGED_FILES[@]}"; do
      if [[ "${file}" =~ src/test/java ]]; then
        dir=$(dirname "${file}")
        pkg=$(echo "${dir}" | "${SED}" -e 's,.*/src/test/java/,,g' -e 's,/,.,g' )
        sclass=$(basename "${file}")
        sclass=${sclass%.java}
        class="${pkg}.${sclass}"
        if [[ -f "${file}" ]]; then
          if "${GREP}" -q "package ${pkg}" "${file}"; then
            if "${GREP}" -q "class ${sclass}" "${file}"; then
              testonly+=("${class}")
              filtered="${filtered}${class},"
            fi
          fi
        fi
      fi
    done

    if [[ ${#testonly[@]} -ne ${#CHANGED_FILES[@]} ]]; then
      unset filtered
    fi
  fi

  if [[ -z "${filtered}" ]]; then
    printf "%s" ""
  else
    printf "%s" "-Dtest=${filtered%,}"
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

  if ! verify_needed_test mvnsite; then
    return 0
  fi

  if [[ "${repostatus}" = branch ]]; then
    big_console_header "maven site verification: ${PATCH_BRANCH}"
  else
    big_console_header "maven site verification: ${BUILDMODE}"
  fi

  personality_modules_wrapper "${repostatus}" mvnsite
  modules_workers "${repostatus}" mvnsite clean site site:stage
  result=$?
  modules_messages "${repostatus}" mvnsite true
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

## @description  maven precompile phase
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function maven_precompile
{
  declare repostatus=$1
  declare result=0
  declare need=${2:-false}

  if [[ ${BUILDTOOL} != maven ]]; then
    return 0
  fi

  # not everything needs a maven install
  # but quite a few do ...
  # shellcheck disable=SC2086
  for index in "${MAVEN_NEED_INSTALL[@]}"; do
    if verify_needed_test "${index}"; then
      need=true
    fi
  done

  if [[ "${need}" == false ]]; then
    return 0
  fi

  if [[ "${repostatus}" == branch ]]; then
    big_console_header "maven install: ${PATCH_BRANCH}"
  else
    big_console_header "maven install: ${BUILDMODE}"
  fi

  personality_modules_wrapper "${repostatus}" mvninstall
  modules_workers "${repostatus}" mvninstall -fae \
    clean install \
    -DskipTests=true -Dmaven.javadoc.skip=true \
    -Dcheckstyle.skip=true -Dfindbugs.skip=true \
    -Dspotbugs.skip=true
  result=$?
  modules_messages "${repostatus}" mvninstall true
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

## @description  set volumes and options as appropriate for maven
## @audience     private
## @stability    evolving
## @replaceable  yes
function maven_docker_support
{
  DOCKER_EXTRAARGS+=("-v" "${HOME}/.m2:/home/${USER_NAME}/.m2")

  if [[ ${MAVEN_CUSTOM_REPOS} = true ]]; then
    DOCKER_EXTRAARGS+=("-v" "${MAVEN_CUSTOM_REPOS_DIR}:${MAVEN_CUSTOM_REPOS_DIR}")
  fi

  add_docker_env MAVEN_OPTS
}

## @description  worker for maven reordering. MAVEN_DEP_LOG is set to the log file name
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        repostatus
## @return       0 = success
## @return       1 = failure
function maven_reorder_module_process
{
  declare repostatus=$1
  declare module
  declare line
  declare indexm
  declare indexn
  declare -a newlist
  declare fn
  declare needroot=false
  declare found
  declare ret

  for module in "${CHANGED_MODULES[@]}"; do
    if [[ "${module}" = \. ]]; then
      needroot=true
    fi
  done

  pushd "${BASEDIR}" >/dev/null || return 1
  if [[ "${BUILDMODE}" == patch ]] && [[ "${MAVEN_FOUND_ROOT_POM}" == true ]]; then

    echo ""
    echo "Testing root pom.xml file for version change"
    echo ""

    # shellcheck disable=SC2046
    echo_and_redirect \
      "${PATCH_DIR}/maven-${repostatus}-version-log.txt" \
      $("${BUILDTOOL}_executor") \
        "-fae" \
        "org.apache.maven.plugins:maven-help-plugin:evaluate" \
        '-Dexpression=project.version' \
        "-Doutput=${PATCH_DIR}/maven-${repostatus}-version.txt"

    projectversion=$(cat "${PATCH_DIR}/maven-${repostatus}-version.txt")

    if [[ -z "${MAVEN_DETECTED_PROJECT_VERSION}" ]]; then
      MAVEN_DETECTED_PROJECT_VERSION=${projectversion}
    elif [[ "${MAVEN_DETECTED_PROJECT_VERSION}" != "${projectversion}" ]]; then
      echo "Patch changes root pom.xml project.version: forcing an extra mvn install on the patched branch"
      maven_precompile branch true
    fi
  fi

  # get the module directory list in the correct order based on maven dependencies
  # shellcheck disable=SC2046
  echo_and_redirect "${PATCH_DIR}/maven-${repostatus}-dirlist-${fn}.txt" \
    $("${BUILDTOOL}_executor") "-fae" "-q" "exec:exec" "-Dexec.executable=pwd" "-Dexec.args=''"
  MAVEN_DEP_LOG="maven-${repostatus}-dirlist-${fn}.txt"
  ret=$?

  while read -r line; do
    for indexm in "${CHANGED_MODULES[@]}"; do
      if [[ ${line} == "${BASEDIR}/${indexm}" ]]; then
        yetus_debug "mrm: placing ${indexm} from dir: ${line}"
        newlist=("${newlist[@]}" "${indexm}")
        break
      fi
    done
  done < "${PATCH_DIR}/maven-${repostatus}-dirlist-${fn}.txt"
  popd >/dev/null || return 1

  if [[ "${needroot}" = true ]]; then
    newlist=("${newlist[@]}" ".")
  fi

  indexm="${#CHANGED_MODULES[@]}"
  indexn="${#newlist[@]}"

  if [[ ${indexm} -ne ${indexn} ]]; then
    yetus_debug "mrm: Missed a module"
    for indexm in "${CHANGED_MODULES[@]}"; do
      found=false
      for indexn in "${newlist[@]}"; do
        if [[ "${indexn}" = "${indexm}" ]]; then
          found=true
          break
        fi
      done
      if [[ ${found} = false ]]; then
        yetus_debug "mrm: missed ${indexm}"
        newlist=("${newlist[@]}" "${indexm}")
      fi
    done
  fi

  CHANGED_MODULES=("${newlist[@]}")
  return "${ret}"
}

## @description  take a stab at reordering modules based upon
## @description  maven dependency order
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        repostatus
## @param        module
function maven_reorder_modules
{
  declare repostatus=$1
  declare index
  declare ret

  if [[ "${MAVEN_DEPENDENCY_ORDER}" != "true" ]]; then
    return
  fi

  # don't bother if there is only one
  index="${#CHANGED_MODULES[@]}"
  if [[ ${index} -eq 1 ]]; then
    return
  fi

  big_console_header "Determining Maven Dependency Order (downloading dependencies in the process)"

  start_clock

  maven_reorder_module_process "${repostatus}"
  ret=$?

  yetus_debug "Maven: finish re-ordering modules"
  yetus_debug "Finished list: ${CHANGED_MODULES[*]}"

  # build some utility module lists for maven modules
  for index in "${CHANGED_MODULES[@]}"; do
    if [[ -d "${index}/src" ]]; then
      MAVEN_SRC_MODULES=("${MAVEN_SRC_MODULES[@]}" "${index}")
      if [[ -d "${index}/src/test" ]]; then
        MAVEN_SRCTEST_MODULES=("${MAVEN_SRCTEST_MODULES[@]}" "${index}")
      fi
    fi
  done

  if [[ "${BUILDMODE}" = patch ]]; then
    if [[ ${ret} == 0 ]]; then
      add_vote_table_v2 0 mvndep "" "Maven dependency ordering for ${repostatus}"
    else
      add_vote_table_v2 -1 mvndep "@@BASE@@/${MAVEN_DEP_LOG}" "Maven dependency ordering for ${repostatus}"
    fi
  else
    if [[ ${ret} == 0 ]]; then
      add_vote_table_v2 0 mvndep "" "Maven dependency ordering"
    else
      add_vote_table_v2 -1 mvndep "@@BASE@@/${MAVEN_DEP_LOG}" "Maven dependency ordering"
    fi
  fi

  # shellcheck disable=SC2046
  echo "Elapsed: $(clock_display $(stop_clock))"
}
