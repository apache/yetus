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

# Make sure that bash version meets the pre-requisite

if [[ -z "${BASH_VERSINFO[0]}" ]] \
   || [[ "${BASH_VERSINFO[0]}" -lt 3 ]] \
   || [[ "${BASH_VERSINFO[0]}" -eq 3 && "${BASH_VERSINFO[1]}" -lt 2 ]]; then
  echo "bash v3.2+ is required. Sorry."
  exit 1
fi

this="${BASH_SOURCE-$0}"
BINDIR=$(cd -P -- "$(dirname -- "${this}")" >/dev/null && pwd -P)
#shellcheck disable=SC2034
QATESTMODE=false
STARTINGDIR=$(pwd)


## @description  disable function
## @stability    stable
## @audience     private
## @replaceable  no
function add_vote_table_v2
{
  true
}

## @description  disable function
## @stability    stable
## @audience     private
## @replaceable  no
function add_footer_table
{
  true
}

## @description  disable function
## @stability    stable
## @audience     private
## @replaceable  no
function big_console_header
{
  true
}

## @description  disable function
## @stability    stable
## @audience     private
## @replaceable  no
function add_test
{
  true
}


## @description  disable function
## @stability    stable
## @audience     private
## @replaceable  no
function bugsystem_finalreport
{
  true
}

## @description  Clean the filesystem as appropriate and then exit
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function cleanup_and_exit
{
  local result=$1

  if [[ ${PATCH_DIR} =~ ^/tmp/yetus
    && -d ${PATCH_DIR} ]]; then
    rm -rf "${PATCH_DIR}"
  fi

  # shellcheck disable=SC2086
  exit ${result}
}

## @description  Setup the default global variables
## @audience     public
## @stability    stable
## @replaceable  no
function setup_defaults
{
  common_defaults
  REPORTONLY=false
}

## @description  Print the usage information
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_usage
{
  echo "smart-apply-patch.sh [OPTIONS] patch"
  echo ""
  echo "Where:"
  echo "  patch is a file, URL, or bugsystem-compatible location of the patch file"
  echo ""
  echo "Options:"
  echo ""
  yetus_add_option "--committer" "Apply patches like a boss."
  yetus_add_option "--debug" "If set, then output some extra stuff to stderr"
  yetus_add_option "--dry-run" "Check for patch viability without applying"
  yetus_add_option "--gpg-sign" "GPG sign the commit using gpg keys"
  yetus_add_option "--ignore-unknown-options=<bool>" "Continue despite unknown options (default: ${IGNORE_UNKNOWN_OPTIONS})"
  yetus_add_option "--list-plugins" "List all installed plug-ins and then exit"
  yetus_add_option "--modulelist=<list>" "Specify additional modules to test (comma delimited)"
  yetus_add_option "--offline" "Avoid connecting to the Internet"
  yetus_add_option "--patch-dir=<dir>" "The directory for working and output files (default '/tmp/yetus-(random))"
  yetus_add_option "--personality=<file>" "The personality file to load"
  yetus_add_option "--plugins=<list>" "Specify which plug-ins to add/delete (comma delimited; use 'all' for all found)"
  yetus_add_option "--project=<name>" "The short name for project currently using test-patch (default 'yetus')"
  yetus_add_option "--skip-system-plugins" "Do not load plugins from ${BINDIR}/plugins.d"
  yetus_add_option "--user-plugins=<dir>" "A directory of user provided plugins. (default ${USER_PLUGIN_DIR})"
  yetus_add_option "--version" "Print release version information and exit"
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage

  echo ""
  echo "Shell binary overrides:"
  yetus_add_option "--awk-cmd=<cmd>" "The 'awk' command to use (default 'awk')"
  yetus_add_option "--curl-cmd=<cmd>" "The 'curl' command to use (default 'curl')"
  yetus_add_option "--diff-cmd=<cmd>" "The GNU-compatible 'diff' command to use (default 'diff')"
  yetus_add_option "--file-cmd=<cmd>" "The 'file' command to use (default 'file')"
  yetus_add_option "--git-cmd=<cmd>" "The 'git' command to use (default 'git')"
  yetus_add_option "--grep-cmd=<cmd>" "The 'grep' command to use (default 'grep')"
  yetus_add_option "--patch-cmd=<cmd>" "The 'patch' command to use (default 'patch')"
  yetus_add_option "--sed-cmd=<cmd>" "The 'sed' command to use (default 'sed')"
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage

  echo ""
  echo "Patch reporting:"
  yetus_add_option "--build-tool=<tool>" "Override the build tool"
  yetus_add_option "--changedfilesreport=<name>" "List of files that this patch modifies"
  yetus_add_option "--changedmodulesreport=<name>" "List of modules that this patch modifies"
  yetus_add_option "--changedunionreport=<name>" "Union of modules that this patch modifies"
  yetus_add_option "--report-only" "Do not try to apply at all; just report on the patch"
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage

  echo ""
  importplugins

  #shellcheck disable=SC2034
  BUILDTOOLS=()
  #shellcheck disable=SC2034
  TESTTYPES=()
  #shellcheck disable=SC2034
  TESTFORMATS=()

  for plugin in "${BUGSYSTEMS[@]}"; do
    if declare -f "${plugin}_usage" >/dev/null 2>&1; then
      echo ""
      echo "${plugin} plugin usage options:"
      "${plugin}_usage"
      yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
      yetus_reset_usage
    fi
  done
}

## @description  Interpret the command line parameters
## @audience     private
## @stability    stable
## @replaceable  no
## @param        $@
## @return       May exit on failure
function parse_args
{
  local i

  common_args "$@"

  for i in "$@"; do
    case ${i} in
      --build-tool=*)
        delete_parameter "${i}"
        BUILDTOOL=${i#*=}
      ;;
      --committer)
        delete_parameter "${i}"
        COMMITMODE=true
      ;;
      --gpg-sign)
        delete_parameter "${i}"
        GPGSIGN=true
      ;;
      --dry-run)
        delete_parameter "${i}"
        PATCH_DRYRUNMODE=true
      ;;
      --changedfilesreport=*)
        delete_parameter "${i}"
        FILEREPORT=${i#*=}
      ;;
      --changedmodulesreport=*)
        delete_parameter "${i}"
        MODULEREPORT=${i#*=}
      ;;
      --changedunionreport=*)
        delete_parameter "${i}"
        UNIONREPORT=${i#*=}
      ;;
      --report-only)
        delete_parameter "${i}"
        REPORTONLY=true
      ;;
      --*)
        ## PATCH_OR_ISSUE can't be a --.  So this is probably
        ## a plugin thing.
        continue
      ;;
      *)
        PATCH_OR_ISSUE=${i#*=}
      ;;
    esac
  done

  if [[ ! -d ${PATCH_DIR} ]]; then
   if ! mkdir -p "${PATCH_DIR}"; then
      yetus_error "ERROR: Unable to create ${PATCH_DIR}"
      cleanup_and_exit 1
    fi
  fi

  # we need absolute dir for ${BASEDIR}
  cd "${STARTINGDIR}" || cleanup_and_exit 1
  BASEDIR=$(yetus_abs "${BASEDIR}")
}

## @description  generate reports on the given patch file
## @replaceable  no
## @audience     private
## @stability    evolving
function patch_reports
{
  declare i

  if [[ -z "${FILEREPORT}" ]] && [[ -z "${MODULEREPORT}" ]] && [[ -z "${UNIONREPORT}" ]]; then
    return
  fi

  find_changed_files

  if [[ -n "${FILEREPORT}" ]]; then
    : > "${FILEREPORT}"
    for i in "${CHANGED_FILES[@]}"; do
      echo "${i}" >> "${FILEREPORT}"
    done
  fi

  if [[ -n "${MODULEREPORT}" ]] || [[ -n "${UNIONREPORT}" ]]; then
    if [[ -z "${BUILDTOOL}" ]]; then
      guess_build_tool
    fi

    unset -f "${BUILDTOOL}_reorder_modules"

    find_changed_modules

    if [[ -n "${MODULEREPORT}" ]]; then
      : > "${MODULEREPORT}"
      for i in "${CHANGED_MODULES[@]}"; do
        echo "${i}" >> "${MODULEREPORT}"
      done
    fi

    if [[ -n "${UNIONREPORT}" ]]; then
      cat "${CHANGED_UNION_MODULES}" > "${UNIONREPORT}"
    fi
  fi
}

## @description  git am dryrun
## @replaceable  no
## @audience     private
## @stability    evolving
function gitam_dryrun
{

  # there is no dryrun method for git-am, so just
  # use apply instead.
  gitapply_dryrun "$@"

  if [[ ${PATCH_METHOD} = "gitapply" ]]; then
    PATCH_METHOD="gitam"
  fi
}

## @description  git am signoff
## @replaceable  no
## @audience     private
## @stability    evolving
function gitam_apply
{
  declare patchfile=$1
  declare gpg=$2

  if [[ ${gpg} = true ]]; then
    EXTRA_ARGS="-S"
  fi

  echo "Applying the patch:"
  yetus_run_and_redirect "${PATCH_DIR}/apply-patch-git-am.log" \
    "${GIT}" am --signoff ${EXTRA_ARGS} --whitespace=fix "-p${PATCH_LEVEL}" "${patchfile}"
  RESULT=$?
  "${GREP}" -v "^Checking" "${PATCH_DIR}/apply-patch-git-am.log"

  # fallback
  if [[ ${RESULT} -gt 0 && ${PATCH_SYSTEM} == 'jira' ]]; then
    echo "Use git apply and commit with the information from jira."
    gitapply_and_commit "${patchfile}"
  fi
}

## @description  get author and summary from jira and commit it.
##               if the author and the summary contains " or *,
##               the function does not work correctly because
##               the characters are used for delimiters.
## @replaceable  no
## @audience     private
## @stability    evolving
function gitapply_and_commit
{
  declare patchfile=$1
  declare jsontmpfile
  declare assigneeline
  declare assigneefile
  declare name
  declare email
  declare author
  declare summary

  yetus_debug "gitapply_and_commit: fetching ${JIRA_URL}/rest/api/2/issue/${PATCH_OR_ISSUE}"
  if ! jira_http_fetch "rest/api/2/issue/${PATCH_OR_ISSUE}" "${PATCH_DIR}/issue"; then
    yetus_debug "gitapply_and_commit: not a JIRA."
    return 1
  fi

  jsontmpfile="${PATCH_DIR}/jsontmpfile"
  # cannot set " as delimiter for cut command in script, so replace " with *
  tr ',' '\n' < "${PATCH_DIR}/issue" | "${SED}" 's/\"/*/g' > "${jsontmpfile}"

  assigneeline=$("${GREP}" -n -E '^\*assignee\*:' "${jsontmpfile}" | cut -f1 -d":")
  assigneefile="${PATCH_DIR}/assigneefile"
  tail -n +"${assigneeline}" "${jsontmpfile}" | head -n 20 > "${assigneefile}"

  name=$("${GREP}" "displayName" "${assigneefile}" | cut -f4 -d"*")
  email=$("${GREP}" "emailAddress" "${assigneefile}" | cut -f4 -d"*" \
    | "${SED}" 's/ at /@/g' | "${SED}" 's/ dot /./g')
  author="${name} <${email}>"
  summary=$("${GREP}" -E '^\*summary\*:' "${jsontmpfile}" | cut -f4 -d"*")
  gitapply_apply "${patchfile}"
  "${GIT}" add --all
  echo "Committing with author: ${author}, summary: ${summary}"
  yetus_run_and_redirect "${PATCH_DIR}/apply-patch-git-am-fallback.log" \
    "${GIT}" commit ${EXTRA_ARGS} --signoff -m "${PATCH_OR_ISSUE}. ${summary}" \
    --author="${author}"
}

## @description import core library routines
## @audience private
## @stability evolving
function import_core
{
  declare filename

  for filename in "${BINDIR}/core.d"/*; do
    # shellcheck disable=SC1091
    # shellcheck source=core.d/01-common.sh
    . "${filename}"
  done
}

## @description setup the parameter tracker for param errors
## @audience    private
## @stability   evolving
function setup_parameter_tracker
{
  declare i

  for i in "${USER_PARAMS[@]}"; do
    if [[ "${i}" =~ ^-- ]]; then
      i=${i%=*}
      PARAMETER_TRACKER+=("${i}")
    fi
  done
}

trap "cleanup_and_exit 1" HUP INT QUIT TERM

# robots will change USER_PARAMS so must
# do this before importing other code
setup_parameter_tracker

import_core

setup_defaults

parse_args "$@"

importplugins
yetus_debug "Removing TESTTYPES and TESTFORMATS from installed plug-in list"
#shellcheck disable=SC2034
TESTTYPES=()
#shellcheck disable=SC2034
TESTFORMATS=()

parse_args_plugins "$@"

if [[ "${#PARAMETER_TRACKER}" -gt 0 ]]; then
  yetus_error "ERROR: Unprocessed flag(s): ${PARAMETER_TRACKER[*]}"
  if [[ "${IGNORE_UNKNOWN_OPTIONS}" == false ]]; then
    cleanup_and_exit 1
  fi
fi

plugins_initialize

locate_patch

if [[ "${REPORTONLY}" = true ]]; then
  INPUT_APPLIED_FILE="${INPUT_PATCH_FILE}"
  patch_reports
  cleanup_and_exit 0
fi

if [[ ${COMMITMODE} = true ]]; then
  status=$("${GIT}" status --porcelain)
  if [[ "$status" != "" ]] ; then
    yetus_error "ERROR: Can't use --committer option in a workspace that contains the following modifications:"
    yetus_error "${status}"
    cleanup_and_exit 1
  fi
  PATCH_METHODS=("gitam" "${PATCH_METHODS[@]}")
fi

if ! dryrun_both_files; then
  yetus_error "ERROR: Aborting! ${PATCH_OR_ISSUE} cannot be verified."
  cleanup_and_exit ${RESULT}
fi

patch_file_hinter "${INPUT_APPLIED_FILE}"

if [[ "${INPUT_APPLIED_FILE}" ==  "${INPUT_DIFF_FILE}" ]]; then
  yetus_error "WARNING: "Used diff version of patch file. Binary files and potentially other changes not applied. Please rebase and squash commits if necessary.""
fi

pushd "${BASEDIR}" >/dev/null || exit 1

if [[ ${PATCH_DRYRUNMODE} == false ]]; then
  patchfile_apply_driver "${INPUT_APPLIED_FILE}" "${GPGSIGN}"
  RESULT=$?
fi

if [[ ${COMMITMODE} = true
   && ${PATCH_METHOD} != "gitam" ]]; then
  yetus_debug "Running git add -A"
  git add -A
fi

patch_reports

popd >/dev/null || exit 1

cleanup_and_exit ${RESULT}
