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

# dummy functions
function add_vote_table
{
  true
}

function add_footer_table
{
  true
}

function big_console_header
{
  true
}

function add_test
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
  yetus_add_option "--list-plugins" "List all installed plug-ins and then exit"
  yetus_add_option "--modulelist=<list>" "Specify additional modules to test (comma delimited)"
  yetus_add_option "--offline" "Avoid connecting to the Internet"
  yetus_add_option "--patch-dir=<dir>" "The directory for working and output files (default '/tmp/yetus-(random))"
  yetus_add_option "--personality=<file>" "he personality file to load"
  yetus_add_option "--plugins=<list>" "Specify which plug-ins to add/delete (comma delimited; use 'all' for all found)"
  yetus_add_option "--project=<name>" "The short name for project currently using test-patch (default 'yetus')"
  yetus_add_option "--skip-system-plugins" "Do not load plugins from ${BINDIR}/test-patch.d"
  yetus_add_option "--user-plugins=<dir>" "A directory of user provided plugins. see test-patch.d for examples (default empty)"
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
  importplugins

  unset TESTFORMATS
  unset TESTTYPES
  unset BUILDTOOLS

  for plugin in ${BUGSYSTEMS}; do
    if declare -f ${plugin}_usage >/dev/null 2>&1; then
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
      --committer)
        COMMITMODE=true
      ;;
      --dry-run)
        PATCH_DRYRUNMODE=true
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
    mkdir -p "${PATCH_DIR}"
    if [[ $? != 0 ]] ; then
      yetus_error "ERROR: Unable to create ${PATCH_DIR}"
      cleanup_and_exit 1
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

  echo "Applying the patch:"
  yetus_run_and_redirect "${PATCH_DIR}/apply-patch-git-am.log" \
    "${GIT}" am --signoff --whitespace=fix "-p${PATCH_LEVEL}" "${patchfile}"
  ${GREP} -v "^Checking" "${PATCH_DIR}/apply-patch-git-am.log"
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

trap "cleanup_and_exit 1" HUP INT QUIT TERM

import_core

setup_defaults

parse_args "$@"

importplugins
yetus_debug "Removing BUILDTOOLS, TESTTYPES, and TESTFORMATS from installed plug-in list"
unset BUILDTOOLS
unset TESTTYPES
unset TESTFORMATS

parse_args_plugins "$@"

plugins_initialize

locate_patch

if [[ ${COMMITMODE} = true ]]; then
  PATCH_METHODS=("gitam" "${PATCH_METHODS[@]}")
fi

patchfile_dryrun_driver "${PATCH_DIR}/patch"
RESULT=$?

if [[ ${RESULT} -gt 0 ]]; then
  yetus_error "ERROR: Aborting! ${PATCH_OR_ISSUE} cannot be verified."
  cleanup_and_exit ${RESULT}
fi

if [[ ${PATCH_DRYRUNMODE} == false ]]; then
  patchfile_apply_driver "${PATCH_DIR}/patch"
  RESULT=$?
fi

if [[ ${COMMITMODE} = true
   && ${PATCH_METHOD} != "gitam" ]]; then
  yetus_debug "Running git add -A"
  git add -A
fi

cleanup_and_exit ${RESULT}
