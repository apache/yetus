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
  yetus_add_option "--junit-test-output=<path>" "Directory to search for the test output TEST-*.xml files, relative to the module directory (default:'${JUNIT_TEST_OUTPUT_DIR}')"
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
        JUNIT_REPORT_XML=${i#*=}
      ;;
    esac
  done
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
  declare footsub
  declare footcomment

  if [[ -z "${JUNIT_REPORT_XML}" ]]; then
    return
  fi

  big_console_header "Writing JUnit-style results to ${JUNIT_REPORT_XML}"

  url=$(get_artifact_url)

cat << EOF > "${JUNIT_REPORT_XML}"
<testsuites>
    <testsuite tests="1" failures="'${result}'" time="1" name="Apache Yetus">
EOF

  i=0
  until [[ $i -eq ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\|)
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    msg=$(echo "${ourstring}" | cut -f5 -d\|)

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
        msg="${msg//&/&amp;}"
        msg="${msg//</&lt;}"
        msg="${msg//>/&gt;}"
        msg="${msg//\"/&quot;}"
        msg="${msg//\'/&apos;}"
        printf "<failure message=\"%s\">" "${msg}"
        j=0
        until [[ $j -eq ${#TP_FOOTER_TABLE[@]} ]]; do
          if [[ "${TP_FOOTER_TABLE[${j}]}" =~ \@\@BASE\@\@ ]]; then
            footsub=$(echo "${TP_FOOTER_TABLE[${j}]}" | cut -f2 -d\|)
            footcomment=$(echo "${TP_FOOTER_TABLE[${j}]}" |
                        cut -f3 -d\| |
                        "${SED}" -e "s,@@BASE@@,${PATCH_DIR},g")
            if [[ -n "${url}" ]]; then
              footcomment=$(echo "${TP_FOOTER_TABLE[${j}]}" |
                        cut -f3 -d\| |
                        "${SED}" -e "s,@@BASE@@,${url},g")
            fi
            if [[ "${footsub// }" == "${subs}" ]]; then
              footcomment="${footcomment//&/&amp;}"
              footcomment="${footcomment//</&lt;}"
              footcomment="${footcomment//>/&gt;}"
              footcomment="${footcomment//\"/&quot;}"
              footcomment="${footcomment//\'/&apos;}"
              echo "${footcomment}"
            fi
          fi
          ((j=j+1))
        done
        echo "</failure>"
      fi
      echo "</testcase>"
    } >> "${JUNIT_REPORT_XML}"

    ((i=i+1))
  done

  echo "</testsuite>" >> "${JUNIT_REPORT_XML}"
  echo "</testsuites>" >> "${JUNIT_REPORT_XML}"
}