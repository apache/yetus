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

DEPENDENCY_CHECK_ARGS=()
DEPENDENCY_CHECK_SUPPRESSION_FILES=()
DEPENDENCY_CHECK_EXCLUDES_PATTERNS=()
DEPENDENCY_CHECK_TIMER="0"
DEPENDENCY_CHECK_SEVERITIES=("High" "Medium" "Low")
DEPENDENCY_CHECK_SEVERITY="${DEPENDENCY_CHECK_SEVERITIES[0]}"
DEPENDENCY_CHECK_UPDATE=true
DEPENDENCY_CHECK_EXPERIMENTAL=false
DEPENDENCY_CHECK_MAVEN_GOAL=check

add_test_type dependency_check

## @audience     private
function dependency_check_usage
{
  yetus_add_option "--dependency-check=<path>" "path to the dependency-check executable"
  yetus_add_option "--dependency-check-severity-threshold=<value>" "ignore findings with a 'highest severity' lower than this. default: ${DEPENDENCY_CHECK_SEVERITY}"
  yetus_add_option "--dependency-check-suppression=<list>" "path(s) to suppression XML file(s). see https://s.apache.org/ahw7"
  yetus_add_option "--dependency-check-excludes=<list>" "list of ant style exclusions"
  yetus_add_option "--dependency-check-experimental" "enable experimental analyzers."
  yetus_add_option "--dependency-check-no-updates" "suppress updates of CVE information"
  yetus_add_option "--dependency-check-data-file=<path>" "path to local H2 database"
  yetus_add_option "--dependency-check-db-connection-string=<string>" "iff shared db, jdbs connection string"
  yetus_add_option "--dependency-check-db-driver-name=<classname>" "iff shared db, jdbc driver name"
  yetus_add_option "--dependency-check-db-driver-jar=<path>" "iff shared db, driver jar path"
  yetus_add_option "--dependency-check-db-username=<name>" "iff shared db, username"
  yetus_add_option "--dependency-check-db-password=<passwor>" "iff shared db, password"
  yetus_add_option "--dependency-check-maven-goal=<goal>" "iff maven build, the plugin goal to use. default: ${DEPENDENCY_CHECK_MAVEN_GOAL}"
}

## @audience     private
function dependency_check_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --dependency-check=*)
        DEPENDENCY_CHECK=${i#*=}
      ;;
      --dependency-check-severity-threshold=*)
        DEPENDENCY_CHECK_SEVERITY=${i#*=}
      ;;
      --dependency-check-suppression=*)
        yetus_comma_to_array DEPENDENCY_CHECK_SUPPRESSION_FILES "${i#*=}"
      ;;
      --dependency-check-excludes=*)
        yetus_comma_to_array DEPENDENCY_CHECK_EXCLUDES_PATTERNS "${i#*=}"
      ;;
      --dependency-check-experimental)
        DEPENDENCY_CHECK_EXPERIMENTAL=true
      ;;
      --dependency-check-no-updates)
        DEPENDENCY_CHECK_UPDATE=false
      ;;
      --dependency-check-data-file=*)
        DEPENDENCY_CHECK_DATA_FILE=${i#*=}
      ;;
      --dependency-check-db-connection-string=*)
        DEPENDENCY_CHECK_DB_CONNECTION=${i#*=}
      ;;
      --dependency-check-db-driver-name=*)
        DEPENDENCY_CHECK_DB_DRIVER=${i#*=}
      ;;
      --dependency-check-db-driver-jar=*)
        DEPENDENCY_CHECK_DB_DRIVER_JAR=${i#*=}
      ;;
      --dependency-check-db-username=*)
        DEPENDENCY_CHECK_DB_USER=${i#*=}
      ;;
      --dependency-check-db-password=*)
        DEPENDENCY_CHECK_DB_PASSWORD=${i#*=}
      ;;
      --dependency-check-maven-goal=*)
        DEPENDENCY_CHECK_MAVEN_GOAL=${i#*=}
      ;;
    esac
  done

}

## @audience     private
function dependency_check_filefilter
{
  declare filename=$1

  case ${BUILDTOOL} in
    maven)
      if [[ ${filename} =~ pom\.xml$ ]]; then
        yetus_debug "tests/dependency_check: ${filename}"
        add_test dependency_check
      fi
    ;;
    *)
      add_test dependency_check
    ;;
  esac
}

## @audience     private
function dependency_check_precheck
{
  declare dependency_check_version

  if ! yetus_array_contains "${DEPENDENCY_CHECK_SEVERITY}" "${DEPENDENCY_CHECK_SEVERITIES[@]}" ; then
    yetus_error "Dependency check doesn't know about severity level '${DEPENDENCY_CHECK_SEVERITY}'"
    return 1
  fi

  case ${BUILDTOOL} in
    maven)
      if [ "${#DEPENDENCY_CHECK_EXCLUDES_PATTERNS[@]}" -gt 0 ]; then
        yetus_error "dependency_check: The maven plugin doesn't support exclusion patterns."
        return 1
      fi
    ;;
    *)
      if ! verify_command "dependency_check" "${DEPENDENCY_CHECK}"; then
        add_vote_table 0 dependency_check "dependency-check was not available."
        delete_test dependency_check
        return 0
      fi
    ;;
  esac

  # Can't give both data file and db connection info
  if [ -n "${DEPENDENCY_CHECK_DATA_FILE}" ] && [ -n "${DEPENDENCY_CHECK_DB_CONNECTION}" ]; then
    yetus_debug "Both a local datafile and an external db were given on the cli, behavior of dependency-check isn't well defined."
  fi

  # finally let folks know what version they'll be dealing with.
  dependency_check_version=$(${DEPENDENCY_CHECK} --noupdate --version 2>/dev/null | head -n 1 2>/dev/null)
  add_footer_table dependency_check "version: ${dependency_check_version}"
}

## @audience     private
function dependency_check_initialize
{
  local -a filtered_severities
  local -i severity_threshold
  severity_threshold=$(yetus_array_index_of "DEPENDENCY_CHECK_SEVERITIES" "${DEPENDENCY_CHECK_SEVERITY}")
  yetus_debug "Looking for severities in our list ranked up to ${severity_threshold}"
  for key in "${!DEPENDENCY_CHECK_SEVERITIES[@]}"; do
    if [ ! "${key}" -gt "${severity_threshold}" ]; then
      filtered_severities=("${filtered_severities[@]}" "${DEPENDENCY_CHECK_SEVERITIES[${key}]}")
    fi
  done
  yetus_debug "Given severity threshold of '${DEPENDENCY_CHECK_SEVERITY}' we'll look for: ${filtered_severities[*]}"
  # The quotes here are important, because we want to match an entire CSV record
  IFS=" " read -r -a DEPENDENCY_CHECK_LOG_FILTERS <<< "$(printf -- '-e "%s" ' "${filtered_severities[@]}")"

  case ${BUILDTOOL} in
    maven)
      if [[ "${DEPENDENCY_CHECK_EXPERIMENTAL}" = "true" ]]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DenableExperimental=true")
      fi
      if [[ "${DEPENDENCY_CHECK_UPDATE}" = "false" ]] || [[ "${OFFLINE}" == "true" ]]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DautoUpdate=false")
      fi
      if [[ "${OFFLINE}" == "true" ]]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DcentralAnalyzerEnabled=false")
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DnexusAnalyzerEnabled=false")
      fi
      if [ -n "${DEPENDENCY_CHECK_DATA_FILE}" ]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DdataDirectory=${DEPENDENCY_CHECK_DATA_FILE}")
      fi
      DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-Dformat=ALL")
      DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DversionCheckEnabled=false")
      DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DskipProvidedScope=true")
      DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DskipSystemScope=true")
      if [ "${#DEPENDENCY_CHECK_SUPPRESSION_FILES[@]}" -gt 0 ]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DsuppressionFiles=$(printf -- "%s," "${DEPENDENCY_CHECK_SUPPRESSION_FILES[@]}")")
      fi
      if [ -n "${DEPENDENCY_CHECK_DB_CONNECTION}" ]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DconnectionString=${DEPENDENCY_CHECK_DB_CONNECTION}")
        if [ -n "${DEPENDENCY_CHECK_DB_DRIVER}" ]; then
          DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DdatabaseDriverName=${DEPENDENCY_CHECK_DB_DRIVER}")
        fi
        if [ -n "${DEPENDENCY_CHECK_DB_DRIVER_JAR}" ]; then
          DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DdatabaseDriverPath=${DEPENDENCY_CHECK_DB_DRIVER_JAR}")
        fi
        if [ -n "${DEPENDENCY_CHECK_DB_USER}" ]; then
          DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DdatabaseUser=${DEPENDENCY_CHECK_DB_USER}")
        fi
        if [ -n "${DEPENDENCY_CHECK_DB_PASSWORD}" ]; then
          DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "-DdatabasePassword=${DEPENDENCY_CHECK_DB_PASSWORD}")
        fi
      fi
    ;;
    *)
      if [[ "${DEPENDENCY_CHECK_EXPERIMENTAL}" = "true" ]]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --enableExperimental)
      fi
      if [[ "${DEPENDENCY_CHECK_UPDATE}" = "false" ]] || [[ "${OFFLINE}" == "true" ]]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --noupdate)
      fi
      if [[ "${OFFLINE}" == "true" ]]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --disableCentral)
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --disableNexus)
      fi
      if [ -n "${DEPENDENCY_CHECK_DATA_FILE}" ]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --data "${DEPENDENCY_CHECK_DATA_FILE}")
      fi

      if [ -n "${DEPENDENCY_CHECK_DB_CONNECTION}" ]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --connectionString "${DEPENDENCY_CHECK_DB_CONNECTION}")
        if [ -n "${DEPENDENCY_CHECK_DB_DRIVER}" ]; then
          DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --dbDriverName "${DEPENDENCY_CHECK_DB_DRIVER}")
        fi
        if [ -n "${DEPENDENCY_CHECK_DB_DRIVER_JAR}" ]; then
          DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --dbDriverPath "${DEPENDENCY_CHECK_DB_DRIVER_JAR}")
        fi
        if [ -n "${DEPENDENCY_CHECK_DB_USER}" ]; then
          DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --dbUser "${DEPENDENCY_CHECK_DB_USER}")
        fi
        if [ -n "${DEPENDENCY_CHECK_DB_PASSWORD}" ]; then
          DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --dbPassword "${DEPENDENCY_CHECK_DB_PASSWORD}")
        fi
      fi

      if [ "${#DEPENDENCY_CHECK_SUPPRESSION_FILES[@]}" -gt 0 ]; then
        local -a suppressions
        IFS=" " read -r -a suppressions <<< "$(printf -- "--suppression '%s' " "${DEPENDENCY_CHECK_SUPPRESSION_FILES[@]}")"
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "${suppressions[@]}")
      fi
      if [ "${#DEPENDENCY_CHECK_EXCLUDES_PATTERNS[@]}" -gt 0 ]; then
        local -a excludes
        IFS=" " read -r -a excludes <<< "$(printf -- "--exclude '%s' " "${DEPENDENCY_CHECK_EXCLUDES_PATTERNS[@]}")"
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" "${excludes[@]}")
      fi
      DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --format ALL)
      DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --project "${PROJECT_NAME}")
      if [ -n "${BASEDIR}" ]; then
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --scan "${BASEDIR}")
      else
        DEPENDENCY_CHECK_ARGS=("${DEPENDENCY_CHECK_ARGS[@]}" --scan ".")
      fi
    ;;
  esac


}

## @audience     private
function dependency_check_logfilter
{
  declare input=$1
  declare output=$2

  # TODO we should be parsing CSV columns properly
  yetus_debug "dependency_check: filtering out lines based on severities with '${DEPENDENCY_CHECK_LOG_FILTERS[*]}'"

  "${GREP}" "${DEPENDENCY_CHECK_LOG_FILTERS[@]}" "${input}" > "${output}"

}

## @audience     private
function dependency_check_postcompile
{
  declare repostatus=$1
  declare reports="dependency_check_${repostatus}.reports"
  if ! verify_needed_test dependency_check; then
    return 0
  fi

  big_console_header "Determining number of dependency concerns (${repostatus})"

  start_clock

  # Add our previously calculated time
  if [[ "${repostatus}" != branch ]]; then
    offset_clock "${DEPENDENCY_CHECK_TIMER}"
  fi

  mkdir "${PATCH_DIR}/${reports}"

  case ${BUILDTOOL} in
    maven)
      # invoke on a specific version, because older ones don't support options we need
      # like CSV report output.
      # shellcheck disable=2046
      echo_and_redirect "${PATCH_DIR}/dependency_check_${repostatus}.log" \
        $(maven_executor) --batch-mode "${DEPENDENCY_CHECK_ARGS[@]}" \
        "org.owasp:dependency-check-maven:3.1.2:${DEPENDENCY_CHECK_MAVEN_GOAL}"

      if [ ! -f "${BASEDIR:-.}/target/dependency-check-report.csv" ]; then
        yetus_debug "maven goal did not generate csv report"
        add_vote_table 0 dependency_check "${BUILDMODEMSG} maven goal did not generate needed report"
        return 1
      fi
      # TODO get the plugin to allow configuring the output directory to something other than the project build dir.
      # TODO maybe use the archive functionality here?
      mv "${BASEDIR:-.}/target/dependency-check-"*{csv,html,json,xml} "${PATCH_DIR}/${reports}/"
    ;;
    *)
      echo_and_redirect "${PATCH_DIR}/dependency_check_${repostatus}.log" \
          "${DEPENDENCY_CHECK}" "${DEPENDENCY_CHECK_ARGS[@]}" \
          --log "${PATCH_DIR}/dependency_check_${repostatus}.verbose.log" \
          --out "${PATCH_DIR}/${reports}"
    ;;
  esac

  generic_logfilter dependency_check \
      "${PATCH_DIR}/${reports}/dependency-check-report.csv" \
      "${PATCH_DIR}/dependency_check_${repostatus}_filtered.csv"

  if [[ "${repostatus}" = branch ]]; then
    DEPENDENCY_CHECK_TIMER=$(stop_clock)
  else
    # shellcheck disable=SC2016
    numPostpatch=$(wc -l < "${PATCH_DIR}/dependency_check_patch_filtered.csv")

    # iff the branch report doesn't already exist, we must be in a qbt build via --empty-patch
    if [ -f "${PATCH_DIR}/dependency_check_branch_filtered.csv" ]; then
      calcdiffs \
        "${PATCH_DIR}/dependency_check_branch_filtered.csv" \
        "${PATCH_DIR}/dependency_check_patch_filtered.csv" \
        dependency_check \
          > "${PATCH_DIR}/diff-dependency-check.csv"
      diffPostpatch=$(wc -l < "${PATCH_DIR}/diff-dependency-check.csv")

      # shellcheck disable=SC2016
      numPrepatch=$(wc -l < "${PATCH_DIR}/dependency_check_branch_filtered.csv")
    else
      numPrepatch=0
      diffPostpatch="${numPostpatch}"
      cp "${PATCH_DIR}/dependency_check_patch_filtered.csv" \
         "${PATCH_DIR}/diff-dependency-check.csv"
    fi

    statstring=$(generic_calcdiff_status "${numPrepatch}" "${numPostpatch}" "${diffPostpatch}" )

    if [[ ${diffPostpatch} -gt 0 ]] ; then
      add_vote_table -1 dependency_check "${BUILDMODEMSG} ${statstring}"
      add_footer_table dependency_check "@@BASE@@/diff-dependency-check.csv"
      return 1
    fi

    add_vote_table +1 dependency_check "${BUILDMODEMSG} ${statstring}"
  fi
  return 0
}

