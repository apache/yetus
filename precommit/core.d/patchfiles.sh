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

## @description Use curl to download the patch as a last resort
## @audience    private
## @stability   evolving
## @param       patchloc
## @param       output
## @return      0 got something
## @return      1 error
function generic_locate_patch
{
  declare input=$1
  declare output=$2

  if [[ "${OFFLINE}" == true ]]; then
    yetus_debug "generic_locate_patch: offline, skipping"
    return 1
  fi

  ${CURL} --silent -L \
          --output "${output}" \
         "${input}"
  if [[ $? != 0 ]]; then
    yetus_debug "generic_locate_patch: failed to download the patch."
    return 1
  fi
  return 0
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

  if [[ -z "${PATCH_OR_ISSUE}" ]]; then
    yetus_error "ERROR: No patch provided."
    cleanup_and_exit 1
  fi

  echo "Processing: ${PATCH_OR_ISSUE}"
  # it's a declarely provided file
  if [[ -f ${PATCH_OR_ISSUE} ]]; then
    patchfile="${PATCH_OR_ISSUE}"
    PATCH_SYSTEM=generic
    if [[ -f "${PATCH_DIR}/patch" ]]; then
      "${DIFF}" -q "${PATCH_OR_ISSUE}" "${PATCH_DIR}/patch" >/dev/null
      if [[ $? -eq 1 ]]; then
        rm "${PATCH_DIR}/patch"
      fi
    fi
  else
    # run through the bug systems.  maybe they know?
    for bugsys in ${BUGSYSTEMS}; do
      if declare -f ${bugsys}_locate_patch >/dev/null 2>&1; then
        "${bugsys}_locate_patch" "${PATCH_OR_ISSUE}" "${PATCH_DIR}/patch"
        if [[ $? == 0 ]]; then
          gotit=true
          PATCH_SYSTEM=${bugsys}
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
      PATCH_SYSTEM=generic
    fi
  fi

  yetus_debug "Determined patch system to be ${PATCH_SYSTEM}"

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

## @description  if patch-level zero, then verify we aren't
## @description  just adding files
## @audience     public
## @stability    stable
## @param        log filename
## @replaceable  no
## @return       $?
function patchfile_verify_zero
{
  declare logfile=$1
  shift
  declare dir
  declare changed_files1
  declare changed_files2
  declare filename

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
## @param        path to patch file to dryrun
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
## @param        path to patch file to dryrun
function patchcmd_dryrun
{
  declare patchfile=$1
  declare prefixsize=${2:-0}

  while [[ ${prefixsize} -lt 4
    && -z ${PATCH_METHOD} ]]; do
    # shellcheck disable=SC2153
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
## @param        path to patch file to dryrun
function patchfile_dryrun_driver
{
  declare patchfile=$1
  declare method

  #shellcheck disable=SC2153
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
## @param        path to patch file to apply
function gitapply_apply
{
  declare patchfile=$1
  declare extraopts

  if [[ "${COMMITMODE}" = true ]]; then
    extraopts="--whitespace=fix"
  fi

  echo "Applying the patch:"
  yetus_run_and_redirect "${PATCH_DIR}/apply-patch-git-apply.log" \
    "${GIT}" apply --binary ${extraopts} -v --stat --apply "-p${PATCH_LEVEL}" "${patchfile}"
  ${GREP} -v "^Checking" "${PATCH_DIR}/apply-patch-git-apply.log"
}

## @description  patch patch apply
## @replaceable  no
## @audience     private
## @stability    evolving
## @param        path to patch file to apply
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
## @param        path to patch file to apply
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
