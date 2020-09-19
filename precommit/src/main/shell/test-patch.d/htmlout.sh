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

add_bugsystem htmlout

## @description  Usage info for htmlout plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function htmlout_usage
{
  yetus_add_option "--html-report-file=<file>" "Save the final report to an HTML-formated file"
}

## @description  Option parsing for htmlout plugin
## @audience     private
## @stability    evolving
## @replaceable  no
function htmlout_parse_args
{
  declare i
  declare fn
  declare url

  for i in "$@"; do
    case ${i} in
      --html-report-file=*)
        delete_parameter "${i}"
        fn=${i#*=}
      ;;
    esac
  done

  if [[ -n "${fn}" ]]; then
    if : > "${fn}"; then
      HTMLOUT_REPORTFILE_ORIG="${fn}"
      HTMLOUT_REPORTFILE=$(yetus_abs "${HTMLOUT_REPORTFILE_ORIG}")
    else
      yetus_error "WARNING: cannot create HTML report file ${fn}. Ignoring."
    fi
  fi
}

## @description  Give access to the HTML report file in docker mode
## @audience     private
## @stability    evolving
## @replaceable  no
function htmlout_docker_support
{
  if [[ -n ${HTMLOUT_REPORTFILE} ]]; then
    DOCKER_EXTRAARGS+=("-v" "${HTMLOUT_REPORTFILE}:${DOCKER_WORK_DIR}/report.htm")
    USER_PARAMS+=("--html-report-file=${DOCKER_WORK_DIR}/report.htm")
  fi
}


## @description  Write out an HTML version of the final report to a file
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function htmlout_finalreport
{
  declare result=$1
  declare i
  declare commentfile="${HTMLOUT_REPORTFILE}"
  declare comment
  declare vote
  declare ourstring
  declare ela
  declare subs
  declare color
  declare comment
  declare calctime
  declare url
  declare logfile

  url=$(get_artifact_url)

  rm "${commentfile}" 2>/dev/null

  if [[ -z "${HTMLOUT_REPORTFILE}" ]]; then
    return
  fi

  big_console_header "Writing HTML to ${commentfile}"

  {
    echo "<table><tbody>"

    if [[ ${result} == 0 ]]; then
      echo "<tr><th><font color=\"green\">+1 overall</font></th></tr>"
    else
      echo "<tr><th><font color=\"red\">-1 overall</font></th></tr>"
    fi
    echo "</tbody></table>"
    echo "<p></p>"
  } >  "${commentfile}"

  i=0
  until [[ $i -ge ${#TP_HEADER[@]} ]]; do
    ourstring=$(echo "${TP_HEADER[${i}]}" | tr -s ' ')
    comment=$(echo "${ourstring}"  | cut -f2 -d\|)
    printf '<tr><td>%s</td></tr>\n' "${comment}"
    ((i=i+1))
  done

  {
    echo "<table><tbody>"
    echo "<tr>"
    echo "<th>Vote</th>"
    echo "<th>Subsystem</th>"
    echo "<th>Runtime</th>"
    echo "<th>Log</th>"
    echo "<th>Comment</th>"
    echo "</tr>"
  } >> "${commentfile}"

  i=0
  until [[ $i -ge ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\| | tr -d ' ')
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    calctime=$(clock_display "${ela}")
    logfile=$(echo "${ourstring}" | cut -f5 -d\| | tr -d ' ')
    comment=$(echo "${ourstring}"  | cut -f6 -d\|)

    if [[ "${vote}" = "H" ]]; then
      {
        echo "<tr>"
        printf '\t\t<td></td>'
        printf "<td></td>"
        printf "<td></td>"
        printf '<td></td>'
        printf '<td><font color=\"%s\">%s</font></td>\n' "brown" "${comment}"
        echo "</tr>"
      } >> "${commentfile}"
      ((i=i+1))
      continue
    fi

    # summary line
    if [[ -z ${vote} && -n ${ela} ]]; then
      color="black"
    elif [[ -z ${vote} ]]; then
      # keep same color
      true
    else
      # new vote line
      case ${vote} in
        1|"+1")
          color="green"
        ;;
        -1)
          color="red"
        ;;
        0)
          color="blue"
        ;;
        -0)
          color="orange"
        ;;
        *)
          color="black"
        ;;
      esac
    fi

    {
      printf "<tr>\n"
      printf '\t\t<td><font color=\"%s\">%s</font></td>\n' "${color}" "${vote}"
      printf "\t\t<td><font color=\"%s\">%s</font></td>\n" "${color}" "${subs}"
      printf "\t\t<td><font color=\"%s\">%s</font></td>\n" "${color}" "${calctime}"
      if [[ -n "${logfile}" ]]; then
        t1=${logfile/@@BASE@@/}
        t2="<a href=\"${url}${t1}\">${t1}</a>"
        printf '<td><font color=\"%s\">%s</></font></td>\n' "${color}" "${t2}"
      else
        printf '<td></td>\n'
      fi
      printf '<td><font color=\"%s\">%s</font></td>\n' "${color}" "${comment}"
      printf "</tr>\n"
    } >> "${commentfile}"
    ((i=i+1))
  done
  {
    echo "</tbody></table>"
    echo "<p></p>"
  } >> "${commentfile}"

  if [[ ${#TP_TEST_TABLE[@]} -gt 0 ]]; then
    {
      echo "<table><tbody>"
      echo "<tr>"
      echo "<th>Reason</th>"
      echo "<th>Tests</th>"
      echo "</tr>"
    } >> "${commentfile}"

    i=0
    until [[ $i -ge ${#TP_TEST_TABLE[@]} ]]; do
      ourstring=$(echo "${TP_TEST_TABLE[${i}]}" | tr -s ' ')
      subs=$(echo "${ourstring}"  | cut -f2 -d\|)
      comment=$(echo "${ourstring}"  | cut -f3 -d\|)
      {
        echo "<tr>"
        printf "<td><font color=\"%s\">%s</font></td>" "${color}" "${subs}"
        printf "<td><font color=\"%s\">%s</font></td>" "${color}" "${comment}"
        echo "</tr>"
      } >> "${commentfile}"
      ((i=i+1))
    done

    {
      echo "</tbody></table>"
      echo "<p></p>"
    } >> "${commentfile}"
  fi

  {
    echo "<table><tbody>"
    echo "<tr>"
    echo "<th>Subsystem</th>"
    echo "<th>Report/Notes</th>"
    echo "</tr>"
  } >> "${commentfile}"

  i=0
  until [[ $i -ge ${#TP_FOOTER_TABLE[@]} ]]; do

    # turn off file globbing. break apart the string by spaces.
    # if our string begins with @@BASE@@, then create a substring
    # without the base url, and one with the base, but replace
    # it with the URL magic.  then use those strings in an href
    # structure.
    # otherwise, copy it unmodified.  this also acts to strip
    # excess spaces
    set -f
    ourstring=""
    for j in ${TP_FOOTER_TABLE[${i}]}; do
      if [[ "${j}" =~ ^@@BASE@@ ]]; then
        t1=${j#@@BASE@@/}
        t2=$(echo "${j}" | "${SED}" -e "s,@@BASE@@,${url},g")
        if [[ -n "${BUILD_URL}" ]]; then
          t2="<a href=\"${t2}\">${t1}</a>"
        fi
        ourstring="${ourstring} ${t2}"
      else
        ourstring="${ourstring} ${j}"
      fi
    done
    set +f

    subs=$(echo "${ourstring}"  | cut -f2 -d\|)
    comment=$(echo "${ourstring}"  | cut -f3 -d\|)

    {
      echo "<tr>"
      printf "<td><font color=\"%s\">%s</font></td>" "${color}" "${subs}"
      printf "<td><font color=\"%s\">%s</font></td>" "${color}" "${comment}"
      echo "</tr>"
    } >> "${commentfile}"
    ((i=i+1))
  done
  {
    echo "</tbody></table>"
    echo "<p></p>"
  } >> "${commentfile}"

  printf "<p>This message was automatically generated.</p>" >> "${commentfile}"
}
