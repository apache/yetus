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

# no public APIs here
# SHELLDOC-IGNORE

# this bug system handles JIRA.  Personalities
# can override the following variables:

# base JIRA URL
JIRA_URL=${JIRA_URL:-"https://issues.apache.org/jira"}

# Issue regex to help identify the project
JIRA_ISSUE_RE=''

# If the issue status is matched with this pattern, the attached patch is regarded as ready to be applied
JIRA_STATUS_RE='Patch Available'

add_bugsystem jira

# Simple function to set a default JIRA user after PROJECT_NAME has been set
function jira_set_jira_user
{
  if [[ -n "${PROJECT_NAME}" && ! "${PROJECT_NAME}" = unknown ]]; then
    JIRA_USER=${JIRA_USER:-"${PROJECT_NAME}qa"}
  fi
}

function jira_usage
{

  jira_set_jira_user

  yetus_add_option "--jira-base-url=<url>" "The URL of the JIRA server (default:'${JIRA_URL}')"
  yetus_add_option "--jira-issue-re=<expr>" "Regular expression to use when trying to find a JIRA ref in the patch name (default: '${JIRA_ISSUE_RE}')"
  yetus_add_option "--jira-password=<pw>" "The password for accessing JIRA"
  yetus_add_option "--jira-status-re=<expr>" "Regular expression representing the issue status whose patch is applicable to the codebase (default: '${JIRA_STATUS_RE}')"
  yetus_add_option "--jira-user=<user>" "The user to access JIRA command (default: ${JIRA_USER})"
}

function jira_parse_args
{
  declare i

  jira_set_jira_user

  for i in "$@"; do
    case ${i} in
      --jira-base-url=*)
        delete_parameter "${i}"
        JIRA_URL=${i#*=}
      ;;
      --jira-issue-re=*)
        delete_parameter "${i}"
        JIRA_ISSUE_RE=${i#*=}
      ;;
      --jira-password=*)
        delete_parameter "${i}"
        JIRA_PASSWD=${i#*=}
      ;;
      --jira-status-re=*)
        delete_parameter "${i}"
        JIRA_STATUS_RE=${i#*=}
      ;;
      --jira-user=*)
        delete_parameter "${i}"
        JIRA_USER=${i#*=}
      ;;
    esac
  done
}

## @description provides issue determination based upon the URL and more.
## @description WARNING: called from the github plugin!
function jira_determine_issue
{
  declare input=$1
  declare patchnamechunk
  declare maybeissue

  if [[ -n ${JIRA_ISSUE} ]]; then
    return 0
  fi

  if [[ -z "${JIRA_ISSUE_RE}" ]]; then
    return 1
  fi

  # shellcheck disable=SC2016
  patchnamechunk=$(echo "${input}" | "${AWK}" -F/ '{print $NF}')

  maybeissue=$(echo "${patchnamechunk}" | cut -f1,2 -d-)

  if [[ ${maybeissue} =~ ${JIRA_ISSUE_RE} ]]; then
    # shellcheck disable=SC2034
    ISSUE=${maybeissue}
    JIRA_ISSUE=${maybeissue}
    add_footer_table "JIRA Issue" "${JIRA_ISSUE}"
    return 0
  fi

  return 1
}

function jira_http_fetch
{
  declare input=$1
  declare output=$2
  declare ec

  yetus_debug "jira_http_fetch: ${JIRA_URL}/${input}"
  if [[ -n "${JIRA_USER}"
     && -n "${JIRA_PASSWD}" ]]; then
    "${CURL}" --silent --fail \
            --user "${JIRA_USER}:${JIRA_PASSWD}" \
            --output "${output}" \
            --location \
           "${JIRA_URL}/${input}"
  else
    "${CURL}" --silent --fail \
            --output "${output}" \
            --location \
           "${JIRA_URL}/${input}"
  fi
  ec=$?
  case "${ec}" in
  "0")
    ;;
  "1")
    yetus_debug "jira_http_fetch: Unsupported protocol. Maybe misspelled jira's url?"
    ;;
  "3")
    yetus_debug "jira_http_fetch: ${JIRA_URL}/${input} url is malformed."
    ;;
  "6")
    yetus_debug "jira_http_fetch: Could not resolve host in URL ${JIRA_URL}."
    ;;
  "22")
    yetus_debug "jira_http_fetch: ${JIRA_URL}/${input} returned 4xx status code. Maybe incorrect username/password?"
    ;;
  *)
    yetus_debug "jira_http_fetch: ${JIRA_URL}/${input} returned $ec error code. See https://ec.haxx.se/usingcurl-returns.html for details."
    ;;
  esac
  return ${ec}
}

function jira_locate_patch
{
  declare input=$1
  declare patchout=$2
  declare diffout=$3
  declare jsonloc
  declare relativeurl
  declare retval
  declare found=false

  yetus_debug "jira_locate_patch: trying ${JIRA_URL}/browse/${input}"

  if [[ "${OFFLINE}" == true ]]; then
    yetus_debug "jira_locate_patch: offline, skipping"
    return 1
  fi

  if ! jira_http_fetch "browse/${input}" "${PATCH_DIR}/jira"; then
    yetus_debug "jira_locate_patch: not a JIRA."
    return 1
  fi

  # if github is configured check to see if there is a URL in the text
  # that is a github patch file or pull request
  if [[ -n "${GITHUB_BASE_URL}" ]]; then
    jira_determine_issue "${input}"
    # Download information via REST API
    jsonloc="${PATCH_DIR}/jira-json"
    jira_http_fetch "rest/api/2/issue/${input}" "${jsonloc}"
    # Parse the downloaded information to check if the issue is
    # just a pointer to GitHub.
    if github_jira_bridge "${jsonloc}" "${patchout}" "${diffout}"; then
      echo "${input} appears to be a Github PR. Switching Modes."
      return 0
    fi
    yetus_debug "jira_locate_patch: ${input} seemed like a Github PR, but there was a failure."
  fi

  # Not reached if there is a successful github plugin return
  if [[ $("${GREP}" -c "${JIRA_STATUS_RE}" "${PATCH_DIR}/jira") == 0 ]]; then
    if [[ ${ROBOT} == true ]]; then
      yetus_error "ERROR: ${input} issue status is not matched with \"${JIRA_STATUS_RE}\"."
      cleanup_and_exit 1
    else
      yetus_error "WARNING: ${input} issue status is not matched with \"${JIRA_STATUS_RE}\"."
    fi
  fi

  # See https://jira.atlassian.com/browse/JRA-27637 as why we can't use
  # the REST interface here. :(
  # the assumption here is that attachment id's are given in an
  # ascending order. so bigger # == newer file
  #shellcheck disable=SC2016
  tr '>' '\n' < "${PATCH_DIR}/jira" \
    | "${AWK}" 'match($0,"/secure/attachment/[0-9]*/[^\"]*"){print substr($0,RSTART,RLENGTH)}' \
    | "${GREP}" -v -e 'htm[l]*$' \
    | "${SED}" -e 's,[ ]*$,,g' \
    | sort -n -r -k4 -t/ \
    | uniq \
      > "${PATCH_DIR}/jira-attachments.txt"

  echo "${input} patch is being downloaded at $(date) from"
  while read -r relativeurl && [[ ${found} = false ]]; do
    PATCHURL="${JIRA_URL}${relativeurl}"

    printf "  %s -> " "${PATCHURL}"

    jira_http_fetch "${relativeurl}" "${patchout}"
    retval=$?
    if [[ ${retval} == 0 ]]; then
      found=true
      echo "Downloaded"
    elif [[ ${retval} == 22 ]]; then
      echo "404"
      yetus_debug "Presuming the attachment was deleted, trying the next one (see YETUS-298)"
    else
      echo "Error (curl returned ${retval})"
      break
    fi
  done < <(cat "${PATCH_DIR}/jira-attachments.txt")

  if [[ "${found}" = false ]]; then
    yetus_error "ERROR: ${input} could not be downloaded."
    cleanup_and_exit 1
  fi

  if [[ ! ${PATCHURL} =~ \.patch$ ]]; then
    if guess_patch_file "${patchout}"; then
      yetus_debug "The patch ${PATCHURL} was not named properly, but it looks like a patch file. Proceeding, but issue/branch matching might go awry."
      add_vote_table_v2 0 patch "" "The patch file was not named according to ${PROJECT_NAME}'s naming conventions. Please see ${PATCH_NAMING_RULE} for instructions."
    else
      # this definitely isn't a patch so just bail out.
      return 1
    fi
  fi
  add_footer_table "JIRA Patch URL" "${PATCHURL}"

  return 0
}

## @description  Try to guess the branch being tested using a variety of heuristics
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success, with PATCH_BRANCH updated appropriately
function jira_determine_branch
{
  declare patchnamechunk
  declare total
  declare count
  declare hinttype

  for hinttype in "${PATCHURL}" "${PATCH_OR_ISSUE}"; do
    if [[ -z "${hinttype}" ]]; then
      continue
    fi

    # If one of these matches the JIRA issue regex
    # then we don't want it to trigger the branch
    # detection since that's almost certainly not
    # intended.  In other words, if ISSUE-99 is the
    # name of a branch, you want to test ISSUE-99
    # against main, not ISSUE-99's branch
    if [[ ${hinttype} =~ ${JIRA_ISSUE_RE} ]]; then
      continue
    fi

    yetus_debug "Determine branch: starting with ${hinttype}"
    patchnamechunk=$(echo "${hinttype}" \
            | "${SED}" -e 's,.*/\(.*\)$,\1,' \
                     -e 's,\.txt,.,' \
                     -e 's,.patch,.,g' \
                     -e 's,.diff,.,g' \
                     -e 's,\.\.,.,g' \
                     -e 's,\.$,,g' )

    # ISSUE-branch-##
    PATCH_BRANCH=$(echo "${patchnamechunk}" | cut -f3- -d- | cut -f1,2 -d-)
    yetus_debug "Determine branch: ISSUE-branch-## = ${PATCH_BRANCH}"
    if [[ -n "${PATCH_BRANCH}" ]]; then
      if verify_valid_branch  "${PATCH_BRANCH}"; then
        return 0
      fi
    fi

    # ISSUE-##[.##].branch
    PATCH_BRANCH=$(echo "${patchnamechunk}" | cut -f3- -d. )
    count="${PATCH_BRANCH//[^.]}"
    total=${#count}
    ((total = total + 3 ))
    until [[ ${total} -lt 3 ]]; do
      PATCH_BRANCH=$(echo "${patchnamechunk}" | cut "-f3-${total}" -d.)
      yetus_debug "Determine branch: ISSUE[.##].branch = ${PATCH_BRANCH}"
      ((total=total-1))
      if [[ -n "${PATCH_BRANCH}" ]]; then
        if verify_valid_branch  "${PATCH_BRANCH}"; then
          return 0
        fi
      fi
    done

    # ISSUE.branch.##
    PATCH_BRANCH=$(echo "${patchnamechunk}" | cut -f2- -d. )
    count="${PATCH_BRANCH//[^.]}"
    total=${#count}
    ((total = total + 3 ))
    until [[ ${total} -lt 2 ]]; do
      PATCH_BRANCH=$(echo "${patchnamechunk}" | cut "-f2-${total}" -d.)
      yetus_debug "Determine branch: ISSUE.branch[.##] = ${PATCH_BRANCH}"
      ((total=total-1))
      if [[ -n "${PATCH_BRANCH}" ]]; then
        if verify_valid_branch  "${PATCH_BRANCH}"; then
          return 0
        fi
      fi
    done

    # ISSUE-branch.##
    PATCH_BRANCH=$(echo "${patchnamechunk}" | cut -f3- -d- | cut -f1- -d. )
    count="${PATCH_BRANCH//[^.]}"
    total=${#count}
    ((total = total + 1 ))
    until [[ ${total} -lt 1 ]]; do
      PATCH_BRANCH=$(echo "${patchnamechunk}" | cut -f3- -d- | cut "-f1-${total}" -d. )
      yetus_debug "Determine branch: ISSUE-branch[.##] = ${PATCH_BRANCH}"
      ((total=total-1))
      if [[ -n "${PATCH_BRANCH}" ]]; then
        if verify_valid_branch  "${PATCH_BRANCH}"; then
          return 0
        fi
      fi
    done
  done

  return 1
}

## @description Write the contents of a file to JIRA
## @param     filename
## @stability stable
## @audience  public
## @return    exit code from posting to jira
function jira_write_comment
{
  declare -r commentfile=${1}
  declare retval=0

  if [[ "${OFFLINE}" == true ]]; then
    echo "JIRA Plugin: Running in offline, comment skipped."
    return 0
  fi

  if [[ -n ${JIRA_PASSWD}
     && -n ${JIRA_USER} ]]; then

    # RESTify the comment
    {
      echo "{\"body\":\""
      "${SED}" -e 's,\\,\\\\,g' \
          -e 's,\",\\\",g' \
          -e 's,$,\\r\\n,g' "${commentfile}" \
      | tr -d '\n'
      echo "\"}"
    } > "${PATCH_DIR}/jiracomment.$$"

    "${CURL}" -X POST \
         -H "Accept: application/json" \
         -H "Content-Type: application/json" \
         -u "${JIRA_USER}:${JIRA_PASSWD}" \
         -d @"${PATCH_DIR}/jiracomment.$$" \
         --silent --location \
           "${JIRA_URL}/rest/api/2/issue/${JIRA_ISSUE}/comment" \
          >/dev/null
    retval=$?
    rm "${PATCH_DIR}/jiracomment.$$"
  else
    echo "JIRA Plugin: no credentials provided to write a comment."
  fi
  return ${retval}
}

## @description  Print out the finished details to the JIRA issue
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function jira_finalreport
{
  declare result=$1
  declare i
  declare commentfile=${PATCH_DIR}/jiracommentfile
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
  declare fn
  declare logurl

  url=$(get_artifact_url)

  rm "${commentfile}" 2>/dev/null

  if [[ ${ROBOT} == "false"
      || ${OFFLINE} == true ]] ; then
    return 0
  fi

  #if [[ -z "${JIRA_ISSUE}" ]]; then
  #  return 0
  #fi

  big_console_header "Adding comment to JIRA"

  if [[ ${result} == 0 ]]; then
    echo "| (/) *{color:green}+1 overall{color}* |" >> "${commentfile}"
  else
    echo "| (x) *{color:red}-1 overall{color}* |" >> "${commentfile}"
  fi

  echo "\\\\" >>  "${commentfile}"

  i=0
  until [[ $i -ge ${#TP_HEADER[@]} ]]; do
    printf '%s\n' "${TP_HEADER[${i}]}" >> "${commentfile}"
    ((i=i+1))
  done

  echo "\\\\" >>  "${commentfile}"

  echo "|| Vote || Subsystem || Runtime ||  Logfile || Comment ||" >> "${commentfile}"

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
      echo "|| || || || {color:brown}${comment}{color} || ||" >> "${commentfile}"
      ((i=i+1))
      continue
    fi

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
        H)
          # this never gets called (see above) but this is here so others know the color is taken
          color="brown"
        ;;
        *)
          color="black"
        ;;
      esac
    fi
    if [[ -n "${logfile}" ]]; then
      fn=${logfile//@@BASE@@/}
      if [[ "${url}" =~ http ]]; then
        logurl=${logfile//@@BASE@@/${url}}
        fn="[${fn}|${logurl}]"
      fi
    else
      fn=""
    fi
    printf '| {color:%s}%s{color} | {color:%s}%s{color} | {color:%s}%s{color} | %s | {color:%s}%s{color} |\n' \
      "${color}" "${vote}" \
      "${color}" "${subs}" \
      "${color}" "${calctime}" \
      "${fn}" \
      "${color}" "${comment}" \
      >> "${commentfile}"
    ((i=i+1))
  done

  if [[ ${#TP_TEST_TABLE[@]} -gt 0 ]]; then
    { echo "\\\\" ; echo "\\\\"; } >>  "${commentfile}"

    echo "|| Reason || Tests ||" >>  "${commentfile}"
    i=0
    until [[ $i -ge ${#TP_TEST_TABLE[@]} ]]; do
      printf '%s\n' "${TP_TEST_TABLE[${i}]}" >> "${commentfile}"
      ((i=i+1))
    done
  fi

  { echo "\\\\" ; echo "\\\\"; } >>  "${commentfile}"


  echo "|| Subsystem || Report/Notes ||" >> "${commentfile}"
  i=0
  until [[ $i -ge ${#TP_FOOTER_TABLE[@]} ]]; do
    comment=$(echo "${TP_FOOTER_TABLE[${i}]}" | "${SED}" -e "s,@@BASE@@,${url},g")
    printf '%s\n' "${comment}" >> "${commentfile}"
    ((i=i+1))
  done

  printf '\n\nThis message was automatically generated.\n\n' >> "${commentfile}"

  cp "${commentfile}" "${commentfile}-jira.txt"

  jira_write_comment "${commentfile}"
}
