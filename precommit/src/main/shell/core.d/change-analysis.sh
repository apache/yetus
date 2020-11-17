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


## @description  Locate the build file for a given directory
## @audience     private
## @stability    stable
## @replaceable  no
## @return       directory containing the buildfile. Nothing returned if not found.
## @param        buildfile
## @param        directory
function find_buildfile_dir
{
  local buildfile=$1
  local dir=$2

  yetus_debug "Find ${buildfile} dir for: ${dir}"

  while builtin true; do
    if [[ -f "${dir}/${buildfile}" ]];then
      echo "${dir}"
      yetus_debug "Found: ${dir}"
      return 0
    elif [[ ${dir} == "." || ${dir} == "/" ]]; then
      yetus_debug "ERROR: ${buildfile} is not found."
      return 1
    else
      dir=$(faster_dirname "${dir}")
    fi
  done
}

## @description  List of files that ${INPUT_APPLIED_FILE} modifies
## @audience     private
## @stability    stable
## @replaceable  no
## @return       None; sets ${CHANGED_FILES[@]}
function find_changed_files
{
  declare line

  BUILDMODE=${BUILDMODE:-patch}
  INPUT_APPLIED_FILE=${INPUT_APPLIED_FILE:-${PATCH_DIR}/patch}

  pushd "${BASEDIR}" >/dev/null || return 1

  case "${BUILDMODE}" in
    full)
      echo "Building a list of all files in the source tree"
      while IFS= read -r; do CHANGED_FILES+=("$REPLY"); done < <("${GIT}" ls-files)
    ;;
    patch)
      # get a list of all of the files that have been changed,
      # except for /dev/null (which would be present for new files).
      # Additionally, remove any a/ b/ patterns at the front of the patch filenames.
      # see also similar code in change-analysis
      # shellcheck disable=SC2016
      while read -r line; do
        if [[ -n "${line}" ]]; then
          CHANGED_FILES=("${CHANGED_FILES[@]}" "${line}")
        fi
      done < <(
        "${AWK}" 'function p(s){sub("^[ab]/","",s); if(s!~"^/dev/null"&&s!~"^[[:blank:]]*$"){print s}}
        /^diff --git /   { p($3); p($4) }
        /^(\+\+\+|---) / { p($2) }' "${INPUT_APPLIED_FILE}" | sort -u)
      ;;
    esac
  popd >/dev/null || return 1
}


## @description Determine directories with
## @description changed content. Should be used with
## @description static linters that don't care about
## @description the build system.
## @audience    private
## @stability   evolving
## @replaceable no
## @return      None; sets ${CHANGED_DIRS}
function find_changed_dirs
{
  declare f
  declare -a newarray
  declare dir

  CHANGED_DIRS=()
  for f in "${CHANGED_FILES[@]}"; do
    dir=$(dirname "./${f}")
    if [[ "${dir}" = . ]]; then
      CHANGED_DIRS=('.')
      continue
    fi
    yetus_add_array_element CHANGED_DIRS "${dir}"
  done

  if [[ "${#CHANGED_DIRS[@]}" -eq 1 ]]; then
    return
  fi

  echo "${#CHANGED_DIRS[@]}"

  newarray=()

  for f in "${CHANGED_DIRS[@]}"; do
    dir=${f%/*}
    found=false
    while [[ ${dir} != "." ]] && [[ ${found} = false ]]; do
      if yetus_array_contains "${dir}" "${newarray[@]}"; then
        found=true
        continue
      fi
      if yetus_array_contains "${dir}" "${CHANGED_DIRS[@]}"; then
        found=true
        continue
      fi
      dir=${dir%/*}
    done

    if [[ "${found}" == false ]]; then
      newarray+=("${f}")
    fi
  done

  CHANGED_DIRS=("${newarray[@]}")
}

## @description  Apply the EXCLUDE_PATHS to CHANGED_FILES
## @audience     private
## @stability    stable
## @replaceable  no
## @return       None; sets ${CHANGED_FILES[@]}
function exclude_paths_from_changed_files
{
  declare f
  declare p
  declare strip
  declare -a a

  # empty the existing list
  EXCLUDE_PATHS=()

  # if E_P_F has been defined, then it was found earlier
  if [[ -n "${EXCLUDE_PATHS_FILE}" ]]; then

    # if it still exists ( it may have gotten deleted post-patch!)
    # read it in
    if [[ -f "${EXCLUDE_PATHS_FILE}" ]]; then
      yetus_file_to_array EXCLUDE_PATHS "${EXCLUDE_PATHS_FILE}"
    else
      # it was deleted post-patch, so delete it
      unset EXCLUDE_PATHS_FILE
      return
    fi

 # User provided us with a name but it wasn't there.
 # let's see if it is now
 elif [[ -n "${EXCLUDE_PATHS_FILE_SAVEOFF}" ]]; then
    # try to absolute the file name
    if [[ -f "${EXCLUDE_PATHS_FILE_SAVEOFF}" ]]; then
      EXCLUDE_PATHS_FILE=$(yetus_abs "${EXCLUDE_PATHS_FILE_SAVEOFF}")
    elif [[ -f "${BASEDIR}/${EXCLUDE_PATHS_FILE_SAVEOFF}" ]]; then
      EXCLUDE_PATHS_FILE=$(yetus_abs "${BASEDIR}/${EEXCLUDE_PATHS_FILE_SAVEOFF}")
    fi

    # if it exists, process, otherwise just return because nothing
    # to do

    if [[ -f "${EXCLUDE_PATHS_FILE}" ]]; then
      yetus_file_to_array EXCLUDE_PATHS "${EXCLUDE_PATHS_FILE}"
    else
      unset EXCLUDE_PATHS_FILE
      return
    fi
  else
    return
  fi

  a=()
  for f in "${CHANGED_FILES[@]}"; do
    strip=false
    for p in "${EXCLUDE_PATHS[@]}"; do
      if [[  "${f}" =~ ${p} ]]; then
        strip=true
        echo "${f}" >> "${PATCH_DIR}/excluded.txt"
      fi
    done
    if [[ ${strip} = false ]]; then
      a+=("${f}")
    fi
  done

  CHANGED_FILES=("${a[@]}")
}

## @description Check for directories to skip during
## @description changed module calcuation
## @description requires $MODULE_SKIPDIRS to be set
## @audience    private
## @stability   stable
## @replaceable no
## @param       directory
## @return      0 for use
## @return      1 for skip
function module_skipdir
{
  local dir=${1}
  local i

  yetus_debug "Checking skipdirs for ${dir}"

  if [[ -z ${MODULE_SKIPDIRS} ]]; then
    yetus_debug "Skipping skipdirs"
    return 0
  fi

  while builtin true; do
    for i in ${MODULE_SKIPDIRS}; do
      if [[ ${dir} = "${i}" ]];then
        yetus_debug "Found a skip: ${dir}"
        return 1
      fi
    done
    if [[ ${dir} == "." || ${dir} == "/" ]]; then
      return 0
    else
      dir=$(faster_dirname "${dir}")
      yetus_debug "Trying to skip: ${dir}"
    fi
  done
}

## @description  Find the modules of the build that ${PATCH_DIR}/patch modifies
## @audience     private
## @stability    stable
## @replaceable  no
## @param        repostatus
## @return       None; sets ${CHANGED_MODULES[@]}
function find_changed_modules
{
  declare repostatus=$1
  declare i
  declare builddir
  declare module
  declare prev_builddir
  declare i=1
  declare dir
  declare dirt
  declare buildfile
  declare -a tmpmods
  declare retval

  if declare -f "${BUILDTOOL}_buildfile" >/dev/null; then
    buildfile=$("${BUILDTOOL}_buildfile")
    retval=$?
  else
    yetus_error "ERROR: build tool plugin is broken"
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  if [[ ${retval} != 0 ]]; then
    yetus_error "ERROR: Unsupported build tool."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  pushd "${BASEDIR}" >/dev/null || return 1

  #  Empty string indicates the build system wants to disable module detection
  if [[ -z ${buildfile} ]]; then
    CHANGED_MODULES=(".")
  else

    # Now find all the modules that were changed
    for i in "${CHANGED_FILES[@]}"; do

      # TODO: optimize this
      if [[ "${BUILDMODE}" = full && ! "${i}" =~ ${buildfile} ]]; then
        continue
      fi

      dirt=$(dirname "${i}")

      if ! module_skipdir "${dirt}"; then
        continue
      fi

      builddir=$(find_buildfile_dir "${buildfile}" "${dirt}")
      if [[ -z ${builddir} ]]; then
        yetus_error "ERROR: ${buildfile} is not found. Make sure the target is a ${BUILDTOOL}-based project."
        bugsystem_finalreport 1
        cleanup_and_exit 1
      fi
      CHANGED_MODULES+=("${builddir}")
    done
  fi

  CHANGED_MODULES+=("${USER_MODULE_LIST[@]}")

  for i in "${CHANGED_MODULES[@]}"; do
    if [[ -d "${i}" ]]; then
      tmpmods+=("${i}")
    fi
  done

  CHANGED_MODULES=("${tmpmods[@]}")

  yetus_sort_and_unique_array CHANGED_MODULES

  yetus_debug "Locate the union of ${CHANGED_MODULES[*]}"

  count=${#CHANGED_MODULES[@]}
  if [[ ${count} -lt 2 ]]; then
    yetus_debug "Only one entry, so keeping it ${CHANGED_MODULES[0]}"
    # shellcheck disable=SC2034
    CHANGED_UNION_MODULES="${CHANGED_MODULES[0]}"
  else
    i=1

    # BUG - fix me
    # shellcheck disable=SC2207
    while [[ ${i} -lt 100 ]]; do
      tmpmods=()
      for j in "${CHANGED_MODULES[@]}"; do
        tmpmods+=($(echo "${j}" | cut -f1-${i} -d/))
      done
      tmpmods=($(printf '%s\n' "${tmpmods[@]}" | sort -u))

      module=${tmpmods[0]}
      count=${#tmpmods[@]}
      if [[ ${count} -eq 1
        && -f ${module}/${buildfile} ]]; then
        prev_builddir=${module}
      elif [[ ${count} -gt 1 ]]; then
        builddir=${prev_builddir}
        break
      fi
      ((i=i+1))
    done

    if [[ -z ${builddir} ]]; then
      builddir="."
    fi

    yetus_debug "Finding union of ${builddir}"
    builddir=$(find_buildfile_dir "${buildfile}" "${builddir}" || true)

    #shellcheck disable=SC2034
    CHANGED_UNION_MODULES="${builddir}"
  fi

  # some build tools may want to change these and/or
  # make other changes based upon these results
  if declare -f "${BUILDTOOL}_reorder_modules" >/dev/null; then
    "${BUILDTOOL}_reorder_modules" "${repostatus}"
  fi
  popd >/dev/null || return 1
}
