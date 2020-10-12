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

add_bugsystem junit
add_test_format junit

JUNIT_TEST_TIMEOUTS=""
JUNIT_FAILED_TESTS=""

JUNIT_TEST_OUTPUT_DIR="."
JUNIT_TEST_PREFIX="org.apache."

function junit_usage
{
  yetus_add_option "--junit-test-output=<dir>" "Directory to search for the test output TEST-*.xml files, relative to the module directory (default:'${JUNIT_TEST_OUTPUT_DIR}')"
  yetus_add_option "--junit-test-prefix=<prefix to trim>" "Prefix of test names to be be removed. Used to shorten test names by removing common package name. (default:'${JUNIT_TEST_PREFIX}')"
  yetus_add_option "--junit-report-xml=<file>" "Filename to use when generating a JUnit-style report (default: ${JUNIT_REPORT_XML}"
}

function junit_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --junit-test-output=*)
        delete_parameter "${i}"
        JUNIT_TEST_OUTPUT_DIR=${i#*=}
      ;;
      --junit-test-prefix=*)
        delete_parameter "${i}"
        JUNIT_TEST_PREFIX=${i#*=}
      ;;
      --junit-report-xml=*)
        delete_parameter "${i}"
        fn=${i#*=}
      ;;
    esac
  done

  if [[ -n "${fn}" ]]; then
    if : > "${fn}"; then
      JUNIT_REPORT_XML_ORIG="${fn}"
      JUNIT_REPORT_XML=$(yetus_abs "${JUNIT_REPORT_XML_ORIG}")
    else
      yetus_error "WARNING: cannot create JUnit XML report file ${fn}. Ignoring."
    fi
  fi
}

function junit_process_tests
{
  # shellcheck disable=SC2034
  declare module=$1
  declare buildlogfile=$2
  declare result=0
  declare module_test_timeouts
  declare module_failed_tests

  if [[ -z "${JUNIT_TEST_OUTPUT_DIR}" ]]; then
    return 0
  fi

  # shellcheck disable=SC2016
  module_test_timeouts=$("${AWK}" '/^Running / { array[$NF] = 1 } /^Tests run: .* in / { delete array[$NF] } END { for (x in array) { print x } }' "${buildlogfile}")
  if [[ -n "${module_test_timeouts}" ]] ; then
    JUNIT_TEST_TIMEOUTS="${JUNIT_TEST_TIMEOUTS} ${module_test_timeouts}"
    ((result=result+1))
  fi

  #shellcheck disable=SC2026,SC2038,SC2016
  module_failed_tests=$(find "${JUNIT_TEST_OUTPUT_DIR}" -name 'TEST*.xml'\
    | xargs "${GREP}" -l -E "<failure|<error"\
    | "${AWK}" -F/ '{sub("'"TEST-${JUNIT_TEST_PREFIX}"'",""); sub(".xml",""); print $NF}')
  if [[ -n "${module_failed_tests}" ]] ; then
    JUNIT_FAILED_TESTS="${JUNIT_FAILED_TESTS} ${module_failed_tests}"
    ((result=result+1))
  fi

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

function junit_finalize_results
{
  declare jdk=$1

  if [[ -n "${JUNIT_FAILED_TESTS}" ]] ; then
    # shellcheck disable=SC2086
    populate_test_table "${jdk}Failed junit tests" ${JUNIT_FAILED_TESTS}
    JUNIT_FAILED_TESTS=""
  fi
  if [[ -n "${JUNIT_TEST_TIMEOUTS}" ]] ; then
    # shellcheck disable=SC2086
    populate_test_table "${jdk}Timed out junit tests" ${JUNIT_TEST_TIMEOUTS}
    JUNIT_TEST_TIMEOUTS=""
  fi
}

## @description  Give access to the junit report file in docker mode
## @audience     private
## @stability    evolving
## @replaceable  no
function junit_docker_support
{
  if [[ -n ${JUNIT_REPORT_XML} ]]; then
    DOCKER_EXTRAARGS+=("-v" "${JUNIT_REPORT_XML}:${DOCKER_WORK_DIR}/junit.xml")
    USER_PARAMS+=("--junit-report-xml=${DOCKER_WORK_DIR}/junit.xml")
  fi
}

## @description  Only print selected information to a report file
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
## @return       0 on success
## @return       1 on failure
function junit_finalreport
{
  declare result=$1
  shift
  declare i=0
  declare failures
  declare ourstring
  declare vote
  declare subs
  declare ela
  declare footcomment
  declare logfile
  declare comment
  declare url

  if [[ -z "${JUNIT_REPORT_XML}" ]]; then
    return
  fi

  big_console_header "Writing JUnit-style results to ${JUNIT_REPORT_XML}"

  url=$(get_artifact_url)

cat << EOF > "${JUNIT_REPORT_XML}"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
    <testsuite tests="1" failures="'${result}'" time="1" name="Apache Yetus">
EOF

  i=0
  until [[ $i -ge ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\|)
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    logfile=$(echo "${ourstring}" | cut -f5 -d\| | tr -d ' ')
    comment=$(echo "${ourstring}"  | cut -f6 -d\|)

    subs=${subs// }

    if [[ "${subs}"  == "${oldsubs}" ]]; then
      ((counter=counter+1))
    else
      oldsubs=${subs}
      ((counter=0))
    fi

    if [[ -z "${vote// }" || "${vote}" = "H" ]]; then
       ((i=i+1))
       continue
     fi

    if [[ ${vote// } = -1 ]]; then
      failures=1
    else
      failures=0
    fi

    {
      printf "<testcase id=\"%s\" classname=\"%s\" name=\"%s\" failures=\"%s\" tests=\"1\" time=\"%s\">" \
        "${subs}.${counter}" \
        "${subs}" \
        "${subs}" \
        "${failures}" \
        "${ela}"
      if [[ "${failures}" == 1 ]]; then
        comment=$(escape_html "${comment}")
        printf "<failure message=\"%s\">" "${comment}"

        if [[ -n "${logfile}" ]]; then
          if [[ -n "${url}" ]]; then
            footcomment=$(echo "${logfile}" | "${SED}" -e "s,@@BASE@@,${url},g")
          else
            footcomment=$(echo "${logfile}" | "${SED}" -e "s,@@BASE@@,${PATCH_DIR},g")
          fi
          escape_html "${footcomment}"
        fi
        echo "</failure>"
      fi
      echo "</testcase>"
    } >> "${JUNIT_REPORT_XML}"

    ((i=i+1))
  done

  echo "</testsuite>" >> "${JUNIT_REPORT_XML}"
  echo "</testsuites>" >> "${JUNIT_REPORT_XML}"
}
