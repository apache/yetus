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


# This bug system handles the output on the screen.

add_bugsystem console

CONSOLE_USE_BUILD_URL=false

## @description  Print out the finished details on the console
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
## @return       0 on success
## @return       1 on failure
function console_finalreport
{
  declare result=$1
  shift
  declare i=0
  declare ourstring
  declare vote
  declare subs
  declare ela
  declare comment
  declare commentfile1="${PATCH_DIR}/comment.1"
  declare commentfile2="${PATCH_DIR}/comment.2"
  declare normaltop
  declare line
  declare seccoladj=0
  declare spcfx=${PATCH_DIR}/spcl.txt
  declare calctime

  if [[ -n "${CONSOLE_REPORT_FILE}" ]]; then
    exec 6>&1
    exec >"${CONSOLE_REPORT_FILE}"
  fi

  if [[ ${result} == 0 ]]; then
    if [[ ${ROBOT} == false ]]; then
      if declare -f ${PROJECT_NAME}_console_success >/dev/null; then
        "${PROJECT_NAME}_console_success" > "${spcfx}"
      else
        {
          printf "IF9fX18gICAgICAgICAgICAgICAgICAgICAgICAgICAgICBfIAovIF9fX3wg";
          printf "XyAgIF8gIF9fXyBfX18gX19fICBfX18gX19ffCB8ClxfX18gXHwgfCB8IHwv";
          printf "IF9fLyBfXy8gXyBcLyBfXy8gX198IHwKIF9fXykgfCB8X3wgfCAoX3wgKF98";
          printf "ICBfXy9cX18gXF9fIFxffAp8X19fXy8gXF9fLF98XF9fX1xfX19cX19ffHxf";
          printf "X18vX19fKF8pCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg";
          printf "ICAK";
        } > "${spcfx}"
      fi
    fi
    printf "\n\n+1 overall\n\n"
  else
    if [[ ${ROBOT} == false ]]; then
      if declare -f ${PROJECT_NAME}_console_failure >/dev/null; then
        "${PROJECT_NAME}_console_failure" > "${spcfx}"
      else
        {
          printf "IF9fX19fICAgICBfIF8gICAgICAgICAgICAgICAgXyAKfCAgX19ffF8gXyhf";
          printf "KSB8XyAgIF8gXyBfXyBfX198IHwKfCB8XyAvIF9gIHwgfCB8IHwgfCB8ICdf";
          printf "Xy8gXyBcIHwKfCAgX3wgKF98IHwgfCB8IHxffCB8IHwgfCAgX18vX3wKfF98";
          printf "ICBcX18sX3xffF98XF9fLF98X3wgIFxfX18oXykKICAgICAgICAgICAgICAg";
          printf "ICAgICAgICAgICAgICAgICAK"
        } > "${spcfx}"
      fi
    fi
    printf "\n\n-1 overall\n\n"
  fi

  if [[ -f ${spcfx} ]]; then
    if which base64 >/dev/null 2>&1; then
      base64 --decode "${spcfx}" 2>/dev/null
    elif which openssl >/dev/null 2>&1; then
      openssl enc -A -d -base64 -in "${spcfx}" 2>/dev/null
    fi
    echo
    echo
    rm "${spcfx}"
  fi

  seccoladj=$(findlargest 2 "${TP_VOTE_TABLE[@]}")
  if [[ ${seccoladj} -lt 10 ]]; then
    seccoladj=10
  fi

  seccoladj=$((seccoladj + 2 ))
  i=0
  until [[ $i -eq ${#TP_HEADER[@]} ]]; do
    printf "%s\n" "${TP_HEADER[${i}]}"
    ((i=i+1))
  done

  printf "| %s | %*s |  %s   | %s\n" "Vote" ${seccoladj} Subsystem Runtime "Comment"
  echo "============================================================================"
  i=0
  until [[ $i -eq ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\|)
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    calctime=$(clock_display "${ela}")
    comment=$(echo "${ourstring}"  | cut -f5 -d\|)

    echo "${comment}" | fold -s -w $((78-seccoladj-22)) > "${commentfile1}"
    normaltop=$(head -1 "${commentfile1}")
    ${SED} -e '1d' "${commentfile1}"  > "${commentfile2}"

    printf "| %4s | %*s | %-10s |%-s\n" "${vote}" ${seccoladj} \
      "${subs}" "${calctime}" "${normaltop}"
    while read -r line; do
      printf "|      | %*s |            | %-s\n" ${seccoladj} " " "${line}"
    done < "${commentfile2}"

    ((i=i+1))
    rm "${commentfile2}" "${commentfile1}" 2>/dev/null
  done

  if [[ ${#TP_TEST_TABLE[@]} -gt 0 ]]; then
    seccoladj=$(findlargest 1 "${TP_TEST_TABLE[@]}")
    printf "\n\n%*s | Tests\n" "${seccoladj}" "Reason"
    i=0
    until [[ $i -eq ${#TP_TEST_TABLE[@]} ]]; do
      ourstring=$(echo "${TP_TEST_TABLE[${i}]}" | tr -s ' ')
      vote=$(echo "${ourstring}" | cut -f2 -d\|)
      subs=$(echo "${ourstring}"  | cut -f3 -d\|)
      printf "%*s | %s\n" "${seccoladj}" "${vote}" "${subs}"
      ((i=i+1))
    done
  fi

  printf "\n\n|| Subsystem || Report/Notes ||\n"
  echo "============================================================================"
  i=0

  until [[ $i -eq ${#TP_FOOTER_TABLE[@]} ]]; do
    if [[ "${CONSOLE_USE_BUILD_URL}" = true &&
          -n "${BUILD_URL}" ]]; then
      comment=$(echo "${TP_FOOTER_TABLE[${i}]}" |
                ${SED} -e "s,@@BASE@@,${BUILD_URL}${BUILD_URL_ARTIFACTS},g")
    else
      comment=$(echo "${TP_FOOTER_TABLE[${i}]}" |
                ${SED} -e "s,@@BASE@@,${PATCH_DIR},g")
    fi
    printf "%s\n" "${comment}"
    ((i=i+1))
  done

  if [[ -n "${CONSOLE_REPORT_FILE}" ]]; then
    exec 1>&6 6>&-
    cat "${CONSOLE_REPORT_FILE}"
  fi
}
