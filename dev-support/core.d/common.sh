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

## @description  Setup the default global variables
## @audience     public
## @stability    stable
## @replaceable  no
function common_defaults
{
  #shellcheck disable=SC2034
  BASEDIR=$(pwd)
  LOAD_SYSTEM_PLUGINS=true
  #shellcheck disable=SC2034
  JENKINS=false
  #shellcheck disable=SC2034
  OFFLINE=false
  OSTYPE=$(uname -s)
  #shellcheck disable=SC2034
  PATCH_BRANCH=""
  PATCH_BRANCH_DEFAULT="master"
  #shellcheck disable=SC2034
  PATCH_DRYRUNMODE=false
  PATCH_DIR=/tmp
  while [[ -e ${PATCH_DIR} ]]; do
    PATCH_DIR=/tmp/yetus-${RANDOM}.${RANDOM}
  done
  PATCH_METHOD=""
  PATCH_METHODS=("gitapply" "patchcmd")
  PATCH_LEVEL=0
  PROJECT_NAME=yetus
  RESULT=0
  USER_PLUGIN_DIR=""
  #shellcheck disable=SC2034
  YETUS_SHELL_SCRIPT_DEBUG=false

  # Solaris needs POSIX and GNU, not SVID
  case ${OSTYPE} in
    SunOS)
      AWK=${AWK:-/usr/xpg4/bin/awk}
      CURL=${CURL:-curl}
      DIFF=${DIFF:-/usr/gnu/bin/diff}
      FILE=${FILE:-file}
      GIT=${GIT:-git}
      GREP=${GREP:-/usr/xpg4/bin/grep}
      PATCH=${PATCH:-/usr/gnu/bin/patch}
      SED=${SED:-/usr/xpg4/bin/sed}
    ;;
    *)
      AWK=${AWK:-awk}
      CURL=${CURL:-curl}
      DIFF=${DIFF:-diff}
      FILE=${FILE:-file}
      GIT=${GIT:-git}
      GREP=${GREP:-grep}
      PATCH=${PATCH:-patch}
      SED=${SED:-sed}
    ;;
  esac
}

## @description  Interpret the common command line parameters used by test-patch,
## @description  smart-apply-patch, and the bug system plugins
## @audience     private
## @stability    stable
## @replaceable  no
## @params       $@
## @return       May exit on failure
function common_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --awk-cmd=*)
        AWK=${i#*=}
      ;;
      --basedir=*)
        #shellcheck disable=SC2034
        BASEDIR=${i#*=}
      ;;
      --branch=*)
        #shellcheck disable=SC2034
        PATCH_BRANCH=${i#*=}
      ;;
      --branch-default=*)
        #shellcheck disable=SC2034
        PATCH_BRANCH_DEFAULT=${i#*=}
      ;;
      --curl-cmd=*)
        CURL=${i#*=}
      ;;
      --debug)
        #shellcheck disable=SC2034
        YETUS_SHELL_SCRIPT_DEBUG=true
      ;;
      --diff-cmd=*)
        DIFF=${i#*=}
      ;;
      --file-cmd=*)
        FILE=${i#*=}
      ;;
      --git-cmd=*)
        GIT=${i#*=}
      ;;
      --grep-cmd=*)
        GREP=${i#*=}
      ;;
      --help|-help|-h|help|--h|--\?|-\?|\?)
        yetus_usage
        exit 0
      ;;
      --modulelist=*)
        USER_MODULE_LIST=${i#*=}
        USER_MODULE_LIST=${USER_MODULE_LIST//,/ }
        yetus_debug "Manually forcing modules ${USER_MODULE_LIST}"
      ;;
      --offline)
        #shellcheck disable=SC2034
        OFFLINE=true
      ;;
      --patch-cmd=*)
        PATCH=${i#*=}
      ;;
      --patch-dir=*)
        PATCH_DIR=${i#*=}
      ;;
      --plugins=*)
        USER_PLUGIN_DIR=${i#*=}
      ;;
      --project=*)
        PROJECT_NAME=${i#*=}
      ;;
      --skip-system-plugins)
        LOAD_SYSTEM_PLUGINS=false
      ;;
      --sed-cmd=*)
        SED=${i#*=}
      ;;
      *)
      ;;
    esac
  done
}

## @description  Print a message to stderr
## @audience     public
## @stability    stable
## @replaceable  no
## @param        string
function yetus_error
{
  echo "$*" 1>&2
}

## @description  Print a message to stderr if --debug is turned on
## @audience     public
## @stability    stable
## @replaceable  no
## @param        string
function yetus_debug
{
  if [[ -n "${YETUS_SHELL_SCRIPT_DEBUG}" ]]; then
    echo "[$(date) DEBUG]: $*" 1>&2
  fi
}

## @description  run the command, sending stdout and stderr to the given filename
## @audience     public
## @stability    stable
## @param        filename
## @param        command
## @param        [..]
## @replaceable  no
## @returns      $?
function yetus_run_and_redirect
{
  declare logfile=$1
  shift

  # to the log
  {
    date
    echo "cd $(pwd)"
    echo "${*}"
  } >> "${logfile}"
  # run the actual command
  "${@}" >> "${logfile}" 2>&1
}

## @description Given a possible patch file, guess if it's a patch file
## @description only using the more intense verify if we really need to
## @audience private
## @stability evolving
## @param path to patch file to test
## @return 0 we think it's a patch file
## @return 1 we think it's not a patch file
function guess_patch_file
{
  declare patch=$1
  declare fileOutput

  if [[ ! -f ${patch} ]]; then
    return 1
  fi

  yetus_debug "Trying to guess if ${patch} is a patch file."
  fileOutput=$("${FILE}" "${patch}")
  if [[ $fileOutput =~ \ diff\  ]]; then
    yetus_debug "file magic says it's a diff."
    return 0
  fi

  fileOutput=$(head -n 1 "${patch}" | "${GREP}" -E "^(From [a-z0-9]* Mon Sep 17 00:00:00 2001)|(diff .*)|(Index: .*)$")
  if [[ $? == 0 ]]; then
    yetus_debug "first line looks like a patch file."
    return 0
  fi

  patchfile_dryrun_driver "${patch}"
}

## @description  Given ${PATCH_OR_ISSUE}, determine what type of patch file is in use,
## @description  and do the necessary work to place it into ${PATCH_DIR}/patch.
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure, may exit
function locate_patch
{
  declare bugsys
  declare patchfile=""
  declare gotit=false

  yetus_debug "locate patch"

  # it's a declarely provided file
  if [[ -f ${PATCH_OR_ISSUE} ]]; then
    patchfile="${PATCH_OR_ISSUE}"
  else
    # run through the bug systems.  maybe they know?
    for bugsys in ${BUGSYSTEMS}; do
      if declare -f ${bugsys}_locate_patch >/dev/null 2>&1; then
        "${bugsys}_locate_patch" "${PATCH_OR_ISSUE}" "${PATCH_DIR}/patch"
        if [[ $? == 0 ]]; then
          gotit=true
        fi
      fi
    done

    # ok, none of the bug systems know. let's see how smart we are
    if [[ ${gotit} == false ]]; then
      generic_locate_patch "${PATCH_OR_ISSUE}" "${PATCH_DIR}/patch"
      if [[ $? != 0 ]]; then
        yetus_error "ERROR: Unsure how to process ${PATCH_OR_ISSUE}."
        cleanup_and_exit 1
      fi
    fi
  fi

  if [[ ! -f "${PATCH_DIR}/patch"
      && -f "${patchfile}" ]]; then
    cp "${patchfile}" "${PATCH_DIR}/patch"
    if [[ $? == 0 ]] ; then
      echo "Patch file ${patchfile} copied to ${PATCH_DIR}"
    else
      yetus_error "ERROR: Could not copy ${patchfile} to ${PATCH_DIR}"
      cleanup_and_exit 1
    fi
  fi
}

## @description  Let plugins also get a copy of the arguments
## @audience     private
## @stability    evolving
## @replaceable  no
function parse_args_plugins
{
  for plugin in ${PLUGINS} ${BUGSYSTEMS} ${TESTFORMATS} ${BUILDTOOLS}; do
    if declare -f ${plugin}_parse_args >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_parse_args"
      #shellcheck disable=SC2086
      ${plugin}_parse_args "$@"
      (( RESULT = RESULT + $? ))
    fi
  done

  BUGCOMMENTS=${BUGCOMMENTS:-${BUGSYSTEMS}}
  if [[ ! ${BUGCOMMENTS} =~ console ]]; then
    BUGCOMMENTS="${BUGCOMMENTS} console"
  fi

  BUGLINECOMMENTS=${BUGLINECOMMENTS:-${BUGCOMMENTS}}
}

## @description  Let plugins also get a copy of the arguments
## @audience     private
## @stability    evolving
## @replaceable  no
function plugins_initialize
{
  declare plugin

  for plugin in ${PLUGINS} ${BUGSYSTEMS} ${TESTFORMATS} ${BUILDTOOLS}; do
    if declare -f ${plugin}_initialize >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_initialize"
      #shellcheck disable=SC2086
      ${plugin}_initialize
      (( RESULT = RESULT + $? ))
    fi
  done
}

## @description  Register test-patch.d plugins
## @audience     public
## @stability    stable
## @replaceable  no
function add_plugin
{
  PLUGINS="${PLUGINS} $1"
}

## @description  Register test-patch.d bugsystems
## @audience     public
## @stability    stable
## @replaceable  no
function add_bugsystem
{
  BUGSYSTEMS="${BUGSYSTEMS} $1"
}

## @description  Register test-patch.d test output formats
## @audience     public
## @stability    stable
## @replaceable  no
function add_test_format
{
  TESTFORMATS="${TESTFORMATS} $1"
}

## @description  Register test-patch.d build tools
## @audience     public
## @stability    stable
## @replaceable  no
function add_build_tool
{
  BUILDTOOLS="${BUILDTOOLS} $1"
}

## @description  Import content from test-patch.d and optionally
## @description  from user provided plugin directory
## @audience     private
## @stability    evolving
## @replaceable  no
function importplugins
{
  declare i
  declare files=()

  if [[ ${LOAD_SYSTEM_PLUGINS} == "true" ]]; then
    if [[ -d "${BINDIR}/test-patch.d" ]]; then
      files=(${BINDIR}/test-patch.d/*.sh)
    fi
  fi

  if [[ -n "${USER_PLUGIN_DIR}" && -d "${USER_PLUGIN_DIR}" ]]; then
    yetus_debug "Loading user provided plugins from ${USER_PLUGIN_DIR}"
    files=("${files[@]}" ${USER_PLUGIN_DIR}/*.sh)
  fi

  for i in "${files[@]}"; do
    if [[ -f ${i} ]]; then
      yetus_debug "Importing ${i}"
      . "${i}"
    fi
  done

  if [[ -z ${PERSONALITY}
      && -f "${BINDIR}/personality/${PROJECT_NAME}.sh" ]]; then
    PERSONALITY="${BINDIR}/personality/${PROJECT_NAME}.sh"
  fi

  if [[ -n ${PERSONALITY} ]]; then
    if [[ ! -f ${PERSONALITY} ]]; then
      if [[ -f "${BINDIR}/personality/${PROJECT_NAME}.sh" ]]; then
        PERSONALITY="${BINDIR}/personality/${PROJECT_NAME}.sh"
      else
        yetus_debug "Can't find ${PERSONALITY} to import."
        return
      fi
    fi
    yetus_debug "Importing ${PERSONALITY}"
    . "${PERSONALITY}"
  fi
}

## @description  if patch-level zero, then verify we aren't
## @description  just adding files
## @audience     public
## @stability    stable
## @param        filename
## @param        command
## @param        [..]
## @replaceable  no
## @returns      $?
function patchfile_verify_zero
{
  declare logfile=$1
  shift
  declare dir
  declare changed_files1
  declare changed_files2
  declare $filename

  # don't return /dev/null
  # shellcheck disable=SC2016
  changed_files1=$(${AWK} 'function p(s){if(s!~"^/dev/null"){print s}}
    /^diff --git /   { p($3); p($4) }
    /^(\+\+\+|---) / { p($2) }' "${PATCH_DIR}/patch" | sort -u)

  # maybe we interpreted the patch wrong? check the log file
  # shellcheck disable=SC2016
  changed_files2=$(${GREP} -E '^[cC]heck' "${logfile}" \
    | ${AWK} '{print $3}' \
    | ${SED} -e 's,\.\.\.$,,g')

  for filename in ${changed_files1} ${changed_files2}; do

    # leading prefix = bad
    if [[ ${filename} =~ ^(a|b)/ ]]; then
      return 1
    fi

    # touching an existing file is proof enough
    # that pl=0 is good
    if [[ -f ${filename} ]]; then
      return 0
    fi

    dir=$(dirname "${filename}" 2>/dev/null)
    if [[ -n ${dir} && -d ${dir} ]]; then
      return 0
    fi
  done

  # ¯\_(ツ)_/¯ - no way for us to know, all new files with no prefix!
  yetus_error "WARNING: Patch only adds files; using patch level ${PATCH_LEVEL}"
  return 0
}

## @description git apply dryrun
## @replaceable  no
## @audience     private
## @stability    evolving
function gitapply_dryrun
{
  declare patchfile=$1
  declare prefixsize=${2:-0}

  while [[ ${prefixsize} -lt 4
    && -z ${PATCH_METHOD} ]]; do
    yetus_run_and_redirect "${PATCH_DIR}/patch-dryrun.log" \
       "${GIT}" apply --binary -v --check "-p${prefixsize}" "${patchfile}"
    if [[ $? == 0 ]]; then
      PATCH_LEVEL=${prefixsize}
      PATCH_METHOD=gitapply
      break
    fi
    ((prefixsize=prefixsize+1))
  done

  if [[ ${prefixsize} -eq 0 ]]; then
    patchfile_verify_zero "${PATCH_DIR}/patch-dryrun.log"
    if [[ $? != 0 ]]; then
      PATCH_METHOD=""
      PATCH_LEVEL=""
      gitapply_dryrun "${patchfile}" 1
    fi
  fi
}

## @description  patch patch dryrun
## @replaceable  no
## @audience     private
## @stability    evolving
function patchcmd_dryrun
{
  declare patchfile=$1
  declare prefixsize=${2:-0}

  while [[ ${prefixsize} -lt 4
    && -z ${PATCH_METHOD} ]]; do
    yetus_run_and_redirect "${PATCH_DIR}/patch-dryrun.log" \
      "${PATCH}" "-p${prefixsize}" -E --dry-run < "${patchfile}"
    if [[ $? == 0 ]]; then
      PATCH_LEVEL=${prefixsize}
      PATCH_METHOD=patchcmd
      break
    fi
    ((prefixsize=prefixsize+1))
  done

  if [[ ${prefixsize} -eq 0 ]]; then
    patchfile_verify_zero "${PATCH_DIR}/patch-dryrun.log"
    if [[ $? != 0 ]]; then
      PATCH_METHOD=""
      PATCH_LEVEL=""
      patchcmd_dryrun "${patchfile}" 1
    fi
  fi
}

## @description  driver for dryrun methods
## @replaceable  no
## @audience     private
## @stability    evolving
function patchfile_dryrun_driver
{
  declare patchfile=$1
  declare method

  for method in "${PATCH_METHODS[@]}"; do
    if declare -f ${method}_dryrun >/dev/null; then
      "${method}_dryrun" "${patchfile}"
    fi
    if [[ -n ${PATCH_METHOD} ]]; then
      break
    fi
  done

  if [[ -n ${PATCH_METHOD} ]]; then
    return 0
  fi
  return 1
}

## @description  git patch apply
## @replaceable  no
## @audience     private
## @stability    evolving
function gitapply_apply
{
  declare patchfile=$1

  echo "Applying the patch:"
  yetus_run_and_redirect "${PATCH_DIR}/apply-patch-git-apply.log" \
    "${GIT}" apply --binary -v --stat --apply "-p${PATCH_LEVEL}" "${patchfile}"
  ${GREP} -v "^Checking" "${PATCH_DIR}/apply-patch-git-apply.log"
}


## @description  patch patch apply
## @replaceable  no
## @audience     private
## @stability    evolving
function patchcmd_apply
{
  declare patchfile=$1

  echo "Applying the patch:"
  yetus_run_and_redirect "${PATCH_DIR}/apply-patch-patch-apply.log" \
    "${PATCH}" "-p${PATCH_LEVEL}" -E < "${patchfile}"
  cat "${PATCH_DIR}/apply-patch-patch-apply.log"
}

## @description  driver for patch apply methods
## @replaceable  no
## @audience     private
## @stability    evolving
function patchfile_apply_driver
{
  declare patchfile=$1

  if declare -f ${PATCH_METHOD}_apply >/dev/null; then
    "${PATCH_METHOD}_apply" "${patchfile}"
    if [[ $? -gt 0 ]]; then
     return 1
    fi
  else
    yetus_error "ERROR: Patching method ${PATCH_METHOD} does not have a way to apply patches!"
    return 1
  fi
  return 0
}
