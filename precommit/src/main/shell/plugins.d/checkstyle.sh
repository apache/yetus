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

# SHELLDOC-IGNORE

add_test_type checkstyle

CHECKSTYLE_TIMER=0
CHECKSTYLE_GOAL_DEFAULT="checkstyle"
CHECKSTYLE_GOAL="${CHECKSTYLE_GOAL_DEFAULT}"
CHECKSTYLE_OPTIONS_DEFAULT="-Dcheckstyle.consoleOutput=true"
CHECKSTYLE_OPTIONS="${CHECKSTYLE_OPTIONS_DEFAULT}"

function checkstyle_filefilter
{
  local filename=$1

  if [[ ${BUILDTOOL} == maven
    || ${BUILDTOOL} == ant ]]; then
    if [[ ${filename} =~ \.java$ ]]; then
      add_test checkstyle
    fi
  fi

  if [[ ${BUILDTOOL} == gradle ]]; then
    if [[ ${filename} =~ \.java$
       || ${filename} =~ config/checkstyle/checkstyle.xml
       || ${filename} =~ config/checkstyle/suppressions.xml ]]; then
      add_test checkstyle
    fi
  fi
}

## @description  usage help for checkstyle
## @audience     private
## @stability    evolving
## @replaceable  no
function checkstyle_usage
{
  yetus_add_option "--checkstyle-goal=<goal>" "Checkstyle maven plugin goal to use, 'check' and 'checkstyle' supported. Defaults to '${CHECKSTYLE_GOAL_DEFAULT}'."
}

## @description  parse checkstyle args
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        arg
## @param        ..
function checkstyle_parse_args
{
  local i

  for i in "$@"; do
    case ${i} in
    --checkstyle-goal=*)
      delete_parameter "${i}"
      CHECKSTYLE_GOAL=${i#*=}
        case ${CHECKSTYLE_GOAL} in
        check)
            CHECKSTYLE_OPTIONS="-Dcheckstyle.consoleOutput=true -Dcheckstyle.failOnViolation=false"
        ;;
        checkstyle)
        ;;
        *)
            yetus_error "Warning: checkstyle goal ${CHECKSTYLE_GOAL} not supported. It may have unexpected behavior"
        ;;
        esac
    ;;
    esac
  done
}

## @description  initialize the checkstyle plug-in
## @audience     private
## @stability    evolving
## @replaceable  no
function checkstyle_initialize
{
  if declare -f maven_add_install >/dev/null 2>&1; then
    maven_add_install checkstyle
  fi
}

## @description  checkstyle plug-in specific difference calculator
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function checkstyle_calcdiffs
{
  declare orig=$1
  declare new=$2
  declare tmp=${PATCH_DIR}/pl.$$.${RANDOM}
  declare j

  # first, strip filenames:line:
  # this keeps column: in an attempt to increase
  # accuracy in case of multiple, repeated errors
  # since the column number shouldn't change
  # if the line of code hasn't been touched
  # remove the numbers from the error message for comparing
  # so if only the error message numbers change
  # we do not report new error
  # shellcheck disable=SC2016
  cut -f3- -d: "${orig}" | "${AWK}" -F'\1' '{ gsub("[0-9,]+", "", $2) ;print $1":"$2}' > "${tmp}.branch"
  # shellcheck disable=SC2016
  cut -f3- -d: "${new}" | "${AWK}" -F'\1' '{ gsub("[0-9,]+", "", $2) ;print $1":"$2}' > "${tmp}.patch"

  # compare the errors, generating a string of line
  # numbers. Sorry portability: GNU diff makes this too easy
  "${DIFF}" --unchanged-line-format="" \
     --old-line-format="" \
     --new-line-format="%dn " \
     "${tmp}.branch" \
     "${tmp}.patch" > "${tmp}.lined"

  # now, pull out those lines of the raw output
  # removing extra marker before the chekstyle error
  # message which was needed for calculations
  # shellcheck disable=SC2013
  for j in $(cat "${tmp}.lined"); do
    head -"${j}" "${new}" | tail -1 | tr -d $'\x01'
  done

  rm "${tmp}.branch" "${tmp}.patch" "${tmp}.lined" 2>/dev/null
}

## @description execute checkstyle
## @audience    private
## @stability   stable
## @replaceable no
function checkstyle_runner
{
  declare repostatus=$1
  declare tmp=${PATCH_DIR}/$$.${RANDOM}
  declare j
  declare i=0
  declare fn
  declare savestart=${TIMER}
  declare savestop
  declare output
  declare logfile
  declare logfilename
  declare modulesuffix
  declare cmd
  declare line
  declare newline
  declare logline
  declare text
  declare linenum
  declare codeline
  declare cmdresult
  declare -a filelist
  declare rol

  # first, let's clear out any previous run information
  modules_reset

  # loop through the modules we've been given
  #shellcheck disable=SC2153
  until [[ $i -eq ${#MODULE[@]} ]]; do

    # start the clock per module, setup some help vars, etc
    start_clock
    fn=$(module_file_fragment "${MODULE[${i}]}")
    modulesuffix=$(basename "${MODULE[${i}]}")
    output="${PATCH_DIR}/${repostatus}-checkstyle-${fn}.txt"
    logfile="${PATCH_DIR}/buildtool-${repostatus}-checkstyle-${fn}.txt"

    buildtool_cwd "${i}"

    #BUG - fix this

    case ${BUILDTOOL} in
      ant)
        cmd="${ANT}  \
          -Dcheckstyle.consoleOutput=true \
          ${MODULEEXTRAPARAM[${i}]//@@@MODULEFN@@@/${fn}} \
          ${ANT_ARGS[*]} checkstyle"
      ;;
      maven)
        cmd="${MAVEN} ${MAVEN_ARGS[*]} \
           checkstyle:${CHECKSTYLE_GOAL} \
          ${CHECKSTYLE_OPTIONS} \
          ${MODULEEXTRAPARAM[${i}]//@@@MODULEFN@@@/${fn}} -Ptest-patch"
      ;;
      gradle)
        cmd="${GRADLEW} ${GRADLEW_ARGS[*]} \
           checkstyleMain checkstyleTest \
          ${MODULEEXTRAPARAM[${i}]//@@@MODULEFN@@@/${fn}}"
      ;;
      *)
        UNSUPPORTED_TEST=true
        return 0
      ;;
    esac

    # we're going to execute it and pull out
    # anything that beings with a /.  that's
    # almost certainly checkstyle output.
    # checkstyle 6.14 or upper adds severity
    # to the beginning of line, so removing it

    #shellcheck disable=SC2086
    echo_and_redirect "${logfile}" ${cmd}
    cmdresult=$?

    case ${BUILDTOOL} in
      ant)
        "${SED}" -e 's,^\[ERROR\] ,,g' -e 's,^\[WARN\] ,,g' "${logfile}" \
          | "${GREP}" ^/ \
          | "${SED}" -e "s,${BASEDIR},.,g" \
          > "${tmp}"
        ;;
      maven)
        "${SED}" -e 's,^\[ERROR\] ,,g' -e 's,^\[WARN\] ,,g' "${logfile}" \
          | "${GREP}" ^/ \
          | "${SED}" -e "s,${BASEDIR},.,g" \
          > "${tmp}"
          ;;
      gradle)
         # find -path isn't quite everywhere yet...

          while read -r line; do
              if [[ ${line} =~ build/reports/checkstyle ]]; then
                filelist+=("${line}")
              fi
          done < <(find "${BASEDIR}" -name 'main.xml' -o -name 'test.xml')

          touch "${tmp}"

          if [[ ${#filelist[@]} -gt 0 ]]; then
            # convert xml to maven-like output
            while read -r line; do
              if [[ $line =~ ^\<file ]]; then
                fn=$(echo "$line" | "${SED}" -E 's,^.+name="([^"]+)".+$,\1,' | "${SED}" -e "s,${BASEDIR},.,g")
              elif [[ $line =~ ^\<error ]]; then
                if [[ $line =~ column ]]; then
                  newline=$(echo "$line" | "${SED}" -E 's,^.+line="([0-9]+)".*column="([0-9]+)".*severity="([a-z]+)".*message="([^"]+)".+$,__FN__:\1\:\2:\4,')
                else
                  newline=$(echo "$line" | "${SED}" -E 's,^.+line="([0-9]+)".*severity="([a-z]+)".*message="([^"]+)".+$,__FN__:\1:\3,')
                fi

                newline=$(unescape_html "${newline}")
                newline=$(echo "$newline" | "${SED}" -e "s,__FN__,$fn,")
                echo "$newline" >> "${tmp}"
              fi
            done < <(cat "${filelist[@]}")
          fi
          ;;
    esac

    if [[ "${modulesuffix}" == . ]]; then
      modulesuffix=root
    fi

    logfilename=$(basename "${logfile}")
    if [[ ${cmdresult} == 0 ]]; then
      module_status ${i} +1 "${logfilename}" "${BUILDMODEMSG} passed checkstyle in ${modulesuffix}"
    else
      module_status ${i} -1 "${logfilename}" "${BUILDMODEMSG} fails to run checkstyle in ${modulesuffix}"
      ((result = result + 1))
    fi

    # if we have some output, we need to do more work:
    if [[ -s ${tmp} && "${BUILDMODE}" = patch ]]; then

      # first, let's pull out all of the files that
      # we actually care about, esp since that run
      # above is likely from the entire source
      # this will grealy cut down how much work we
      # have to do later

      for j in "${CHANGED_FILES[@]}"; do
        "${GREP}" "${j}" "${tmp}" >> "${tmp}.1"
      done

      # now that we have just the files we care about,
      # let's unscrew it. You see...

      # checkstyle seems to do everything it possibly can
      # to make it hard to process, including inconsistent
      # output (sometimes it has columns, sometimes it doesn't!)
      # and giving very generic errors when context would be
      # helpful, esp when doing diffs.

      # in order to help calcdiff and the user out, we're
      # going to reprocess the output to include the code
      # line being flagged.  When calcdiff gets a hold of this
      # it will have the code to act as context to help
      # report the correct line

      # file:linenum:(column:)error    ====>
      # file:linenum:code(:column)\x01:error
      # \x01 will later used to identify the beginning
      # of the checkstyle error message
      pushd "${BASEDIR}" >/dev/null || return 1
      while read -r logline; do
        file=${logline%%:*}
        rol=${logline/#${file}:}
        linenum=${rol%%:*}
        text=${rol/#${linenum}:}
        codeline=$(head -n "+${linenum}" "${file}" | tail -1 )
        {
          echo -n "${file}:${linenum}:${codeline}"
          echo -ne '\x01'
          echo ":${text}"
        } >> "${output}"
      done < <(cat "${tmp}.1")

      popd >/dev/null || return 1
      # later on, calcdiff will turn this into code(:column):error
      # compare, and then put the file:line back onto it.
    else
      cp -p "${tmp}" "${output}"
    fi

    rm "${tmp}" "${tmp}.1" 2>/dev/null

    savestop=$(stop_clock)
    #shellcheck disable=SC2034
    MODULE_STATUS_TIMER[${i}]=${savestop}

    popd >/dev/null || return 1
    ((i=i+1))
  done

  TIMER=${savestart}

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

function checkstyle_postcompile
{
  declare repostatus=$1

  if [[ "${repostatus}" = branch ]]; then
    checkstyle_preapply
  else
    checkstyle_postapply
  fi
}

function checkstyle_preapply
{
  local result

  if ! verify_needed_test checkstyle; then
    return 0
  fi

  big_console_header "checkstyle: ${PATCH_BRANCH}"

  start_clock

  personality_modules_wrapper branch checkstyle
  checkstyle_runner branch
  result=$?
  modules_messages branch checkstyle true

  # keep track of how much as elapsed for us already
  CHECKSTYLE_TIMER=$(stop_clock)
  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}

function checkstyle_postapply
{
  declare result
  declare module
  declare mod
  declare fn
  declare i=0
  declare numbranch=0
  declare numpatch=0
  declare addpatch=0
  declare summarize=true
  declare tmpvar

  if ! verify_needed_test checkstyle; then
    return 0
  fi

  big_console_header "checkstyle: ${BUILDMODE}"

  start_clock

personality_modules_wrapper patch checkstyle
  checkstyle_runner patch
  result=$?

  if [[ ${UNSUPPORTED_TEST} = true ]]; then
    return 0
  fi

  # add our previous elapsed to our new timer
  # by setting the clock back
  offset_clock "${CHECKSTYLE_TIMER}"

  until [[ $i -eq ${#MODULE[@]} ]]; do
    if [[ ${MODULE_STATUS[${i}]} == -1 ]]; then
      ((result=result+1))
      ((i=i+1))
      continue
    fi
    module=${MODULE[$i]}
    fn=$(module_file_fragment "${module}")

    # if there is no comparison to be done,
    # we can speed this up tremendously
    if [[ "${BUILDMODE}" = full ]]; then
      touch  "${PATCH_DIR}/branch-checkstyle-${fn}.txt"
      cp -p "${PATCH_DIR}/patch-checkstyle-${fn}.txt" \
        "${PATCH_DIR}/results-checkstyle-${fn}.txt"
    else

      # call calcdiffs to allow overrides
      calcdiffs \
        "${PATCH_DIR}/branch-checkstyle-${fn}.txt" \
        "${PATCH_DIR}/patch-checkstyle-${fn}.txt" \
        checkstyle \
        > "${PATCH_DIR}/results-checkstyle-${fn}.txt"
    fi

    tmpvar=$(wc -l "${PATCH_DIR}/branch-checkstyle-${fn}.txt")
    numbranch=${tmpvar%% *}

    tmpvar=$(wc -l "${PATCH_DIR}/patch-checkstyle-${fn}.txt")
    numpatch=${tmpvar%% *}

    tmpvar=$(wc -l "${PATCH_DIR}/results-checkstyle-${fn}.txt")
    addpatch=${tmpvar%% *}


    ((fixedpatch=numbranch-numpatch+addpatch))

    statstring=$(generic_calcdiff_status "${numbranch}" "${numpatch}" "${addpatch}" )

    mod=${module}
    if [[ ${mod} = \. ]]; then
      mod=root
    fi

    if [[ ${addpatch} -gt 0 ]] ; then
      ((result = result + 1))
      module_status "${i}" -1 "results-checkstyle-${fn}.txt" "${mod}: ${BUILDMODEMSG} ${statstring}"
    elif [[ ${fixedpatch} -gt 0 ]]; then
      module_status "${i}" +1 "results-checkstyle-${fn}.txt" "${mod}: ${BUILDMODEMSG} ${statstring}"
      summarize=false
    fi
    ((i=i+1))
  done

  modules_messages patch checkstyle "${summarize}"

  if [[ ${result} != 0 ]]; then
    return 1
  fi
  return 0
}
