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

# we need to declare this globally as an array, which can only
# be done outside of a function
declare -a YETUS_OPTION_USAGE

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
  if [[ "${YETUS_SHELL_SCRIPT_DEBUG}" = true ]]; then
    echo "[$(date) DEBUG]: $*" 1>&2
  fi
}

## @description  Given variable $1 delete $2 from it
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_delete_entry
{
  if [[ ${!1} =~ \ ${2}\  ]] ; then
    yetus_debug "Removing ${2} from ${1}"
    eval "${1}"=\""${!1// ${2} }"\"
  fi
}

## @description  Given variable $1 add $2 to it
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_add_entry
{
  if [[ ! ${!1} =~ \ ${2}\  ]] ; then
    yetus_debug "Adding ${2} to ${1}"
    #shellcheck disable=SC2140
    eval "${1}"=\""${!1} ${2} "\"
  fi
}

## @description  Given variable $1 determine if $2 is in it
## @audience     public
## @stability    stable
## @replaceable  no
## @return       0 = yes, 1 = no
function yetus_verify_entry
{
  [[ ${!1} =~ \ ${2}\  ]]
}

## @description  run the command, sending stdout and stderr to the given filename
## @audience     public
## @stability    stable
## @param        filename
## @param        command
## @param        [..]
## @replaceable  no
## @return       $?
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

## @description  Given a filename or dir, return the absolute version of it
## @audience     public
## @stability    stable
## @param        fsobj
## @replaceable  no
## @return       0 success
## @return       1 failure
## @return       stdout abspath
function yetus_abs
{
  declare obj=$1
  declare dir
  declare fn

  if [[ ! -e ${obj} ]]; then
    return 1
  elif [[ -d ${obj} ]]; then
    dir=${obj}
  else
    dir=$(dirname -- "${obj}")
    fn=$(basename -- "${obj}")
    fn="/${fn}"
  fi

  dir=$(cd -P -- "${dir}" >/dev/null 2>/dev/null && pwd -P)
  if [[ $? = 0 ]]; then
    echo "${dir}${fn}"
    return 0
  fi
  return 1
}

## @description  Add a header to the usage output
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        header
function yetus_add_header
{
  declare text=$1

  #shellcheck disable=SC2034
  YETUS_USAGE_HEADER="${text}"
}

## @description  Add an option to the usage output
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        subcommand
## @param        subcommanddesc
function yetus_add_option
{
  declare option=$1
  declare text=$2

  YETUS_OPTION_USAGE[${YETUS_OPTION_USAGE_COUNTER}]="${option}@${text}"
  ((YETUS_OPTION_USAGE_COUNTER=YETUS_OPTION_USAGE_COUNTER+1))
}

## @description  Reset the usage information to blank
## @audience     private
## @stability    evolving
## @replaceable  no
function yetus_reset_usage
{
  # shellcheck disable=SC2034
  YETUS_OPTION_USAGE=()
  YETUS_OPTION_USAGE_COUNTER=0
}

## @description  Print a screen-size aware two-column output
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        array
function yetus_generic_columnprinter
{
  declare -a input=("$@")
  declare -i i=0
  declare -i counter=0
  declare line
  declare text
  declare option
  declare giventext
  declare -i maxoptsize
  declare -i foldsize
  declare -a tmpa
  declare numcols

  if [[ -n "${COLUMNS}" ]]; then
    numcols=${COLUMNS}
  else
    numcols=$(tput cols) 2>/dev/null
  fi

  if [[ -z "${numcols}"
     || ! "${numcols}" =~ ^[0-9]+$ ]]; then
    numcols=75
  else
    ((numcols=numcols-5))
  fi

  while read -r line; do
    tmpa[${counter}]=${line}
    ((counter=counter+1))
    option=$(echo "${line}" | cut -f1 -d'@')
    if [[ ${#option} -gt ${maxoptsize} ]]; then
      maxoptsize=${#option}
    fi
  done < <(for text in "${input[@]}"; do
    echo "${text}"
  done | sort)

  i=0
  ((foldsize=numcols-maxoptsize))

  until [[ $i -eq ${#tmpa[@]} ]]; do
    option=$(echo "${tmpa[$i]}" | cut -f1 -d'@')
    giventext=$(echo "${tmpa[$i]}" | cut -f2 -d'@')

    while read -r line; do
      printf "%-${maxoptsize}s   %-s\n" "${option}" "${line}"
      option=" "
    done < <(echo "${giventext}"| fold -s -w ${foldsize})
    ((i=i+1))
  done
}

## @description  Convert a comma-delimited string to an array
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        arrayname
## @param        string
function yetus_comma_to_array
{
  declare var=$1
  declare string=$2

  oldifs="${IFS}"
  IFS=',' read -r -a "${var}" <<< "${string}"
  IFS="${oldifs}"
}

## @description  Check if an array has a given value
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        element
## @param        array
## @returns      0 = yes
## @returns      1 = no
function yetus_array_contains
{
  declare element=$1
  shift
  declare val

  if [[ "$#" -eq 0 ]]; then
    return 1
  fi

  for val in "${@}"; do
    if [[ "${val}" == "${element}" ]]; then
      return 0
    fi
  done
  return 1
}

## @description  Add the element if it is not
## @description  present in the given array
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        arrayname
## @param        element
function yetus_add_array_element
{
  declare arrname=$1
  declare add=$2

  declare arrref="${arrname}[@]"
  declare array=("${!arrref}")

  if ! yetus_array_contains "${add}" "${array[@]}"; then
    # shellcheck disable=SC1083,SC2086
    eval "${arrname}"=\(\"\${array[@]}\" \"${add}\" \)
    yetus_debug "$1 accepted $2"
  else
    yetus_debug "$1 declined $2"
  fi
}

## @description  Sort an array by its elements
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        arrayvar
function yetus_sort_array
{
  declare arrname=$1
  declare arrref="${arrname}[@]"
  declare array=("${!arrref}")

  declare globstatus
  declare oifs
  declare -a sa

  globstatus=$(set -o | grep noglob | awk '{print $NF}')

  if [[ -n ${IFS} ]]; then
    oifs=${IFS}
  fi
  set -f
  # shellcheck disable=SC2034
  IFS=$'\n' sa=($(sort <<<"${array[*]}"))
  # shellcheck disable=SC1083
  eval "${arrname}"=\(\"\${sa[@]}\"\)

  if [[ -n "${oifs}" ]]; then
    IFS=${oifs}
  else
    unset IFS
  fi

  if [[ "${globstatus}" = off ]]; then
    set +f
  fi
}
