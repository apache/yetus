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

SPOTBUGS_HOME=${SPOTBUGS_HOME:-}
ANT_SPOTBUGSXML=${ANT_SPOTBUGSXML:-}
SPOTBUGS_WARNINGS_FAIL_PRECHECK=false

add_test_type spotbugs

function spotbugs_usage
{
  yetus_add_option "--spotbugs-home=<dir>" "SpotBugs home directory (default \${SPOTBUGS_HOME})"
  yetus_add_option "--spotbugs-strict-precheck" "If there are SpotBugs warnings during precheck, fail"
}

function spotbugs_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
    --spotbugs-home=*)
      delete_parameter "${i}"
      SPOTBUGS_HOME=${i#*=}
    ;;
    --spotbugs-strict-precheck)
      delete_parameter "${i}"
      SPOTBUGS_WARNINGS_FAIL_PRECHECK=true
    ;;
    esac
  done
}

## @description  initialize the spotbugs plug-in
## @audience     private
## @stability    evolving
## @replaceable  no
function spotbugs_initialize
{
  if declare -f maven_add_install >/dev/null 2>&1; then
    maven_add_install "spotbugs"
  fi
}

function spotbugs_filefilter
{
  declare filename=$1

  if [[ ${BUILDTOOL} == maven
    || ${BUILDTOOL} == ant ]]; then
    if [[ ${filename} =~ \.java$
      || ${filename} =~ (^|/)spotbugs-exclude.xml$ ]]; then
      add_test "spotbugs"
    fi
  fi
}

function spotbugs_precheck
{
  declare exec
  declare status=0

  if [[ -z ${SPOTBUGS_HOME} ]]; then
    yetus_error "SPOTBUGS_HOME was not specified."
    status=1
  else
    for exec in computeBugHistory \
                convertXmlToText \
                filterBugs \
                setBugDatabaseInfo\
                unionBugs; do
      if ! verify_command "${exec}" "${SPOTBUGS_HOME}/bin/${exec}"; then
        status=1
      fi
    done
  fi
  if [[ ${status} == 1 ]]; then
    add_vote_table_v2 0 "spotbugs" "" "spotbugs executables are not available."
    delete_test "spotbugs"
  fi
}

## @description  Run the maven spotbugs plugin and record found issues in a bug database
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
## @param        repostatus
function spotbugs_runner
{
  declare name=$1
  declare module
  declare result=0
  declare fn
  declare warnings_file
  declare i=0
  declare savestop
  declare retval


  personality_modules_wrapper "${name}" "spotbugs"

  "${BUILDTOOL}_modules_worker" "${name}" "spotbugs"

  if [[ ${UNSUPPORTED_TEST} = true ]]; then
    return 0
  fi

  echo ""
  echo "Building spotbugs database(s) using ${SPOTBUGS_HOME} for executables."
  echo ""

  #shellcheck disable=SC2153
  until [[ ${i} -eq ${#MODULE[@]} ]]; do
    if [[ ${MODULE_STATUS[${i}]} == -1 ]]; then
      ((result=result+1))
      ((i=i+1))
      continue
    fi
    start_clock
    offset_clock "${MODULE_STATUS_TIMER[${i}]}"
    module="${MODULE[${i}]}"
    fn=$(module_file_fragment "${module}")

    if [[ "${module}" == . ]]; then
      module=root
    fi

    case ${BUILDTOOL} in
      maven)
        targetfile="spotbugsXml.xml"
      ;;
      ant)
        targetfile="${ANT_SPOTBUGSXML}"
      ;;
    esac

    buildtool_cwd "${i}"

    files=()
    while read -r line; do
      files+=("${line}")
    done < <(find . -name "${targetfile}")

    warnings_file="${PATCH_DIR}/${name}-spotbugs-${fn}-warnings"

    if [[ "${#files[@]}" -lt 1 ]]; then
      module_status "${i}" 0 "" "${name}/${module} no spotbugs output file (${targetfile})"
      ((i=i+1))
      popd >/dev/null || return 1
      continue
    elif [[ "${#files[@]}" -eq 1 ]]; then
      cp -p "${files[0]}" "${warnings_file}.xml"
    else
      "${SPOTBUGS_HOME}/bin/unionBugs" -withMessages -output "${warnings_file}.xml" "${files[@]}"
    fi

    popd >/dev/null || return 1

    if [[ ${name} == branch ]]; then
      "${SPOTBUGS_HOME}/bin/setBugDatabaseInfo" -name "${PATCH_BRANCH}" \
          "${warnings_file}.xml" "${warnings_file}.xml"
      retval=$?
    else
      "${SPOTBUGS_HOME}/bin/setBugDatabaseInfo" -name patch \
          "${warnings_file}.xml" "${warnings_file}.xml"
      retval=$?
    fi

    if [[ ${retval} != 0 ]]; then
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${i}]=${savestop}
      module_status "${i}" -1 "" "${name}/${module} cannot run setBugDatabaseInfo from spotbugs"
      ((result=result+1))
      ((i=i+1))
      continue
    fi

    if [[ ! -f "${warnings_file}.xml" ]]; then
      module_status "${i}" 0 "" "${name}/${module} no data in SpotBugs output file (${targetfile})"
      ((i=i+1))
      popd >/dev/null || return 1
      continue
    fi

    if ! "${SPOTBUGS_HOME}/bin/convertXmlToText" -html \
      "${warnings_file}.xml" \
      "${warnings_file}.html"; then
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${i}]=${savestop}
      module_status "${i}" -1 "" "${name}/${module} cannot run convertXmlToText from spotbugs"
      ((result=result+1))
    fi

    if [[ -z ${SPOTBUGS_VERSION}
        && ${name} == branch ]]; then
      SPOTBUGS_VERSION=$("${GREP}" -i "BugCollection version=" "${warnings_file}.xml" \
        | cut -f2 -d\" \
        | cut -f1 -d\" )
      if [[ -n ${SPOTBUGS_VERSION} ]]; then
        add_version_data "spotbugs" "${SPOTBUGS_VERSION}"
      fi
    fi

    ((i=i+1))
  done

  return "${result}"
}

## @description  Track pre-existing spotbugs warnings
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function spotbugs_preapply
{
  declare fn
  declare module
  declare modindex=0
  declare warnings_file
  declare module_spotbugs_warnings
  declare result=0
  declare msg

  if ! verify_needed_test "spotbugs"; then
    return 0
  fi

  big_console_header "spotbugs detection: ${PATCH_BRANCH}"

  spotbugs_runner branch
  result=$?

  if [[ ${UNSUPPORTED_TEST} = true ]]; then
    return 0
  fi

  until [[ ${modindex} -eq ${#MODULE[@]} ]]; do
    if [[ ${MODULE_STATUS[${modindex}]} == -1 ]]; then
      ((result=result+1))
      ((modindex=modindex+1))
      continue
    fi

    module=${MODULE[${modindex}]}
    start_clock
    offset_clock "${MODULE_STATUS_TIMER[${modindex}]}"
    fn=$(module_file_fragment "${module}")

    if [[ "${module}" == . ]]; then
      module=root
    fi

    warnings_file="${PATCH_DIR}/branch-spotbugs-${fn}-warnings"
    if [[ ! -f "${warnings_file}.xml" ]]; then
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${modindex}]=${savestop}
      ((modindex=modindex+1))
      continue
    fi

    # shellcheck disable=SC2016
    module_spotbugs_warnings=$("${SPOTBUGS_HOME}/bin/filterBugs" -first \
        "${PATCH_BRANCH}" \
        "${warnings_file}.xml" \
        "${warnings_file}.xml" \
        | "${AWK}" '{print $1}')

    if [[ ${module_spotbugs_warnings} -gt 0 ]] ; then
      msg="${module} in ${PATCH_BRANCH} has ${module_spotbugs_warnings} extant spotbugs warnings."
      if [[ "${SPOTBUGS_WARNINGS_FAIL_PRECHECK}" = "true" ]]; then
        module_status "${modindex}" -1 "branch-spotbugs-${fn}-warnings.html" "${msg}"
        ((result=result+1))
      elif [[ "${BUILDMODE}" = full ]]; then
        module_status "${modindex}" -1 "branch-spotbugs-${fn}-warnings.html" "${msg}"
        ((result=result+1))
        populate_test_table "spotbugs" "module:${module}"
        #shellcheck disable=SC2162
        while read line; do
          firstpart=$(echo "${line}" | cut -f2 -d:)
          secondpart=$(echo "${line}" | cut -f9- -d' ')
          add_test_table "" "${firstpart}:${secondpart}"
        done < <("${SPOTBUGS_HOME}/bin/convertXmlToText" "${warnings_file}.xml")
      else
        module_status "${modindex}" 0 "branch-spotbugs-${fn}-warnings.html" "${msg}"
      fi
    fi

    savestop=$(stop_clock)
    MODULE_STATUS_TIMER[${modindex}]=${savestop}
    ((modindex=modindex+1))
  done
  modules_messages branch "spotbugs" true

  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Verify patch does not trigger any spotbugs warnings
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function spotbugs_postinstall
{
  declare module
  declare fn
  declare combined_xml
  declare branchxml
  declare patchxml
  declare newbugsbase
  declare fixedbugsbase
  declare branch_warnings
  declare patch_warnings
  declare fixed_warnings
  declare line
  declare firstpart
  declare secondpart
  declare i=0
  declare result=0
  declare savestop
  declare summarize=true
  declare statstring

  if ! verify_needed_test "spotbugs"; then
    return 0
  fi

  big_console_header "spotbugs detection: ${BUILDMODE}"

  spotbugs_runner patch

  if [[ ${UNSUPPORTED_TEST} = true ]]; then
    return 0
  fi

  until [[ $i -eq ${#MODULE[@]} ]]; do
    if [[ ${MODULE_STATUS[${i}]} == -1 ]]; then
      ((result=result+1))
      ((i=i+1))
      continue
    fi

    start_clock
    offset_clock "${MODULE_STATUS_TIMER[${i}]}"
    module="${MODULE[${i}]}"

    buildtool_cwd "${i}"

    fn=$(module_file_fragment "${module}")

    if [[ "${module}" == . ]]; then
      module=root
    fi

    combined_xml="${PATCH_DIR}/combined-spotbugs-${fn}.xml"
    branchxml="${PATCH_DIR}/branch-spotbugs-${fn}-warnings.xml"
    patchxml="${PATCH_DIR}/patch-spotbugs-${fn}-warnings.xml"

    if [[ -f "${branchxml}" ]]; then
      # shellcheck disable=SC2016
      branch_warnings=$("${SPOTBUGS_HOME}/bin/filterBugs" -first \
          "${PATCH_BRANCH}" \
          "${branchxml}" \
          "${branchxml}" \
          | ${AWK} '{print $1}')
    else
      branchxml=${patchxml}
    fi

    newbugsbase="${PATCH_DIR}/new-spotbugs-${fn}"
    fixedbugsbase="${PATCH_DIR}/fixed-spotbugs-${fn}"

    if [[ ! -f "${branchxml}" ]] && [[ ! -f "${patchxml}" ]]; then
      module_status "${i}" 0 "" "${module} has no data from spotbugs"
      ((result=result+1))
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${i}]=${savestop}
      ((i=i+1))
      popd >/dev/null || return 1
      continue
    fi

    echo ""

    if ! "${SPOTBUGS_HOME}/bin/computeBugHistory" -useAnalysisTimes -withMessages \
            -output "${combined_xml}" \
            "${branchxml}" \
            "${patchxml}"; then
      module_status "${i}" -1 "" "${module} cannot run computeBugHistory from spotbugs"
      ((result=result+1))
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${i}]=${savestop}
      ((i=i+1))
      popd >/dev/null || return 1
      continue
    fi

    # shellcheck disable=SC2016
    patch_warnings=$("${SPOTBUGS_HOME}/bin/filterBugs" -first \
        "patch" \
        "${patchxml}" \
        "${patchxml}" \
        | ${AWK} '{print $1}')

    #shellcheck disable=SC2016
    add_warnings=$("${SPOTBUGS_HOME}/bin/filterBugs" -first patch \
        "${combined_xml}" "${newbugsbase}.xml" | ${AWK} '{print $1}')
    retval=$?
    if [[ ${retval} != 0 ]]; then
      module_status "${i}" -1 "" "${module} cannot run filterBugs (#1) from spotbugs"
      ((result=result+1))
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${i}]=${savestop}
      ((i=i+1))
      popd >/dev/null || return 1
      continue
    fi

    #shellcheck disable=SC2016
    fixed_warnings=$("${SPOTBUGS_HOME}/bin/filterBugs" -fixed patch \
        "${combined_xml}" "${fixedbugsbase}.xml" | ${AWK} '{print $1}')
    retval=$?
    if [[ ${retval} != 0 ]]; then
      module_status "${i}" -1 "" "${module} cannot run filterBugs (#2) from spotbugs"
      ((result=result+1))
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${i}]=${savestop}
      ((i=i+1))
      popd >/dev/null || return 1
      continue
    fi

    statstring=$(generic_calcdiff_status "${branch_warnings}" "${patch_warnings}" "${add_warnings}")

    if ! "${SPOTBUGS_HOME}/bin/convertXmlToText" -html "${newbugsbase}.xml" \
        "${newbugsbase}.html"; then
      module_status "${i}" -1 "" "${module} cannot run convertXmlToText from spotbugs"
      ((result=result+1))
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${i}]=${savestop}
      ((i=i+1))
      popd >/dev/null || return 1
      continue
    fi

    if [[ ${add_warnings} -gt 0 ]] ; then
      populate_test_table SpotBugs "module:${module}"
      #shellcheck disable=SC2162
      while read line; do
        firstpart=$(echo "${line}" | cut -f2 -d:)
        secondpart=$(echo "${line}" | cut -f9- -d' ')
        add_test_table "" "${firstpart}:${secondpart}"
      done < <("${SPOTBUGS_HOME}/bin/convertXmlToText" "${newbugsbase}.xml")

      module_status "${i}" -1 "new-spotbugs-${fn}.html" "${module} ${statstring}"
      ((result=result+1))
    elif [[ ${fixed_warnings} -gt 0 ]]; then
      module_status "${i}" +1 "" "${module} ${statstring}"
      summarize=false
    fi
    savestop=$(stop_clock)
    MODULE_STATUS_TIMER[${i}]=${savestop}
    popd >/dev/null || return 1
    ((i=i+1))
  done

  modules_messages patch spotbugs "${summarize}"
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

function spotbugs_rebuild
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch || "${BUILDMODE}" = full ]]; then
    spotbugs_preapply
  else
    spotbugs_postinstall
  fi
}
