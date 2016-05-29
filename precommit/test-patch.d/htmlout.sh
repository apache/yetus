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

  for i in "$@"; do
    case ${i} in
      --html-report-file=*)
        fn=${i#*=}
      ;;
    esac
  done

  if [[ -n "${fn}" ]]; then
    touch "${fn}" 2>/dev/null
    if [[ $? != 0 ]]; then
      yetus_error "WARNING: cannot create ${fn}. Ignoring."
    else
      HTMLOUT_REPORTFILE=$(yetus_abs "${fn}")
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
    DOCKER_EXTRAARGS=("${DOCKER_EXTRAARGS[@]}" "-v" "${HTMLOUT_REPORTFILE}:${HTMLOUT_REPORTFILE}")
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
  until [[ $i -eq ${#TP_HEADER[@]} ]]; do
    ourstring=$(echo "${TP_HEADER[${i}]}" | tr -s ' ')
    comment=$(echo "${ourstring}"  | cut -f2 -d\|)
    printf "<tr><td>%s</td></tr>\n" "${comment}"
    ((i=i+1))
  done

  {
    echo "<table><tbody>"
    echo "<tr>"
    echo "<th>Vote</th>"
    echo "<th>Subsystem</th>"
    echo "<th>Runtime</th>"
    echo "<th>Comment</th>"
    echo "</tr>"
  } >> "${commentfile}"

  i=0
  until [[ $i -eq ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\| | tr -d ' ')
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    calctime=$(clock_display "${ela}")
    comment=$(echo "${ourstring}"  | cut -f5 -d\|)

    # summary line
    if [[ -z ${vote}
      && -n ${ela} ]]; then
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
      echo "<tr>"
      printf "<td><font color=\"%s\">%s</font></td>" "${color}" "${vote}"
      printf "<td><font color=\"%s\">%s</font></td>" "${color}" "${subs}"
      printf "<td><font color=\"%s\">%s</font></td>" "${color}" "${calctime}"
      printf "<td><font color=\"%s\">%s</font></td>" "${color}" "${comment}"
      echo "</tr>"
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
    until [[ $i -eq ${#TP_TEST_TABLE[@]} ]]; do
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
  until [[ $i -eq ${#TP_FOOTER_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_FOOTER_TABLE[${i}]}" |
              ${SED} -e "s,@@BASE@@,${BUILD_URL}${BUILD_URL_ARTIFACTS},g" |
              tr -s ' ')
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
