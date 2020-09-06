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

#shellcheck disable=SC2034
INPUT_PATCH_FILE=""
#shellcheck disable=SC2034
INPUT_DIFF_FILE=""
#shellcheck disable=SC2034
INPUT_APPLIED_FILE=""
#shellcheck disable=SC2034
INPUT_APPLY_TYPE=""
PATCH_METHOD=""
PATCH_METHODS=("gitapply" "patchcmd")
PATCH_LEVEL=0
PATCH_HINT=""

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

  if ! ${CURL} --silent -L \
          --output "${output}" \
         "${input}"; then
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
  #shellcheck disable=SC2181
  if [[ $? == 0 ]]; then
    yetus_debug "first line looks like a patch file."
    return 0
  fi

  patchfile_dryrun_driver "${patch}"
}

## @description  Provide a hint on what tool should be used to process a patch file
## @description  Sets PATCH_HINT to provide the hint. Will not do anything if
## @description  PATCH_HINT or PATCH_METHOD is already set
## @audience     private
## @stability    evolving
## @replaceable  no
## @param path to patch file to test
function patch_file_hinter
{
  declare patch=$1

  if [[ -z "${patch}" ]]; then
    generate_stack
  fi

  if [[ -z "${PATCH_HINT}" ]] && [[ -z "${PATCH_METHOD}" ]]; then
    if head -n 1 "${patch}" | "${GREP}" -q -E "^From [a-z0-9]* Mon Sep 17 00:00:00 2001" &&
      "${GREP}" -q "^From: " "${patch}" &&
      "${GREP}" -q "^Subject: \[PATCH" "${patch}" &&
      "${GREP}" -q "^---" "${patch}"; then
      PATCH_HINT="git"
      return
    fi
  fi
}

## @description  Given ${PATCH_OR_ISSUE}, determine what type of patch file is in use,
## @description  and do the necessary work to place it into ${INPUT_PATCH_FILE}.
## @description  If the system support diff files as well, put the diff version in
## @description  ${INPUT_DIFF_FILE} so that any supported degraded modes work.
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

  INPUT_PATCH_FILE="${PATCH_DIR}/input.patch"
  INPUT_DIFF_FILE="${PATCH_DIR}/input.diff"

  echo "Processing: ${PATCH_OR_ISSUE}"
  # it's a declarely provided file
  if [[ -f ${PATCH_OR_ISSUE} ]]; then
    patchfile="${PATCH_OR_ISSUE}"
    PATCH_SYSTEM=generic
    if [[ -f "${INPUT_PATCH_FILE}" ]]; then
      if ! "${DIFF}" -q "${PATCH_OR_ISSUE}" "${INPUT_PATCH_FILE}" >/dev/null; then
        rm "${INPUT_PATCH_FILE}"
      fi
    fi
  else
    # run through the bug systems.  maybe they know?
    for bugsys in "${BUGSYSTEMS[@]}"; do
      if declare -f "${bugsys}_locate_patch" >/dev/null 2>&1; then
        if "${bugsys}_locate_patch" \
            "${PATCH_OR_ISSUE}" \
            "${INPUT_PATCH_FILE}" \
            "${INPUT_DIFF_FILE}"; then
          gotit=true
          PATCH_SYSTEM=${bugsys}
        fi
      fi
      # did the bug system actually make us change our mind?
      if [[ "${BUILDMODE}" == full ]]; then
        return 0
      fi
    done

    # ok, none of the bug systems know. let's see how smart we are
    if [[ ${gotit} == false ]]; then
      if ! generic_locate_patch "${PATCH_OR_ISSUE}" "${INPUT_PATCH_FILE}"; then
        yetus_error "ERROR: Unsure how to process ${PATCH_OR_ISSUE}."
        cleanup_and_exit 1
      fi
      PATCH_SYSTEM=generic
    fi
  fi

  yetus_debug "Determined patch system to be ${PATCH_SYSTEM}"

  if [[ ! -f "${INPUT_PATCH_FILE}"
      && -f "${patchfile}" ]]; then
    if cp "${patchfile}" "${INPUT_PATCH_FILE}"; then
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
  # see also similar code in change-analysis
  # shellcheck disable=SC2016
  changed_files1=$("${AWK}" 'function p(s){if(s!~"^/dev/null"&&s!~"^[[:blank:]]*$"){print s}}
    /^diff --git /   { p($3); p($4) }
    /^(\+\+\+|---) / { p($2) }' "${INPUT_PATCH_FILE}" | sort -u)

  # maybe we interpreted the patch wrong? check the log file
  # shellcheck disable=SC2016
  changed_files2=$("${GREP}" -E '^[cC]heck' "${logfile}" \
    | "${AWK}" '{print $3}' \
    | "${SED}" -e 's,\.\.\.$,,g')

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

  while [[ ${prefixsize} -lt 2
    && -z ${PATCH_METHOD} ]]; do
    if yetus_run_and_redirect "${PATCH_DIR}/input-dryrun.log" \
       "${GIT}" apply --binary -v --check "-p${prefixsize}" "${patchfile}"; then
      PATCH_LEVEL=${prefixsize}
      PATCH_METHOD=gitapply
      break
    fi
    ((prefixsize=prefixsize+1))
  done

  if [[ ${prefixsize} -eq 0 ]]; then
    if ! patchfile_verify_zero "${PATCH_DIR}/input-dryrun.log"; then
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

  while [[ ${prefixsize} -lt 2
    && -z ${PATCH_METHOD} ]]; do
    # shellcheck disable=SC2153
    if yetus_run_and_redirect "${PATCH_DIR}/input-dryrun.log" \
      "${PATCH}" "-p${prefixsize}" -E --dry-run < "${patchfile}"; then
      PATCH_LEVEL=${prefixsize}
      PATCH_METHOD=patchcmd
      break
    fi
    ((prefixsize=prefixsize+1))
  done

  if [[ ${prefixsize} -eq 0 ]]; then
    if ! patchfile_verify_zero "${PATCH_DIR}/input-dryrun.log"; then
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

  patch_file_hinter "${patchfile}"

  #shellcheck disable=SC2153
  for method in "${PATCH_METHODS[@]}"; do
    if [[ -n "${PATCH_HINT}" ]] &&
       [[ !  "${method}" =~ ${PATCH_HINT} ]]; then
        continue
    fi
    if declare -f "${method}_dryrun" >/dev/null; then
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

## @description  dryrun both PATCH and DIFF and determine which one to use
## @replaceable  no
## @audience     private
## @stability    evolving
function dryrun_both_files
{
  # always prefer the patch file since git format patch files support a lot more
  if [[ -f "${INPUT_PATCH_FILE}" ]] && patchfile_dryrun_driver "${INPUT_PATCH_FILE}"; then
    INPUT_APPLY_TYPE="patch"
    INPUT_APPLIED_FILE="${INPUT_PATCH_FILE}"
    return 0
  elif [[ -f "${INPUT_DIFF_FILE}" ]] && patchfile_dryrun_driver "${INPUT_DIFF_FILE}"; then
    INPUT_APPLY_TYPE="diff"
    INPUT_APPLIED_FILE="${INPUT_DIFF_FILE}"
    return 0
  else
    return 1
  fi
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

  echo "Applying the changes:"
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
  declare gpg=$2

  if declare -f "${PATCH_METHOD}_apply" >/dev/null; then
    if ! "${PATCH_METHOD}_apply" "${patchfile}" "${gpg}"; then
     return 1
    fi
  else
    yetus_error "ERROR: Patching method ${PATCH_METHOD} does not have a way to apply patches!"
    return 1
  fi
  return 0
}
