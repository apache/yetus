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

# This bug system provides gitlab integration
add_bugsystem gitlab

# personalities can override the following settings:

# Web interface URL.
GITLAB_BASE_URL="https://gitlab.com"

# API interface URL.
GITLAB_API_URL="https://gitlab.com/api/v4"

# user/repo -- this might get set by robots
GITLAB_REPO=${GITLAB_REPO:-""}
GITLAB_REPO_ENC=""

# user settings
GITLAB_TOKEN=""
GITLAB_WRITE_ENABLED=true
GITLAB_USE_EMOJI_VOTE=false

# private globals...
GITLAB_COMMITSHA=""
GITLAB_ISSUE=""

function gitlab_usage
{
  yetus_add_option "--gitlab-url=<url>" "The URL for Gitlab (default: '${GITLAB_BASE_URL}')"
  yetus_add_option "--gitlab-disable-write" "Disable writing to Gitlab merge requests"
  yetus_add_option "--gitlab-token=<token>" "Personal access token to access Gitlab"
  yetus_add_option "--gitlab-repo=<repo>" "Gitlab repo to use (default:'${GITLAB_REPO}')"
  yetus_add_option "--gitlab-use-emoji-vote" "Whether to use emoji to represent the vote result on gitlab [default: ${GITLAB_USE_EMOJI_VOTE}]"
}

function gitlab_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --gitlab-disable-write)
        delete_parameter "${i}"
        GITLAB_WRITE_ENABLED=false
      ;;
      --gitlab-token=*)
        delete_parameter "${i}"
        GITLAB_TOKEN=${i#*=}
      ;;
      --gitlab-repo=*)
        delete_parameter "${i}"
        GITLAB_REPO=${i#*=}
      ;;
      --gitlab-url=*)
        delete_parameter "${i}"
        GITLAB_BASE_URL=${i#*=}
      ;;
      --gitlab-use-emoji-vote)
        delete_parameter "${i}"
        GITLAB_USE_EMOJI_VOTE=true
      ;;
    esac
  done
}

function gitlab_initialize
{
  if [[ -z "${GITLAB_REPO}" ]]; then
    GITLAB_REPO=${GITLAB_REPO_DEFAULT:-}
  fi

  # convert the repo into a URL encoded one.  Need this for lots of things.
  GITLAB_REPO_ENC=${GITLAB_REPO/\//%2F}

  if [[ "${PROJECT_NAME}" == "unknown" ]]; then
    PROJECT_NAME=${GITLAB_REPO##*/}
  fi
}

## @description given a URL, break it up into gitlab plugin globals
## @description this will *override* any personality or yetus defaults
## @description WARNING: Called from the Jenkins support system!
## @param url
function gitlab_breakup_url
{
  declare url=$1
  declare count
  declare pos1
  declare pos2

  count=${url//[^\/]}
  count=${#count}
  if [[ ${count} -gt 4 ]]; then
    ((pos2=count-3))
    ((pos1=pos2))

    GITLAB_BASE_URL=$(echo "${url}" | cut "-f1-${pos2}" -d/)

    ((pos1=pos1+1))
    ((pos2=pos1+1))

    GITLAB_REPO=$(echo "${url}" | cut "-f${pos1}-${pos2}" -d/)

    ((pos1=pos2+2))
    unset pos2

    GITLAB_ISSUE=$(echo "${url}" | cut "-f${pos1}-${pos2}" -d/ | cut -f1 -d.)
  else
    GITLAB_BASE_URL=$(echo "${url}" | cut -f1-3 -d/)
    GITLAB_REPO=$(echo "${url}" | cut -f4- -d/)
  fi
}

function gitlab_determine_issue
{
  declare input=$1

  if [[ ${input} =~ ^[0-9]+$
     && -n ${GITLAB_REPO} ]]; then
    # shellcheck disable=SC2034
    ISSUE=${input}
    if [[ -z ${GITLAB_ISSUE} ]]; then
      GITLAB_ISSUE=${input}
    fi
  fi

  if [[ -n ${GITLAB_ISSUE} ]]; then
    return 0
  fi

  return 1
}

## @description  Try to guess the branch being tested using a variety of heuristics
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success, with PATCH_BRANCH updated appropriately
## @return       1 on failure
function gitlab_determine_branch
{
  if [[ ! -f "${PATCH_DIR}/gitlab-merge.json" ]]; then
    return 1
  fi

  # shellcheck disable=SC2016
  PATCH_BRANCH=$("${AWK}" 'match($0,"\"ref\": \""){print $2}' "${PATCH_DIR}/gitlab-merge.json"\
     | cut -f2 -d\"\
     | tail -1  )

  yetus_debug "Gitlab determine branch: starting with ${PATCH_BRANCH}"

  verify_valid_branch "${PATCH_BRANCH}"
}

## @description  Given input = GL:##, download a patch to output.
## @description  Also sets GITLAB_ISSUE to the raw number.
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        input
## @param        output
## @return       0 on success
## @return       1 on failure
function gitlab_locate_mr_patch
{
  declare input=$1
  declare patchout=$2
  declare diffout=$3
  declare gitlabauth

  input=${input#GL:}

  # https://gitlab.com/your/repo/merge_requests/##
  if [[ ${input} =~ ^${GITLAB_BASE_URL}.*/merge_requests/[0-9]+$ ]]; then
    gitlab_breakup_url "${input}.patch"
    input=${GITLAB_ISSUE}
  fi

  # https://gitlab.com/your/repo/merge_requests/##.patch
  if [[ ${input} =~ ^${GITLAB_BASE_URL}.*patch$ ]]; then
    gitlab_breakup_url "${input}"
    input=${GITLAB_ISSUE}
  fi

  # https://gitlab.com/your/repo/merges/##.diff
  if [[ ${input} =~ ^${GITLAB_BASE_URL}.*diff$ ]]; then
    gitlab_breakup_url "${input}"
    input=${GITLAB_ISSUE}
  fi

  # if it isn't a number at this point, no idea
  # how to process
  if [[ ! ${input} =~ ^[0-9]+$ ]]; then
    yetus_debug "gitlab: ${input} is not a merge request #"
    return 1
  fi

  # we always merge the .patch version (even if .diff was given)
  # with the assumption that this way binary files work.
  # The downside of this is that the patch files are
  # significantly larger and therefore take longer to process
  PATCHURL="${GITLAB_BASE_URL}/${GITLAB_REPO}/merge_requests/${input}"
  echo "GITLAB MR #${input} is being downloaded at $(date) from"
  echo "${GITLAB_BASE_URL}/${GITLAB_REPO}/merge_requests/${input}"

  if [[ -n "${GITLAB_TOKEN}" ]]; then
    gitlabauth="Private-Token: ${GITLAB_TOKEN}"
  else
    gitlabauth="X-ignore-me: fake"
  fi

  # Let's merge the MR JSON for later use
  "${CURL}" --silent --fail \
          -H "${gitlabauth}" \
          --output "${PATCH_DIR}/gitlab-merge.json" \
          --location \
         "${GITLAB_API_URL}/${GITLAB_REPO}/merge_requests/${input}.json"

  echo "Patch from GITLAB MR #${input} is being downloaded at $(date) from"
  echo "${PATCHURL}"

  # the actual patch file
  if ! "${CURL}" --silent --fail \
          --output "${patchout}" \
          --location \
          -H "${gitlabauth}" \
         "${PATCHURL}.patch"; then
    yetus_debug "gitlab_locate_patch: not a gitlab merge request."
    return 1
  fi

  # the actual patch file
  if ! "${CURL}" --silent --fail \
          --output "${diffout}" \
          --location \
          -H "${gitlabauth}" \
         "${PATCHURL}.diff"; then
    yetus_debug "gitlab_locate_patch: not a gitlab merge request."
    return 1
  fi

  GITLAB_ISSUE=${input}

  # gitlab will translate this to be #(xx) !
  add_footer_table "GITLAB MR" "${GITLAB_BASE_URL}/${GITLAB_REPO}/merge_requests/${input}"

  return 0
}


## @description  a wrapper for gitlab_locate_pr_patch that
## @description  that takes a (likely checkout'ed) gitlab commit
## @description  sha and turns into the the gitlab pr
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        input
## @param        output
## @return       0 on success
## @return       1 on failure
function gitlab_locate_sha_patch
{
  declare input=$1
  declare patchout=$2
  declare diffout=$3
  declare mrid
  declare gitlabauth

  GITLAB_COMMITSHA=${input#GLSHA:}

  if [[ -n "${GITLAB_TOKEN}" ]]; then
    gitlabauth="Private-Token: ${GITLAB_TOKEN}"
  else
    gitlabauth="X-ignore-me: fake"
  fi

   # Let's merge the MR JSON for later use
  if ! "${CURL}" --fail \
          -H "${gitlabauth}" \
          --output "${PATCH_DIR}/gitlab-search.json" \
          --location \
          --silent \
         "${GITLAB_API_URL}/projects/${GITLAB_REPO_ENC}/repository/commits/${GITLAB_COMMITSHA}/merge_requests"; then
    return 1
  fi

  # shellcheck disable=SC2016
  mrid=$(cut -f2 -d, "${PATCH_DIR}/gitlab-search.json")
  mrid=${mrid/\"iid\":}

  # this is a dumb hack to work around gitlab-org/gitlab-ce#15280
  if [[ "${mrid}" = '[]' ]] && [[ "${GITLAB_CI}" = true ]]; then

    echo "This appears to be a full build due to gitlab-org/gitlab-ce#15280. Switching modes."

    PATCH_BRANCH=${CI_COMMIT_REF_NAME}

    # shellcheck disable=SC2034
    PATCH_OR_ISSUE=""
    # shellcheck disable=SC2034
    BUILDMODE=full
    set_buildmode
    return 0
  fi

  gitlab_locate_mr_patch "GL:${mrid}" "${patchout}" "${diffout}"
}

## @description  Handle the various ways to reference a gitlab MR
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        input
## @param        output
## @return       0 on success
## @return       1 on failure
function gitlab_locate_patch
{
  declare input=$1
  declare patchout=$2
  declare diffout=$3

  if [[ "${OFFLINE}" == true ]]; then
    yetus_debug "gitlab_locate_patch: offline, skipping"
    return 1
  fi

  case "${input}" in
      GLSHA:*)
        gitlab_locate_sha_patch "${input}" "${patchout}" "${diffout}"
      ;;
      *)
        gitlab_locate_mr_patch "${input}" "${patchout}" "${diffout}"
      ;;
  esac
}

## @description Write the contents of a file to gitlab
## @param     filename
## @stability stable
## @audience  public
function gitlab_write_comment
{
  declare -r commentfile=${1}
  declare retval=0
  declare restfile="${PATCH_DIR}/ghcomment.$$"
  declare gitlabauth

  if [[ "${GITLAB_WRITE_ENABLED}" == "false" ]]; then
    return 0
  fi

  if [[ "${OFFLINE}" == true ]]; then
    echo "Gitlab Plugin: Running in offline, comment skipped."
    return 0
  fi

  {
    printf "{\"body\":\""
    "${SED}" -e 's,\\,\\\\,g' \
        -e 's,\",\\\",g' \
        -e 's,$,\\r\\n,g' "${commentfile}" \
    | tr -d '\n'
    echo "\"}"
  } > "${restfile}"

  if [[ -n "${GITLAB_TOKEN}" ]]; then
    gitlabauth="Private-Token: ${GITLAB_TOKEN}"
  else
    echo "Gitlab Plugin: no credentials provided to write a comment."
    return 0
  fi

  "${CURL}" -X POST \
       -H "Content-Type: application/json" \
       -H "${gitlabauth}" \
       -d @"${restfile}" \
       --silent --location \
       --output "${PATCH_DIR}/gitlab-comment-out.json" \
         "${GITLAB_API_URL}/projects/${GITLAB_REPO_ENC}/merge_requests/${GITLAB_ISSUE}/notes" \
        >/dev/null

  retval=$?

  rm "${restfile}"
  return ${retval}
}

## @description  Print out the finished details to the Gitlab MR
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function gitlab_finalreport
{
  declare result=$1
  declare i
  declare commentfile=${PATCH_DIR}/gitcommentfile.$$
  declare comment
  declare url
  declare ela
  declare subs
  declare logfile
  declare calctime
  declare vote
  declare emoji

  if [[ "${GITLAB_WRITE_ENABLED}" == "false" ]]; then
    return 0
  fi

  url=$(get_artifact_url)

  rm "${commentfile}" 2>/dev/null

  if [[ ${ROBOT} = "false"
    || -z ${GITLAB_ISSUE} ]] ; then
    return 0
  fi

  big_console_header "Adding comment to Gitlab"

  if [[ ${result} == 0 ]]; then
    echo ":confetti_ball: **+1 overall**" >> "${commentfile}"
  else
    echo ":broken_heart: **-1 overall**" >> "${commentfile}"
  fi

  printf '\n\n\n\n' >>  "${commentfile}"

  i=0
  until [[ ${i} -ge ${#TP_HEADER[@]} ]]; do
    printf "%s\\n\\n" "${TP_HEADER[${i}]}" >> "${commentfile}"
    ((i=i+1))
  done

  {
    printf '\n\n'
    echo "| Vote | Subsystem | Runtime | Logfile | Comment |"
    echo "|:----:|----------:|--------:|:-------:|:-------:|"
  } >> "${commentfile}"

  i=0
  until [[ ${i} -ge ${#TP_VOTE_TABLE[@]} ]]; do
    ourstring=$(echo "${TP_VOTE_TABLE[${i}]}" | tr -s ' ')
    vote=$(echo "${ourstring}" | cut -f2 -d\| | tr -d ' ')
    subs=$(echo "${ourstring}"  | cut -f3 -d\|)
    ela=$(echo "${ourstring}" | cut -f4 -d\|)
    calctime=$(clock_display "${ela}")
    logfile=$(echo "${ourstring}" | cut -f5 -d\| | tr -d ' ')
    comment=$(echo "${ourstring}"  | cut -f6 -d\|)

    if [[ "${vote}" = "H" ]]; then
      echo "|||| _${comment}_ |" >> "${commentfile}"
      ((i=i+1))
      continue
    fi

    if [[ ${GITLAB_USE_EMOJI_VOTE} == true ]]; then
      emoji=""
      case ${vote} in
        1|"+1")
          emoji="+1 :green_heart:"
        ;;
        -1)
          emoji="-1 :x:"
        ;;
        0)
          emoji="+0 :ok:"
        ;;
        -0)
          emoji="-0 :warning:"
        ;;
        H)
          # this never gets called (see above) but this is here so others know the color is taken
          emoji=""
        ;;
        *)
          # usually this should not happen but let's keep the old vote result if it happens
          emoji=${vote}
        ;;
      esac
    else
      emoji="${vote}"
    fi

    if [[ -n "${logfile}" ]]; then
      t1=${logfile/@@BASE@@/}
      t2=$(echo "${logfile}" | "${SED}" -e "s,@@BASE@@,${url},g")
      t2="[${t1}](${t2})"
    else
      t2=""
    fi

    printf '| %s | %s | %s | %s | %s |\n' \
      "${emoji}" \
      "${subs}" \
      "${calctime}" \
      "${t2}" \
      "${comment}" \
      >> "${commentfile}"

    ((i=i+1))
  done

  if [[ ${#TP_TEST_TABLE[@]} -gt 0 ]]; then
    {
      printf '\n\n'
      echo "| Reason | Tests |"
      echo "|-------:|:------|"
    } >> "${commentfile}"
    i=0
    until [[ ${i} -ge ${#TP_TEST_TABLE[@]} ]]; do
      echo "${TP_TEST_TABLE[${i}]}" >> "${commentfile}"
      ((i=i+1))
    done
  fi

  {
    printf '\n\n'
    echo "| Subsystem | Report/Notes |"
    echo "|----------:|:-------------|"
  } >> "${commentfile}"


  i=0
  until [[ $i -ge ${#TP_FOOTER_TABLE[@]} ]]; do
    comment=$(echo "${TP_FOOTER_TABLE[${i}]}" | "${SED}" -e "s,@@BASE@@,${url},g")
    printf '%s\n' "${comment}" >> "${commentfile}"
    ((i=i+1))
  done

  printf '\n\nThis message was automatically generated.\n\n' >> "${commentfile}"

  gitlab_write_comment "${commentfile}"
}
