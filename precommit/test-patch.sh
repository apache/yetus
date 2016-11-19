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
BINNAME=${this##*/}
BINNAME=${BINNAME%.sh}
STARTINGDIR=$(pwd)
USER_PARAMS=("$@")
GLOBALTIMER=$(date +"%s")
#shellcheck disable=SC2034
QATESTMODE=false

# global arrays
declare -a CHANGED_FILES
declare -a CHANGED_MODULES
declare -a TP_HEADER
declare -a TP_VOTE_TABLE
declare -a TP_TEST_TABLE
declare -a TP_FOOTER_TABLE
declare -a MODULE
declare -a MODULE_BACKUP_STATUS
declare -a MODULE_BACKUP_STATUS_TIMER
declare -a MODULE_BACKUP_STATUS_MSG
declare -a MODULE_BACKUP_STATUS_LOG
declare -a MODULE_BACKUP_COMPILE_LOG
declare -a MODULE_STATUS
declare -a MODULE_STATUS_TIMER
declare -a MODULE_STATUS_MSG
declare -a MODULE_STATUS_LOG
declare -a MODULE_COMPILE_LOG
declare -a USER_MODULE_LIST

TP_HEADER_COUNTER=0
TP_VOTE_COUNTER=0
TP_TEST_COUNTER=0
TP_FOOTER_COUNTER=0

## @description  Setup the default global variables
## @audience     public
## @stability    stable
## @replaceable  no
function setup_defaults
{
  declare version="in-progress"

  common_defaults

  if [[ -f "${BINDIR}/../VERSION" ]]; then
    version=$(cat "${BINDIR}/../VERSION")
  elif [[ -f "${BINDIR}/VERSION" ]]; then
    version=$(cat "${BINDIR}/VERSION")
  fi
  if [[ ${version} =~ SNAPSHOT$ ]]; then
    version="in-progress"
  fi

  PATCH_NAMING_RULE="https://yetus.apache.org/documentation/${version}/precommit-patchnames"
  INSTANCE=${RANDOM}
  RELOCATE_PATCH_DIR=false

  ALLOWSUMMARIES=true

  BUILD_NATIVE=${BUILD_NATIVE:-true}

  BUILD_URL_ARTIFACTS=artifact/patchprocess
  BUILD_URL_CONSOLE=console
  BUILDTOOLCWD=module

  # shellcheck disable=SC2034
  CHANGED_UNION_MODULES=""
  REEXECED=false
  RESETREPO=false
  BUILDMODE=patch
  # shellcheck disable=SC2034
  BUILDMODEMSG="The patch"
  ISSUE=""
  TIMER=$(date +"%s")
  JVM_REQUIRED=true
  yetus_add_entry JDK_TEST_LIST compile
  yetus_add_entry JDK_TEST_LIST unit
}

## @description  Convert the given module name to a file fragment
## @audience     public
## @stability    stable
## @replaceable  no
## @param        module
function module_file_fragment
{
  local mod=$1
  if [[ ${mod} = \. ]]; then
    echo root
  else
    echo "$1" | tr '/' '_' | tr '\\' '_'
  fi
}

## @description  Convert time in seconds to m + s
## @audience     public
## @stability    stable
## @replaceable  no
## @param        seconds
function clock_display
{
  local -r elapsed=$1

  if [[ ${elapsed} -lt 0 ]]; then
    echo "N/A"
  else
    printf  "%3sm %02ss" $((elapsed/60)) $((elapsed%60))
  fi
}

## @description  Activate the local timer
## @audience     public
## @stability    stable
## @replaceable  no
function start_clock
{
  yetus_debug "Start clock"
  TIMER=$(date +"%s")
}

## @description  Print the elapsed time in seconds since the start of the local timer
## @audience     public
## @stability    stable
## @replaceable  no
function stop_clock
{
  local -r stoptime=$(date +"%s")
  local -r elapsed=$((stoptime-TIMER))
  yetus_debug "Stop clock"

  echo ${elapsed}
}

## @description  Print the elapsed time in seconds since the start of the global timer
## @audience     private
## @stability    stable
## @replaceable  no
function stop_global_clock
{
  local -r stoptime=$(date +"%s")
  local -r elapsed=$((stoptime-GLOBALTIMER))
  yetus_debug "Stop global clock"

  echo ${elapsed}
}

## @description  Add time to the local timer
## @audience     public
## @stability    stable
## @replaceable  no
## @param        seconds
function offset_clock
{
  declare off=$1

  yetus_debug "offset clock by ${off}"

  if [[ -n ${off} ]]; then
    ((TIMER=TIMER-off))
  else
    yetus_error "ASSERT: no offset passed to offset_clock: ${index}"
    generate_stack
  fi
}

## @description generate a stack trace when in debug mode
## @audience     public
## @stability    stable
## @replaceable  no
## @return       exits
function generate_stack
{
  declare frame

  if [[ "${YETUS_SHELL_SCRIPT_DEBUG}" = true ]]; then
    while caller "${frame}"; do
      ((frame++));
    done
  fi
  exit 1
}

## @description  Add to the header of the display
## @audience     public
## @stability    stable
## @replaceable  no
## @param        string
function add_header_line
{
  # shellcheck disable=SC2034
  TP_HEADER[${TP_HEADER_COUNTER}]="$*"
  ((TP_HEADER_COUNTER=TP_HEADER_COUNTER+1 ))
}

## @description  Add to the output table. If the first parameter is a number
## @description  that is the vote for that column and calculates the elapsed time
## @description  based upon the last start_clock().  The second parameter is the reporting
## @description  subsystem (or test) that is providing the vote.  The second parameter
## @description  is always required.  The third parameter is any extra verbage that goes
## @description  with that subsystem.
## @audience     public
## @stability    stable
## @replaceable  no
## @param        +1/0/-1
## @param        subsystem
## @param        string
function add_vote_table
{
  declare value=$1
  declare subsystem=$2
  shift 2

  # apparently shellcheck doesn't know about declare -r
  #shellcheck disable=SC2155
  declare -r elapsed=$(stop_clock)
  declare filt

  yetus_debug "add_vote_table ${value} ${subsystem} ${elapsed} ${*}"

  if [[ ${value} == "1" ]]; then
    value="+1"
  fi

  for filt in "${VOTE_FILTER[@]}"; do
    if [[ "${subsystem}" == "${filt}" && "${value}" == -1 ]]; then
      value=-0
    fi
  done

  # shellcheck disable=SC2034
  TP_VOTE_TABLE[${TP_VOTE_COUNTER}]="| ${value} | ${subsystem} | ${elapsed} | $* |"
  ((TP_VOTE_COUNTER=TP_VOTE_COUNTER+1))

  if [[ "${value}" = -1 ]]; then
    ((RESULT = RESULT + 1))
  fi
}

## @description  Report the JVM version of the given directory
## @stability    stable
## @audience     private
## @replaceable  yes
## @param        directory
## @return       version
function report_jvm_version
{
  #shellcheck disable=SC2016
  "${1}/bin/java" -version 2>&1 | head -1 | ${AWK} '{print $NF}' | tr -d \"
}

## @description  Verify if a given test is multijdk
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test
## @return       0 = yes
## @return       1 = no
function verify_multijdk_test
{
  local i=$1

  if [[ "${JDK_DIR_LIST}" == "${JAVA_HOME}" ]]; then
    yetus_debug "MultiJDK not configured."
    return 1
  fi

  if [[ ${JDK_TEST_LIST} =~ $i ]]; then
    yetus_debug "${i} is in ${JDK_TEST_LIST} and MultiJDK configured."
    return 0
  fi
  return 1
}

## @description  Put the opening environment information at the bottom
## @description  of the footer table
## @stability    stable
## @audience     private
## @replaceable  yes
function prepopulate_footer
{
  # shellcheck disable=SC2155
  declare -r unamea=$(uname -a)

  add_footer_table "uname" "${unamea}"
  add_footer_table "Build tool" "${BUILDTOOL}"

  if [[ -n ${REEXECPERSONALITY} ]]; then
    add_footer_table "Personality" "${REEXECPERSONALITY}"
  elif [[ -n ${PERSONALITY} ]]; then
    add_footer_table "Personality" "${PERSONALITY}"
  fi

  gitrev=$(${GIT} rev-parse --verify --short HEAD)

  add_footer_table "git revision" "${PATCH_BRANCH} / ${gitrev}"
}

## @description  Last minute entries on the footer table
## @audience     private
## @stability    stable
## @replaceable  no
function finish_footer_table
{
  add_footer_table "modules" "C: ${CHANGED_MODULES[*]} U: ${CHANGED_UNION_MODULES}"
}

## @description  Put the final elapsed time at the bottom of the table.
## @audience     private
## @stability    stable
## @replaceable  no
function finish_vote_table
{

  local -r elapsed=$(stop_global_clock)
  local calctime

  calctime=$(clock_display "${elapsed}")

  echo ""
  echo "Total Elapsed time: ${calctime}"
  echo ""

  # shellcheck disable=SC2034
  TP_VOTE_TABLE[${TP_VOTE_COUNTER}]="| | | ${elapsed} | |"
  ((TP_VOTE_COUNTER=TP_VOTE_COUNTER+1 ))
}

## @description  Add to the footer of the display. @@BASE@@ will get replaced with the
## @description  correct location for the local filesystem in dev mode or the URL for
## @description  Jenkins mode.
## @audience     public
## @stability    stable
## @replaceable  no
## @param        subsystem
## @param        string
function add_footer_table
{
  local subsystem=$1
  shift 1

  # shellcheck disable=SC2034
  TP_FOOTER_TABLE[${TP_FOOTER_COUNTER}]="| ${subsystem} | $* |"
  ((TP_FOOTER_COUNTER=TP_FOOTER_COUNTER+1 ))
}

## @description  Special table just for unit test failures
## @audience     public
## @stability    stable
## @replaceable  no
## @param        failurereason
## @param        testlist
function add_test_table
{
  local failure=$1
  shift 1

  # shellcheck disable=SC2034
  TP_TEST_TABLE[${TP_TEST_COUNTER}]="| ${failure} | $* |"
  ((TP_TEST_COUNTER=TP_TEST_COUNTER+1 ))
}

## @description  Large display for the user console
## @audience     public
## @stability    stable
## @replaceable  no
## @param        string
## @return       large chunk of text
function big_console_header
{
  local text="$*"
  local spacing=$(( (75+${#text}) /2 ))
  printf "\n\n"
  echo "============================================================================"
  echo "============================================================================"
  printf "%*s\n"  ${spacing} "${text}"
  echo "============================================================================"
  echo "============================================================================"
  printf "\n\n"
}

## @description  Find the largest size of a column of an array
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       size
function findlargest
{
  local column=$1
  shift
  local a=("$@")
  local sizeofa=${#a[@]}
  local i=0
  local string
  local maxlen=0

  until [[ ${i} -eq ${sizeofa} ]]; do
    # shellcheck disable=SC2086
    string=$( echo ${a[$i]} | cut -f$((column + 1)) -d\| )
    if [[ ${#string} -gt ${maxlen} ]]; then
      maxlen=${#string}
    fi
    i=$((i+1))
  done
  echo "${maxlen}"
}

## @description Write the contents of a file to all of the bug systems
## @description (so content should avoid special formatting)
## @param     filename
## @stability stable
## @audience  public
function write_comment
{
  local -r commentfile=${1}
  declare bug

  for bug in ${BUGCOMMENTS}; do
    if declare -f ${bug}_write_comment >/dev/null; then
       "${bug}_write_comment" "${commentfile}"
    fi
  done
}

## @description Verify that the patch directory is still in working order
## @description since bad actors on some systems wipe it out. If not,
## @description recreate it and then exit
## @audience    private
## @stability   evolving
## @replaceable yes
## @return      may exit on failure
function verify_patchdir_still_exists
{
  local -r commentfile=/tmp/testpatch.$$.${RANDOM}
  local extra=""

  if [[ ! -d ${PATCH_DIR} ]]; then
    rm "${commentfile}" 2>/dev/null

    echo "(!) The patch artifact directory has been removed! " > "${commentfile}"
    echo "This is a fatal error for test-patch.sh.  Aborting. " >> "${commentfile}"
    echo
    cat ${commentfile}
    echo
    if [[ ${JENKINS} == true ]]; then
      if [[ -n ${NODE_NAME} ]]; then
        extra=" (Jenkins node ${NODE_NAME})"
      fi
      echo "Jenkins${extra} information at ${BUILD_URL}${BUILD_URL_CONSOLE} may provide some hints. " >> "${commentfile}"

      write_comment ${commentfile}
    fi

    rm "${commentfile}"
    cleanup_and_exit "${RESULT}"
  fi
}

## @description generate a list of all files and line numbers in $GITDIFFLINES that
## @description that were added/changed in the source repo.  $GITDIFFCONTENT
## @description is same file, but also includes the content of those lines
## @audience    private
## @stability   stable
## @replaceable no
function compute_gitdiff
{
  local file
  local line
  local startline
  local counter
  local numlines
  local actual
  local content
  local outfile="${PATCH_DIR}/computegitdiff.${RANDOM}"

  pushd "${BASEDIR}" >/dev/null
  ${GIT} add --all --intent-to-add
  while read -r line; do
    if [[ ${line} =~ ^\+\+\+ ]]; then
      file="./"$(echo "${line}" | cut -f2- -d/)
      continue
    elif [[ ${line} =~ ^@@ ]]; then
      startline=$(echo "${line}" | cut -f3 -d' ' | cut -f1 -d, | tr -d + )
      numlines=$(echo "${line}" | cut -f3 -d' ' | cut -s -f2 -d, )
      # if this is empty, then just this line
      # if it is 0, then no lines were added and this part of the patch
      # is strictly a delete
      if [[ ${numlines} == 0 ]]; then
        continue
      elif [[ -z ${numlines} ]]; then
        numlines=1
      fi
      counter=0
      # it isn't obvious, but on MOST platforms under MOST use cases,
      # this is faster than using sed, and definitely faster than using
      # awk.
      # http://unix.stackexchange.com/questions/47407/cat-line-x-to-line-y-on-a-huge-file
      # has a good discussion w/benchmarks
      #
      # note that if tail is still sending data through the pipe, but head gets enough
      # to do what was requested, head will exit, leaving tail with a broken pipe.
      # we're going to send stderr to /dev/null and ignore the error since head's
      # output is really what we're looking for
      tail -n "+${startline}" "${file}" 2>/dev/null | head -n ${numlines} > "${outfile}"
      oldifs=${IFS}
      IFS=''
      while read -r content; do
          ((actual=counter+startline))
          echo "${file}:${actual}:" >> "${GITDIFFLINES}"
          printf "%s:%s:%s\n" "${file}" "${actual}" "${content}" >> "${GITDIFFCONTENT}"
          ((counter=counter+1))
      done < "${outfile}"
      rm "${outfile}"
      IFS=${oldifs}
    fi
  done < <("${GIT}" diff --unified=0 --no-color)

  if [[ ! -f "${GITDIFFLINES}" ]]; then
    touch "${GITDIFFLINES}"
  fi

  if [[ ! -f "${GITDIFFCONTENT}" ]]; then
    touch "${GITDIFFCONTENT}"
  fi

  if [[ -s "${GITDIFFLINES}" ]]; then
    compute_unidiff
  else
    touch "${GITUNIDIFFLINES}"
  fi

  popd >/dev/null
}

## @description generate an index of unified diff lines vs. modified/added lines
## @description ${GITDIFFLINES} must exist.
## @audience    private
## @stability   stable
## @replaceable no
function compute_unidiff
{
  declare fn
  declare filen
  declare tmpfile="${PATCH_DIR}/tmp.$$.${RANDOM}"

  # now that we know what lines are where, we can deal
  # with github's pain-in-the-butt API. It requires
  # that the client provides the line number of the
  # unified diff on a per file basis.

  # First, build a per-file unified diff, pulling
  # out the 'extra' lines, grabbing the adds with
  # the line number in the diff file along the way,
  # finally rewriting the line so that it is in
  # './filename:diff line:content' format

  for fn in "${CHANGED_FILES[@]}"; do
    filen=${fn##./}

    if [[ -f "${filen}" ]]; then
      ${GIT} diff "${filen}" \
        | tail -n +6 \
        | ${GREP} -n '^+' \
        | ${GREP} -vE '^[0-9]*:\+\+\+' \
        | ${SED} -e 's,^\([0-9]*:\)\+,\1,g' \
          -e "s,^,./${filen}:,g" \
              >>  "${tmpfile}"
    fi
  done

  # at this point, tmpfile should be in the same format
  # as gitdiffcontent, just with different line numbers.
  # let's do a merge (using gitdifflines because it's easier)

  # ./filename:real number:diff number
  # shellcheck disable=SC2016
  paste -d: "${GITDIFFLINES}" "${tmpfile}" \
    | ${AWK} -F: '{print $1":"$2":"$5":"$6}' \
    >> "${GITUNIDIFFLINES}"

  rm "${tmpfile}"
}

## @description  Print the command to be executing to the screen. Then
## @description  run the command, sending stdout and stderr to the given filename
## @description  This will also ensure that any directories in ${BASEDIR} have
## @description  the exec bit set as a pre-exec step.
## @audience     public
## @stability    stable
## @param        filename
## @param        command
## @param        [..]
## @replaceable  no
## @return       $?
function echo_and_redirect
{
  local logfile=$1
  shift

  verify_patchdir_still_exists

  find "${BASEDIR}" -type d -exec chmod +x {} \;
  # to the screen
  echo "cd $(pwd)"
  echo "${*} > ${logfile} 2>&1"
  yetus_run_and_redirect "${logfile}" "${@}"
}

## @description is a given directory relative to BASEDIR?
## @audience    public
## @stability   stable
## @replaceable yes
## @param       path
## @return      1 - no, path
## @return      0 - yes, path - BASEDIR
function relative_dir
{
  local p=${1#${BASEDIR}}

  if [[ ${#p} -eq ${#1} ]]; then
    echo "${p}"
    return 1
  fi
  p=${p#/}
  echo "${p}"
  return 0
}

## @description  Print the usage information
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_usage
{
  declare bugsys
  declare jdktlist

  importplugins

  # shellcheck disable=SC2116,SC2086
  bugsys=$(echo ${BUGSYSTEMS})
  bugsys=${bugsys// /,}

  # shellcheck disable=SC2116,SC2086
  jdktlist=$(echo ${JDK_TEST_LIST})
  jdktlist=${jdktlist// /,}

  if [[ "${BUILDMODE}" = patch ]]; then
    echo "${BINNAME} [OPTIONS] patch"
    echo ""
    echo "Where:"
    echo "  patch is a file, URL, or bugsystem-compatible location of the patch file"
  else
    echo "${BINNAME} [OPTIONS]"
  fi
  echo ""
  echo "Options:"
  echo ""
  yetus_add_option "--archive-list=<list>" "Comma delimited list of pattern matching notations to copy to patch-dir"
  yetus_add_option "--basedir=<dir>" "The directory to apply the patch to (default current directory)"
  yetus_add_option "--branch=<ref>" "Forcibly set the branch"
  yetus_add_option "--branch-default=<ref>" "If the branch isn't forced and we don't detect one in the patch name, use this branch (default 'master')"
  yetus_add_option "--build-native=<bool>" "If true, then build native components (default 'true')"
  # shellcheck disable=SC2153
  yetus_add_option "--build-tool=<tool>" "Pick which build tool to focus around (one of ${BUILDTOOLS})"
  yetus_add_option "--bugcomments=<bug>" "Only write comments to the screen and this comma delimited list (default: ${bugsys})"
  yetus_add_option "--contrib-guide=<url>" "URL to point new users towards project conventions. (default: ${PATCH_NAMING_RULE} )"
  yetus_add_option "--debug" "If set, then output some extra stuff to stderr"
  yetus_add_option "--dirty-workspace" "Allow the local git workspace to have uncommitted changes"
  yetus_add_option "--empty-patch" "Create a summary of the current source tree"
  yetus_add_option "--java-home=<path>" "Set JAVA_HOME (In Docker mode, this should be local to the image)"
  yetus_add_option "--linecomments=<bug>" "Only write line comments to this comma delimited list (defaults to bugcomments)"
  yetus_add_option "--list-plugins" "List all installed plug-ins and then exit"
  yetus_add_option "--multijdkdirs=<paths>" "Comma delimited lists of JDK paths to use for multi-JDK tests"
  yetus_add_option "--multijdktests=<list>" "Comma delimited tests to use when multijdkdirs is used. (default: '${jdktlist}')"
  yetus_add_option "--modulelist=<list>" "Specify additional modules to test (comma delimited)"
  yetus_add_option "--offline" "Avoid connecting to the Internet"
  yetus_add_option "--patch-dir=<dir>" "The directory for working and output files (default '/tmp/test-patch-${PROJECT_NAME}/pid')"
  yetus_add_option "--personality=<file>" "The personality file to load"
  yetus_add_option "--project=<name>" "The short name for project currently using test-patch (default 'yetus')"
  yetus_add_option "--plugins=<list>" "Specify which plug-ins to add/delete (comma delimited; use 'all' for all found) e.g. --plugins=all,-ant,-scalac (all plugins except ant and scalac)"
  yetus_add_option "--resetrepo" "Forcibly clean the repo"
  yetus_add_option "--run-tests" "Run all relevant tests below the base directory"
  yetus_add_option "--skip-dirs=<list>" "Skip following directories for module finding"
  yetus_add_option "--skip-system-plugins" "Do not load plugins from ${BINDIR}/test-patch.d"
  yetus_add_option "--summarize=<bool>" "Allow tests to summarize results"
  yetus_add_option "--test-parallel=<bool>" "Run multiple tests in parallel (default false in developer mode, true in Jenkins mode)"
  yetus_add_option "--test-threads=<int>" "Number of tests to run in parallel (default defined in ${PROJECT_NAME} build)"
  yetus_add_option "--tests-filter=<list>" "Lists of tests to turn failures into warnings"
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
  echo "Automation options:"
  yetus_add_option "--build-url=<url>" "Set the build location web page (Default: '${BUILD_URL}')"
  yetus_add_option "--build-url-console=<location>" "Location relative to --build-url of the console (Default: '${BUILD_URL_CONSOLE}')"
  yetus_add_option "--build-url-patchdir=<location>" "Location relative to --build-url of the --patch-dir (Default: '${BUILD_URL_ARTIFACTS}')"
  yetus_add_option "--console-report-file=<file>" "Save the final console-based report to a file in addition to the screen"
  yetus_add_option "--console-urls" "Use the build URL instead of path on the console report"
  yetus_add_option "--instance=<string>" "Parallel execution identifier string"
  yetus_add_option "--jenkins" "Enable Jenkins-specifc handling (auto: --robot)"
  yetus_add_option "--mv-patch-dir" "Move the patch-dir into the basedir during cleanup"
  yetus_add_option "--robot" "Assume this is an automated run"
  yetus_add_option "--sentinel" "A very aggressive robot (auto: --robot)"

  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage


  echo ""
  echo "Docker options:"
  docker_usage
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage

  for plugin in ${BUILDTOOLS} ${TESTTYPES} ${BUGSYSTEMS} ${TESTFORMATS}; do
    if declare -f ${plugin}_usage >/dev/null 2>&1; then
      echo ""
      echo "'${plugin}' plugin usage options:"
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
  declare i
  declare j

  common_args "$@"

  for i in "$@"; do
    case ${i} in
      --archive-list=*)
        yetus_comma_to_array ARCHIVE_LIST "${i#*=}"
        yetus_debug "Set to archive: ${ARCHIVE_LIST[*]}"
      ;;
      --bugcomments=*)
        BUGCOMMENTS=${i#*=}
        BUGCOMMENTS=${BUGCOMMENTS//,/ }
      ;;
      --build-native=*)
        BUILD_NATIVE=${i#*=}
      ;;
      --build-tool=*)
        BUILDTOOL=${i#*=}
      ;;
      --build-url=*)
        BUILD_URL=${i#*=}
      ;;
      --build-url-artifacts=*)
        # shellcheck disable=SC2034
        BUILD_URL_ARTIFACTS=${i#*=}
      ;;
      --build-url-console=*)
        # shellcheck disable=SC2034
        BUILD_URL_CONSOLE=${i#*=}
      ;;
      --console-report-file=*)
        CONSOLE_REPORT_FILE=${i#*=}
      ;;
      --console-urls)
        # shellcheck disable=SC2034
        CONSOLE_USE_BUILD_URL=true
      ;;
      --contrib-guide=*)
        PATCH_NAMING_RULE=${i#*=}
      ;;
      --dirty-workspace)
        DIRTY_WORKSPACE=true
      ;;
      --instance=*)
        INSTANCE=${i#*=}
      ;;
      --empty-patch)
        BUILDMODE=full
        # shellcheck disable=SC2034
        BUILDMODEMSG="The source tree"
      ;;
      --java-home=*)
        JAVA_HOME=${i#*=}
      ;;
      --jenkins)
        JENKINS=true
      ;;
      --linecomments=*)
        BUGLINECOMMENTS=${i#*=}
        BUGLINECOMMENTS=${BUGLINECOMMENTS//,/ }
      ;;
      --modulelist=*)
        yetus_comma_to_array USER_MODULE_LIST "${i#*=}"
        yetus_debug "Manually forcing modules ${USER_MODULE_LIST[*]}"
      ;;
      --multijdkdirs=*)
        JDK_DIR_LIST=${i#*=}
        JDK_DIR_LIST=${JDK_DIR_LIST//,/ }
        yetus_debug "Multi-JDK mode activated with ${JDK_DIR_LIST}"
        yetus_add_entry EXEC_MODES MultiJDK
      ;;
      --multijdktests=*)
        JDK_TEST_LIST=${i#*=}
        JDK_TEST_LIST=${JDK_TEST_LIST//,/ }
        yetus_debug "Multi-JDK test list: ${JDK_TEST_LIST}"
      ;;
      --mv-patch-dir)
        RELOCATE_PATCH_DIR=true;
      ;;
      --personality=*)
        PERSONALITY=${i#*=}
      ;;
      --reexec)
        REEXECED=true
      ;;
      --resetrepo)
        RESETREPO=true
      ;;
      --robot)
        ROBOT=true
      ;;
      --run-tests)
        RUN_TESTS=true
      ;;
      --sentinel)
        # shellcheck disable=SC2034
        SENTINEL=true
        yetus_add_entry EXEC_MODES Sentinel
      ;;
      --skip-dirs=*)
        MODULE_SKIPDIRS=${i#*=}
        MODULE_SKIPDIRS=${MODULE_SKIPDIRS//,/ }
        yetus_debug "Setting skipdirs to ${MODULE_SKIPDIRS}"
      ;;
      --summarize=*)
        ALLOWSUMMARIES=${i#*=}
      ;;
      --test-parallel=*)
        # shellcheck disable=SC2034
        TEST_PARALLEL=${i#*=}
      ;;
      --test-threads=*)
        # shellcheck disable=SC2034
        TEST_THREADS=${i#*=}
      ;;
      --tests-filter=*)
        yetus_comma_to_array VOTE_FILTER "${i#*=}"
      ;;
      --tpglobaltimer=*)
        GLOBALTIMER=${i#*=}
      ;;
      --tpinstance=*)
        INSTANCE=${i#*=}
        EXECUTOR_NUMBER=${INSTANCE}
      ;;
      --tpperson=*)
        REEXECPERSONALITY=${i#*=}
      ;;
      --tpreexectimer=*)
        REEXECLAUNCHTIMER=${i#*=}
      ;;
      --*)
        ## PATCH_OR_ISSUE can't be a --.  So this is probably
        ## a plugin thing.
        continue
      ;;
      *)
        PATCH_OR_ISSUE=${i}
      ;;
    esac
  done

  docker_parse_args "$@"

  if [[ -z "${PATCH_OR_ISSUE}"
       && "${BUILDMODE}" = patch ]]; then
    yetus_usage
    exit 1
  fi

  if [[ ${JENKINS} = true ]]; then
    ROBOT=true
    INSTANCE=${EXECUTOR_NUMBER}
    yetus_add_entry EXEC_MODES Jenkins
  fi

  if [[ ${ROBOT} = true ]]; then
    # shellcheck disable=SC2034
    TEST_PARALLEL=true
    RESETREPO=true
    RUN_TESTS=true
    ISSUE=${PATCH_OR_ISSUE}
    yetus_add_entry EXEC_MODES Robot
  fi

  if [[ -n ${REEXECLAUNCHTIMER} ]]; then
    TIMER=${REEXECLAUNCHTIMER};
  else
    start_clock
  fi

  if [[ "${DOCKERMODE}" = true || "${DOCKERSUPPORT}" = true ]]; then
    if [[ "${DOCKER_DESTRCUTIVE}" = true ]]; then
      yetus_add_entry EXEC_MODES DestructiveDocker
    else
      yetus_add_entry EXEC_MODES Docker
    fi
    add_vote_table 0 reexec "Docker mode activated."
    start_clock
  elif [[ "${REEXECED}" = true ]]; then
    yetus_add_entry EXEC_MODES Re-exec
    add_vote_table 0 reexec "Precommit patch detected."
    start_clock
  fi

  # we need absolute dir for ${BASEDIR}
  cd "${STARTINGDIR}" || cleanup_and_exit 1
  BASEDIR=$(yetus_abs "${BASEDIR}")

  if [[ -n ${USER_PATCH_DIR} ]]; then
    PATCH_DIR="${USER_PATCH_DIR}"
  fi

  # we need absolute dir for PATCH_DIR
  cd "${STARTINGDIR}" || cleanup_and_exit 1
  if [[ ! -d ${PATCH_DIR} ]]; then
    mkdir -p "${PATCH_DIR}"
    if [[ $? == 0 ]] ; then
      echo "${PATCH_DIR} has been created"
    else
      echo "Unable to create ${PATCH_DIR}"
      cleanup_and_exit 1
    fi
  fi
  PATCH_DIR=$(yetus_abs "${PATCH_DIR}")

  # we need absolute dir for ${CONSOLE_REPORT_FILE}
  if [[ -n "${CONSOLE_REPORT_FILE}" ]]; then
    touch "${CONSOLE_REPORT_FILE}"
    if [[ $? != 0 ]]; then
      yetus_error "ERROR: cannot write to ${CONSOLE_REPORT_FILE}. Disabling console report file."
      unset CONSOLE_REPORT_FILE
    else
      j="${CONSOLE_REPORT_FILE}"
      CONSOLE_REPORT_FILE=$(yetus_abs "${j}")
    fi
  fi

  if [[ ${RESETREPO} == "true" ]] ; then
    yetus_add_entry EXEC_MODES ResetRepo
  fi

  if [[ ${RUN_TESTS} == "true" ]] ; then
    yetus_add_entry EXEC_MODES UnitTests
  fi

  if [[ -n "${USER_PLUGIN_DIR}" ]]; then
    USER_PLUGIN_DIR=$(yetus_abs "${USER_PLUGIN_DIR}")
  fi

  GITDIFFLINES="${PATCH_DIR}/gitdifflines.txt"
  GITDIFFCONTENT="${PATCH_DIR}/gitdiffcontent.txt"
  GITUNIDIFFLINES="${PATCH_DIR}/gitdiffunilines.txt"

  if [[ "${REEXECED}" = true
     && -f "${PATCH_DIR}/precommit/personality/provided.sh" ]]; then
    REEXECPERSONALITY="${PERSONALITY}"
    PERSONALITY="${PATCH_DIR}/precommit/personality/provided.sh"
  fi
}

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

## @description  List of files that ${PATCH_DIR}/patch modifies
## @audience     private
## @stability    stable
## @replaceable  no
## @return       None; sets ${CHANGED_FILES[@]}
function find_changed_files
{
  declare line
  declare oldifs

  case "${BUILDMODE}" in
    full)
      echo "Building a list of all files in the source tree"
      oldifs=${IFS}
      IFS=$'\n'
      CHANGED_FILES=($(git ls-files))
      IFS=${oldifs}
    ;;
    patch)
      # get a list of all of the files that have been changed,
      # except for /dev/null (which would be present for new files).
      # Additionally, remove any a/ b/ patterns at the front of the patch filenames.
      # shellcheck disable=SC2016
      while read -r line; do
        CHANGED_FILES=("${CHANGED_FILES[@]}" "${line}")
      done < <(
        ${AWK} 'function p(s){sub("^[ab]/","",s); if(s!~"^/dev/null"){print s}}
        /^diff --git /   { p($3); p($4) }
        /^(\+\+\+|---) / { p($2) }' "${PATCH_DIR}/patch" | sort -u)
      ;;
    esac
}

## @description Check for directories to skip during
## @description changed module calcuation
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

  buildfile=$("${BUILDTOOL}_buildfile")

  if [[ $? != 0 ]]; then
    yetus_error "ERROR: Unsupported build tool."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  #  Empty string indicates the build system wants to disable module detection
  if [[ -z ${buildfile} ]]; then
    tmpmods=(".")
  else

    # Now find all the modules that were changed
    for i in "${CHANGED_FILES[@]}"; do

      # TODO: optimize this
      if [[ "${BUILDMODE}" = full && ! "${i}" =~ ${buildfile} ]]; then
        continue
      fi

      dirt=$(dirname "${i}")

      module_skipdir "${dirt}"
      if [[ $? != 0 ]]; then
        continue
      fi

      builddir=$(find_buildfile_dir "${buildfile}" "${dirt}")
      if [[ -z ${builddir} ]]; then
        yetus_error "ERROR: ${buildfile} is not found. Make sure the target is a ${BUILDTOOL}-based project."
        bugsystem_finalreport 1
        cleanup_and_exit 1
      fi
      tmpmods=("${tmpmods[@]}" "${builddir}")
    done
  fi

  tmpmods=("${tmpmods[@]}" "${USER_MODULE_LIST[@]}")

  CHANGED_MODULES=($(printf "%s\n" "${tmpmods[@]}" | sort -u))

  yetus_debug "Locate the union of ${CHANGED_MODULES[*]}"
  count=${#CHANGED_MODULES[@]}
  if [[ ${count} -lt 2 ]]; then
    yetus_debug "Only one entry, so keeping it ${CHANGED_MODULES[0]}"
    # shellcheck disable=SC2034
    CHANGED_UNION_MODULES="${CHANGED_MODULES[0]}"
  else
    i=1
    while [[ ${i} -lt 100 ]]
    do
      tmpmods=()
      for j in "${CHANGED_MODULES[@]}"; do
        tmpmods=("${tmpmods[@]}" $(echo "${j}" | cut -f1-${i} -d/))
      done
      tmpmods=($(printf "%s\n" "${tmpmods[@]}" | sort -u))

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
  if declare -f ${BUILDTOOL}_reorder_modules >/dev/null; then
    "${BUILDTOOL}_reorder_modules" "${repostatus}"
  fi
}

## @description  git checkout the appropriate branch to test.  Additionally, this calls
## @description  'determine_branch' based upon the context provided
## @description  in ${PATCH_DIR} and in git after checkout.
## @audience     private
## @stability    stable
## @replaceable  no
## @return       0 on success.  May exit on failure.
function git_checkout
{
  local currentbranch
  local exemptdir
  local status

  big_console_header "Confirming git environment"

  cd "${BASEDIR}" || cleanup_and_exit 1
  if [[ ! -d .git ]]; then
    yetus_error "ERROR: ${BASEDIR} is not a git repo."
    cleanup_and_exit 1
  fi

  if [[ ${RESETREPO} == "true" ]] ; then

    if [[ -d .git/rebase-apply ]]; then
      yetus_error "ERROR: a previous rebase failed. Aborting it."
      ${GIT} rebase --abort
    fi

    ${GIT} reset --hard
    if [[ $? != 0 ]]; then
      yetus_error "ERROR: git reset is failing"
      cleanup_and_exit 1
    fi

    # if PATCH_DIR is in BASEDIR, then we don't want
    # git wiping it out.
    exemptdir=$(relative_dir "${PATCH_DIR}")
    if [[ $? == 1 ]]; then
      ${GIT} clean -xdf
    else
      # we do, however, want it emptied of all _files_.
      # we need to leave _directories_ in case we are in
      # re-exec mode (which places a directory full of stuff in it)
      yetus_debug "Exempting ${exemptdir} from clean"
      rm "${PATCH_DIR}/*" 2>/dev/null
      ${GIT} clean -xdf -e "${exemptdir}"
    fi
    if [[ $? != 0 ]]; then
      yetus_error "ERROR: git clean is failing"
      cleanup_and_exit 1
    fi

    ${GIT} checkout --force "${PATCH_BRANCH_DEFAULT}"
    if [[ $? != 0 ]]; then
      yetus_error "ERROR: git checkout --force ${PATCH_BRANCH_DEFAULT} is failing"
      cleanup_and_exit 1
    fi

    determine_branch

    # we need to explicitly fetch in case the
    # git ref hasn't been brought in tree yet
    if [[ ${OFFLINE} == false ]]; then

      ${GIT} pull --rebase
      if [[ $? != 0 ]]; then
        yetus_error "ERROR: git pull is failing"
        cleanup_and_exit 1
      fi
    fi
    # forcibly checkout this branch or git ref
    ${GIT} checkout --force "${PATCH_BRANCH}"
    if [[ $? != 0 ]]; then
      yetus_error "ERROR: git checkout ${PATCH_BRANCH} is failing"
      cleanup_and_exit 1
    fi

    # if we've selected a feature branch that has new changes
    # since our last build, we'll need to rebase to see those changes.
    if [[ ${OFFLINE} == false ]]; then
      ${GIT} pull --rebase
      if [[ $? != 0 ]]; then
        yetus_error "ERROR: git pull is failing"
        cleanup_and_exit 1
      fi
    fi

  else

    status=$(${GIT} status --porcelain)
    if [[ "${status}" != "" && -z ${DIRTY_WORKSPACE} ]] ; then
      yetus_error "ERROR: --dirty-workspace option not provided."
      yetus_error "ERROR: can't run in a workspace that contains the following modifications"
      yetus_error "${status}"
      cleanup_and_exit 1
    fi

    determine_branch

    currentbranch=$(${GIT} rev-parse --abbrev-ref HEAD)
    if [[ "${currentbranch}" != "${PATCH_BRANCH}" ]];then
      if [[ "${BUILDMODE}" = patch ]]; then
        echo "WARNING: Current git branch is ${currentbranch} but patch is built for ${PATCH_BRANCH}."
        echo "WARNING: Continuing anyway..."
      fi
      PATCH_BRANCH=${currentbranch}
    fi
  fi

  return 0
}

## @description  Confirm the given branch is a git reference
## @descriptoin  or a valid gitXYZ commit hash
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        branch
## @return       0 on success, if gitXYZ was passed, PATCH_BRANCH=xyz
## @return       1 on failure
function verify_valid_branch
{
  local check=$1
  local i
  local hash

  # shortcut some common
  # non-resolvable names
  if [[ -z ${check} ]]; then
    return 1
  fi

  if [[ ${check} =~ ^git ]]; then
    hash=$(echo "${check}" | cut -f2- -dt)
    if [[ -n ${hash} ]]; then
      ${GIT} cat-file -t "${hash}" >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        PATCH_BRANCH=${hash}
        return 0
      fi
      return 1
    else
      return 1
    fi
  fi

  ${GIT} show-ref "${check}" >/dev/null 2>&1
  return $?
}

## @description  Try to guess the branch being tested using a variety of heuristics
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success, with PATCH_BRANCH updated appropriately
## @return       1 on failure, with PATCH_BRANCH updated to PATCH_BRANCH_DEFAULT
function determine_branch
{
  declare bugs
  declare retval=1

  # something has already set this, so move on
  if [[ -n ${PATCH_BRANCH} ]]; then
    return
  fi

  pushd "${BASEDIR}" > /dev/null

  yetus_debug "Determine branch"

  # something has already set this, so move on
  if [[ -n ${PATCH_BRANCH} ]]; then
    return
  fi

  # developer mode, existing checkout, whatever
  if [[ "${DIRTY_WORKSPACE}" == true ]];then
    PATCH_BRANCH=$(${GIT} rev-parse --abbrev-ref HEAD)
    echo "dirty workspace mode; applying against existing branch"
    return
  fi

  for bugs in ${BUGSYSTEMS}; do
    if declare -f ${bugs}_determine_branch >/dev/null;then
      "${bugs}_determine_branch"
      retval=$?
      if [[ ${retval} == 0 ]]; then
        break
      fi
    fi
  done

  if [[ ${retval} != 0 ]]; then
    PATCH_BRANCH="${PATCH_BRANCH_DEFAULT}"
  fi
  popd >/dev/null
}

## @description  Try to guess the issue being tested using a variety of heuristics
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success, with ISSUE updated appropriately
## @return       1 on failure, with ISSUE updated to "Unknown"
function determine_issue
{
  declare bugsys

  yetus_debug "Determine issue"

  for bugsys in ${BUGSYSTEMS}; do
    if declare -f ${bugsys}_determine_issue >/dev/null; then
      "${bugsys}_determine_issue" "${PATCH_OR_ISSUE}"
      if [[ $? == 0 ]]; then
        yetus_debug "${bugsys} says ${ISSUE}"
        return 0
      fi
    fi
  done
  return 1
}

## @description  Use some heuristics to determine which long running
## @description  tests to run
## @audience     private
## @stability    stable
## @replaceable  no
function determine_needed_tests
{
  declare i
  declare plugin

  big_console_header "Determining needed tests"
  echo "(Depending upon input size and number of plug-ins, this may take a while)"

  for i in "${CHANGED_FILES[@]}"; do
    yetus_debug "Determining needed tests for ${i}"
    personality_file_tests "${i}"

    for plugin in ${TESTTYPES} ${BUILDTOOL}; do
      if declare -f ${plugin}_filefilter >/dev/null 2>&1; then
        "${plugin}_filefilter" "${i}"
      fi
    done
  done

  add_footer_table "Optional Tests" "${NEEDED_TESTS}"
}

## @description  Given ${PATCH_DIR}/patch, apply the patch
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       exit on failure
function apply_patch_file
{
  big_console_header "Applying patch to ${PATCH_BRANCH}"

  patchfile_apply_driver "${PATCH_DIR}/patch"
  if [[ $? != 0 ]] ; then
    echo "PATCH APPLICATION FAILED"
    ((RESULT = RESULT + 1))
    add_vote_table -1 patch "${PATCH_OR_ISSUE} does not apply to ${PATCH_BRANCH}. Rebase required? Wrong Branch? See ${PATCH_NAMING_RULE} for help."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi
  return 0
}

## @description  copy the test-patch binary bits to a new working dir,
## @description  setting USER_PLUGIN_DIR and PERSONALITY to the new
## @description  locations.
## @description  this is used for test-patch in docker and reexec mode
## @audience     private
## @stability    evolving
## @replaceable  no
function copytpbits
{
  declare dockerdir
  declare dockfile
  declare lines

  # we need to copy/consolidate all the bits that might have changed
  # that are considered part of test-patch.  This *might* break
  # things that do off-path includes, but there isn't much we can
  # do about that, I don't think.

  # if we've already copied, then don't bother doing it again
  if [[ ${STARTINGDIR} == ${PATCH_DIR}/precommit ]]; then
    yetus_debug "Skipping copytpbits; already copied once"
    return
  fi

  pushd "${STARTINGDIR}" >/dev/null
  mkdir -p "${PATCH_DIR}/precommit/user-plugins"
  mkdir -p "${PATCH_DIR}/precommit/personality"
  mkdir -p "${PATCH_DIR}/precommit/test-patch-docker"

  # copy our entire universe, preserving links, etc.
  yetus_debug "copying '${BINDIR}' over to '${PATCH_DIR}/precommit'"
  # shellcheck disable=SC2164
  (cd "${BINDIR}"; tar cpf - . ) | (cd "${PATCH_DIR}/precommit"; tar xpf - )

  if [[ ! -f "${BINDIR}/VERSION"
     && -f "${BINDIR}/../VERSION" ]]; then
    cp -p "${BINDIR}/../VERSION" "${PATCH_DIR}/precommit/VERSION"
  fi

  if [[ -n "${USER_PLUGIN_DIR}"
    && -d "${USER_PLUGIN_DIR}"  ]]; then
    yetus_debug "copying '${USER_PLUGIN_DIR}' over to ${PATCH_DIR}/precommit/user-plugins"
    cp -pr "${USER_PLUGIN_DIR}"/. \
      "${PATCH_DIR}/precommit/user-plugins"
  fi
  # Set to be relative to ${PATCH_DIR}/precommit
  USER_PLUGIN_DIR="${PATCH_DIR}/precommit/user-plugins"

  if [[ -n ${PERSONALITY}
    && -f ${PERSONALITY} ]]; then
    yetus_debug "copying '${PERSONALITY}' over to '${PATCH_DIR}/precommit/personality/provided.sh'"
    cp -pr "${PERSONALITY}" "${PATCH_DIR}/precommit/personality/provided.sh"
  fi

  if [[ -n ${DOCKERFILE}
      && -f ${DOCKERFILE} ]]; then
    yetus_debug "copying '${DOCKERFILE}' over to '${PATCH_DIR}/precommit/test-patch-docker/Dockerfile'"
    dockerdir=$(dirname "${DOCKERFILE}")
    dockfile=$(basename "${DOCKERFILE}")
    pushd "${dockerdir}" >/dev/null
    gitfilerev=$("${GIT}" log -n 1 --pretty=format:%h -- "${dockfile}" 2>/dev/null)
    popd >/dev/null
    if [[ -z ${gitfilerev} ]]; then
      gitfilerev=$(date "+%F")
      gitfilerev="date${gitfilerev}"
    fi
    (
      echo "### YETUS_PRIVATE: dockerfile=${DOCKERFILE}"
      echo "### YETUS_PRIVATE: gitrev=${gitfilerev}"
      lines=$(${GREP} -n 'YETUS CUT HERE' "${DOCKERFILE}" | cut -f1 -d:)
      if [[ -z "${lines}" ]]; then
        cat "${DOCKERFILE}"
      else
        head -n "${lines}" "${DOCKERFILE}"
      fi
      # make sure we put some space between, just in case last
      # line isn't an empty line or whatever
      printf "\n\n"
      echo "### YETUS_PRIVATE: start test-patch-bootstrap"
      cat "${BINDIR}/test-patch-docker/Dockerfile-endstub"

      printf "\n\n"
    ) > "${PATCH_DIR}/precommit/test-patch-docker/Dockerfile"
    DOCKERFILE="${PATCH_DIR}/precommit/test-patch-docker/Dockerfile"
  fi

  popd >/dev/null
}

## @description  change the working directory to execute the buildtool
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        MODULE_ index
function buildtool_cwd
{
  declare modindex=$1

  BUILDTOOLCWD="${BUILDTOOLCWD//@@@BASEDIR@@@/${BASEDIR}}"
  BUILDTOOLCWD="${BUILDTOOLCWD//@@@MODULEDIR@@@/${BASEDIR}/${MODULE[${modindex}]}}"

  if [[ "${BUILDTOOLCWD}" =~ ^/ ]]; then
    yetus_debug "buildtool_cwd: ${BUILDTOOLCWD}"
    if [[ ! -e "${BUILDTOOLCWD}" ]]; then
      mkdir -p "${BUILDTOOLCWD}"
    fi
    pushd "${BUILDTOOLCWD}" >/dev/null
    return $?
  fi

  case "${BUILDTOOLCWD}" in
    basedir)
      pushd "${BASEDIR}" >/dev/null
    ;;
    module)
      pushd "${BASEDIR}/${MODULE[${modindex}]}" >/dev/null
    ;;
    *)
      pushd "$(pwd)"
    ;;
  esac
}

## @description  If this patches actually patches test-patch.sh, then
## @description  run with the patched version for the test.
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       none; otherwise relaunches
function check_reexec
{
  declare commentfile=${PATCH_DIR}/tp.${RANDOM}
  declare tpdir
  declare copy=false
  declare testdir
  declare plugin

  if [[ ${REEXECED} == true ]]; then
    big_console_header "Re-exec mode detected. Continuing."
    return
  fi

  # determine if the patch hits
  # any test-patch sensitive bits
  # if so, we need to copy the universe
  # after patching it (copy=true)
  for testdir in "${BINDIR}" \
      "${PERSONALITY}" \
      "${USER_PLUGIN_DIR}" \
      "${DOCKERFILE}"; do
    tpdir=$(relative_dir "${testdir}")
    if [[ $? == 0
        && "${CHANGED_FILES[*]}" =~ ${tpdir} ]]; then
      copy=true
    fi
  done

  if [[ ${copy} == true && "${BUILDMODE}" != full ]]; then
    big_console_header "precommit patch detected"

    if [[ ${RESETREPO} == false ]]; then
      ((RESULT = RESULT + 1))
      yetus_debug "can't destructively change the working directory. run with '--resetrepo' please. :("
      add_vote_table -1 precommit "Couldn't test precommit changes because we aren't configured to destructively change the working directory."
    else

      apply_patch_file

      if [[ ${ROBOT} == true ]]; then
        rm "${commentfile}" 2>/dev/null
        echo "(!) A patch to the testing environment has been detected. " > "${commentfile}"
        echo "Re-executing against the patched versions to perform further tests. " >> "${commentfile}"
        echo "The console is at ${BUILD_URL}${BUILD_URL_CONSOLE} in case of problems." >> "${commentfile}"
        write_comment "${commentfile}"
        rm "${commentfile}"
      fi
    fi
  fi

  if [[ ${DOCKERSUPPORT} == false
     && ${copy} == false ]]; then
    return
  fi

  if [[ ${DOCKERSUPPORT} == true
    && ${copy} == false ]]; then
      big_console_header "Re-execing under Docker"
  fi

  # copy our universe
  copytpbits

  if [[ ${DOCKERSUPPORT} == true ]]; then
    # if we are doing docker, then we re-exec, but underneath the
    # container

    for plugin in ${PROJECT_NAME} ${BUILDTOOL} ${BUGSYSTEMS} ${TESTTYPES} ${TESTFORMATS}; do
      if declare -f ${plugin}_docker_support >/dev/null; then
        "${plugin}_docker_support"
      fi
    done

    TESTPATCHMODE="${USER_PARAMS[*]}"
    if [[ -n "${BUILD_URL}" ]]; then
      TESTPATCHMODE="--build-url=${BUILD_URL} ${TESTPATCHMODE}"
    fi

    if [[ -f "${PERSONALITY}" ]]; then
      TESTPATCHMODE="--tpperson=${PERSONALITY} ${TESTPATCHMODE}"
    fi

    TESTPATCHMODE="--tpglobaltimer=${GLOBALTIMER} ${TESTPATCHMODE}"
    TESTPATCHMODE="--tpreexectimer=${TIMER} ${TESTPATCHMODE}"
    TESTPATCHMODE="--tpinstance=${INSTANCE} ${TESTPATCHMODE}"
    TESTPATCHMODE="--plugins=${ENABLED_PLUGINS// /,} ${TESTPATCHMODE}"
    TESTPATCHMODE=" ${TESTPATCHMODE}"
    export TESTPATCHMODE

    #shellcheck disable=SC2164
    cd "${BASEDIR}"
    #shellcheck disable=SC2093
    docker_handler
  else

    # if we aren't doing docker, then just call ourselves
    # but from the new path with the new flags
    #shellcheck disable=SC2164
    cd "${PATCH_DIR}/precommit/"
    exec "${PATCH_DIR}/precommit/test-patch.sh" \
      "${USER_PARAMS[@]}" \
      --reexec \
      --basedir="${BASEDIR}" \
      --branch="${PATCH_BRANCH}" \
      --patch-dir="${PATCH_DIR}" \
      --tpglobaltimer="${GLOBALTIMER}" \
      --tpreexectimer="${TIMER}" \
      --personality="${PERSONALITY}" \
      --tpinstance="${INSTANCE}" \
      --user-plugins="${USER_PLUGIN_DIR}"
  fi
}

## @description  Save file names and directory to the patch dir
## @audience     public
## @stability    evolving
## @replaceable  no
function archive
{
  declare pmn
  declare fn
  declare line
  declare srcdir
  declare tmpfile="${PATCH_DIR}/tmp.$$.${RANDOM}"

  if [[ ${#ARCHIVE_LIST[@]} -eq 0 ]]; then
    return
  fi

  if ! verify_command "rsync" "${RSYNC}"; then
    yetus_error "WARNING: Cannot use the archive function"
    return
  fi

  yetus_debug "Starting archiving process"
  # get the list of files. these will be with
  # the full path
  # (this is pretty expensive)

  rm "${tmpfile}" 2>/dev/null
  for pmn in "${ARCHIVE_LIST[@]}"; do
    find "${BASEDIR}" -name "${pmn}" >> "${tmpfile}"
  done

  # read the list, stripping of both
  # the BASEDIR and any leading /.
  # with our filename fragment,
  # call faster_dirname with a prepended /
  while read -r line; do
    yetus_debug "Archiving: ${line}"
    srcdir=$(faster_dirname "/${line}")
    mkdir -p "${PATCH_DIR}/archiver${srcdir}"
    "${RSYNC}" -av "${BASEDIR}/${line}" "${PATCH_DIR}/archiver${srcdir}" >/dev/null 2>&1
  done < <("${SED}" -e "s,${BASEDIR},,g" \
      -e "s,^/,,g" "${tmpfile}")
  rm "${tmpfile}" 2>/dev/null
  yetus_debug "Ending archiving process"

}

## @description  Reset the test results
## @audience     public
## @stability    evolving
## @replaceable  no
function modules_reset
{
  MODULE_STATUS=()
  MODULE_STATUS_TIMER=()
  MODULE_STATUS_MSG=()
  MODULE_STATUS_LOG=()
  MODULE_COMPILE_LOG=()
}

## @description  Backup the MODULE globals prior to loop processing
## @audience     public
## @stability    evolving
## @replaceable  no
function modules_backup
{
  MODULE_BACKUP_STATUS=("${MODULE_STATUS[@]}")
  MODULE_BACKUP_STATUS_TIMER=("${MODULE_STATUS_TIMER[@]}")
  MODULE_BACKUP_STATUS_MSG=("${MODULE_STATUS_MSG[@]}")
  MODULE_BACKUP_STATUS_LOG=("${MODULE_STATUS_LOG[@]}")
  MODULE_BACKUP_COMPILE_LOG=("${MODULE_COMPILE_LOG[@]}")
}

## @description  Restore the backup
## @audience     public
## @stability    evolving
## @replaceable  no
function modules_restore
{
  MODULE_STATUS=("${MODULE_BACKUP_STATUS[@]}")
  MODULE_STATUS_TIMER=("${MODULE_BACKUP_STATUS_TIMER[@]}")
  MODULE_STATUS_MSG=("${MODULE_BACKUP_STATUS_MSG[@]}")
  MODULE_STATUS_LOG=("${MODULE_BACKUP_STATUS_LOG[@]}")
  MODULE_COMPILE_LOG=("${MODULE_BACKUP_COMPILE_LOG[@]}")
}

## @description  Utility to print standard module errors
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        repostatus
## @param        testtype
## @param        summarymode
function modules_messages
{
  declare repostatus=$1
  declare testtype=$2
  declare summarymode=$3
  shift 3
  declare modindex=0
  declare repo
  declare goodtime=0
  declare failure=false
  declare oldtimer
  declare statusjdk
  declare multijdkmode=false

  if [[ "${BUILDMODE}" == full ]]; then
    repo="the source"
  elif [[ "${repostatus}" == branch ]]; then
    repo=${PATCH_BRANCH}
  else
    repo="the patch"
  fi

  if verify_multijdk_test "${testtype}"; then
    multijdkmode=true
  fi

  oldtimer=${TIMER}

  if [[ ${summarymode} == true
    && ${ALLOWSUMMARIES} == true ]]; then

    until [[ ${modindex} -eq ${#MODULE[@]} ]]; do

      if [[ ${multijdkmode} == true ]]; then
        statusjdk=${MODULE_STATUS_JDK[${modindex}]}
      fi

      if [[ "${MODULE_STATUS[${modindex}]}" == '+1' ]]; then
        ((goodtime=goodtime + ${MODULE_STATUS_TIMER[${modindex}]}))
      else
        failure=true
        start_clock
        echo ""
        echo "${MODULE_STATUS_MSG[${modindex}]}"
        echo ""
        offset_clock "${MODULE_STATUS_TIMER[${modindex}]}"
        add_vote_table "${MODULE_STATUS[${modindex}]}" "${testtype}" "${MODULE_STATUS_MSG[${modindex}]}"
        if [[ ${MODULE_STATUS[${modindex}]} == -1
          && -n "${MODULE_STATUS_LOG[${modindex}]}" ]]; then
          add_footer_table "${testtype}" "@@BASE@@/${MODULE_STATUS_LOG[${modindex}]}"
        fi
      fi
      ((modindex=modindex+1))
    done

    if [[ ${failure} == false ]]; then
      start_clock
      offset_clock "${goodtime}"
      add_vote_table +1 "${testtype}" "${repo} passed${statusjdk}"
    fi
  else
    until [[ ${modindex} -eq ${#MODULE[@]} ]]; do
      start_clock
      echo ""
      echo "${MODULE_STATUS_MSG[${modindex}]}"
      echo ""
      offset_clock "${MODULE_STATUS_TIMER[${modindex}]}"
      add_vote_table "${MODULE_STATUS[${modindex}]}" "${testtype}" "${MODULE_STATUS_MSG[${modindex}]}"
      if [[ ${MODULE_STATUS[${modindex}]} == -1
        && -n "${MODULE_STATUS_LOG[${modindex}]}" ]]; then
        add_footer_table "${testtype}" "@@BASE@@/${MODULE_STATUS_LOG[${modindex}]}"
      fi
      ((modindex=modindex+1))
    done
  fi
  TIMER=${oldtimer}
}

## @description  Add or update a test result. Update requires
## @description  at least the first two parameters.
## @description  WARNING: If the message is updated,
## @description  then the JDK version is also calculated to match
## @description  the current JAVA_HOME.
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        moduleindex
## @param        -1-0|0|+1
## @param        logvalue
## @param        message
function module_status
{
  declare index=$1
  declare value=$2
  shift 2
  declare log=$1
  shift

  declare jdk

  jdk=$(report_jvm_version "${JAVA_HOME}")

  if [[ -n ${index}
    && ${index} =~ ^[0-9]+$ ]]; then
    MODULE_STATUS[${index}]="${value}"
    if [[ -n ${log} ]]; then
      MODULE_STATUS_LOG[${index}]="${log}"
    fi
    if [[ -n $1 ]]; then
      MODULE_STATUS_JDK[${index}]=" with JDK v${jdk}"
      MODULE_STATUS_MSG[${index}]="${*}"
    fi
  else
    yetus_error "ASSERT: module_status given bad index: ${index}"
    yetus_error "ASSERT: module_stats $*"
    generate_stack
    exit 1
  fi
}

## @description  run the tests for the queued modules
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        repostatus
## @param        testtype
## @param        mvncmdline
function modules_workers
{
  declare repostatus=$1
  declare testtype=$2
  shift 2
  declare modindex=0
  declare fn
  declare savestart=${TIMER}
  declare savestop
  declare repo
  declare modulesuffix
  declare jdk=""
  declare jdkindex=0
  declare statusjdk
  declare result=0
  declare argv

  if [[ "${BUILDMODE}" = full ]]; then
    repo="the source"
  elif [[ ${repostatus} == branch ]]; then
    repo=${PATCH_BRANCH}
  else
    repo="the patch"
  fi

  modules_reset

  if verify_multijdk_test "${testtype}"; then
    jdk=$(report_jvm_version "${JAVA_HOME}")
    statusjdk=" with JDK v${jdk}"
    jdk="-jdk${jdk}"
    jdk=${jdk// /}
    yetus_debug "Starting MultiJDK mode${statusjdk} on ${testtype}"
  fi

  until [[ ${modindex} -eq ${#MODULE[@]} ]]; do
    start_clock

    fn=$(module_file_fragment "${MODULE[${modindex}]}")
    fn="${fn}${jdk}"
    modulesuffix=$(basename "${MODULE[${modindex}]}")
    buildtool_cwd "${modindex}"

    if [[ ${modulesuffix} = \. ]]; then
      modulesuffix="root"
    fi

    if [[ $? != 0 ]]; then
      echo "${BASEDIR}/${MODULE[${modindex}]} no longer exists. Skipping."
      ((modindex=modindex+1))
      continue
    fi

    argv=("${@//@@@MODULEFN@@@/${fn}}")
    argv=("${argv[@]//@@@MODULEDIR@@@/${BASEDIR}/${MODULE[${modindex}]}}")

    # shellcheck disable=2086,2046
    echo_and_redirect "${PATCH_DIR}/${repostatus}-${testtype}-${fn}.txt" \
      $("${BUILDTOOL}_executor" "${testtype}") \
      ${MODULEEXTRAPARAM[${modindex}]//@@@MODULEFN@@@/${fn}} \
      "${argv[@]}"

    if [[ $? == 0 ]] ; then
      module_status \
        ${modindex} \
        +1 \
        "${repostatus}-${testtype}-${fn}.txt" \
        "${modulesuffix} in ${repo} passed${statusjdk}."
    else
      module_status \
        ${modindex} \
        -1 \
        "${repostatus}-${testtype}-${fn}.txt" \
        "${modulesuffix} in ${repo} failed${statusjdk}."
      ((result = result + 1))
    fi

    # compile is special
    if [[ ${testtype} = compile ]]; then
      MODULE_COMPILE_LOG[${modindex}]="${PATCH_DIR}/${repostatus}-${testtype}-${fn}.txt"
      yetus_debug "Compile log set to ${MODULE_COMPILE_LOG[${modindex}]}"
    fi

    savestop=$(stop_clock)
    MODULE_STATUS_TIMER[${modindex}]=${savestop}
    # shellcheck disable=SC2086
    echo "Elapsed: $(clock_display ${savestop})"
    popd >/dev/null
    ((modindex=modindex+1))
  done

  TIMER=${savestart}

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Reset the queue for tests
## @audience     public
## @stability    evolving
## @replaceable  no
function clear_personality_queue
{
  yetus_debug "Personality: clear queue"
  MODCOUNT=0
  MODULE=()
}

## @description  Build the queue for tests
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        module
## @param        profiles/flags/etc
function personality_enqueue_module
{
  yetus_debug "Personality: enqueue $*"
  local module=$1
  shift

  MODULE[${MODCOUNT}]=${module}
  MODULEEXTRAPARAM[${MODCOUNT}]=${*}
  ((MODCOUNT=MODCOUNT+1))
}

## @description  Remove a module
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        modulenames
function dequeue_personality_module
{
  declare modname=$1
  declare oldmodule=("${MODULE[@]}")
  declare oldmodparams=("${MODULEESXTRAPARAM[@]}")
  declare modindex=0

  yetus_debug "Personality: dequeue $*"

  clear_personality_queue

  until [[ ${modindex} -eq ${#oldmodule[@]} ]]; do
    if [[ "${oldmodule[${modindex}]}" = "${modname}" ]]; then
      yetus_debug "Personality: removing ${modindex}, ${oldmodule[${modindex}]} = ${modname}"
    else
      personality_enqueue_module "${oldmodule[${modindex}]}" "${oldmodparams[${modindex}]}"
    fi
    ((modindex=modindex+1))
  done
}

## @description  Utility to push many tests into the failure list
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        testdesc
## @param        testlist
function populate_test_table
{
  local reason=$1
  shift
  local first=""
  local i

  for i in "$@"; do
    if [[ -z "${first}" ]]; then
      add_test_table "${reason}" "${i}"
      first="${reason}"
    else
      add_test_table " " "${i}"
    fi
  done
}

## @description  Run and verify the output of the appropriate unit tests
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function check_unittests
{
  declare i
  declare testsys
  declare test_logfile
  declare result=0
  declare -r savejavahome=${JAVA_HOME}
  declare multijdkmode
  declare jdk=""
  declare jdkindex=0
  declare jdklist
  declare statusjdk
  declare formatresult=0
  declare needlog

  if ! verify_needed_test unit; then
    return 0
  fi

  big_console_header "Running unit tests"

  if verify_multijdk_test unit; then
    multijdkmode=true
    jdklist=${JDK_DIR_LIST}
  else
    multijdkmode=false
    jdklist=${JAVA_HOME}
  fi

  for jdkindex in ${jdklist}; do
    if [[ ${multijdkmode} == true ]]; then
      JAVA_HOME=${jdkindex}
      jdk=$(report_jvm_version "${JAVA_HOME}")
      statusjdk="JDK v${jdk} "
      jdk="-jdk${jdk}"
      jdk=${jdk// /}
    fi

    personality_modules patch unit
    "${BUILDTOOL}_modules_worker" patch unit

    ((result=result+$?))

    i=0
    until [[ $i -eq ${#MODULE[@]} ]]; do
      module=${MODULE[${i}]}
      fn=$(module_file_fragment "${module}")
      fn="${fn}${jdk}"
      test_logfile="${PATCH_DIR}/patch-unit-${fn}.txt"

      buildtool_cwd "${i}"

      needlog=0
      for testsys in ${TESTFORMATS}; do
        if declare -f ${testsys}_process_tests >/dev/null; then
          yetus_debug "Calling ${testsys}_process_tests"
          "${testsys}_process_tests" "${module}" "${test_logfile}" "${fn}"
          formatresult=$?
          ((result=result+formatresult))
          if [[ "${formatresult}" != 0 ]]; then
            needlog=1
          fi
        fi
      done

      if [[ ${needlog} == 1 ]]; then
        module_status ${i} -1 "patch-unit-${fn}.txt"
      fi

      popd >/dev/null

      ((i=i+1))
    done

    for testsys in ${TESTFORMATS}; do
      if declare -f ${testsys}_finalize_results >/dev/null; then
        yetus_debug "Calling ${testsys}_finalize_results"
        "${testsys}_finalize_results" "${statusjdk}"
      fi
    done

  done
  JAVA_HOME=${savejavahome}

  modules_messages patch unit false

  if [[ ${JENKINS} == true ]]; then
    add_footer_table "${statusjdk} Test Results" "${BUILD_URL}testReport/"
  fi

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Write comments onto bug systems that have code review support.
## @description  File should be in the form of "file:line:comment"
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        filename
function bugsystem_linecomments
{
  declare title=$1
  declare fn=$2
  declare line
  declare bugs
  declare realline
  declare text
  declare idxline
  declare uniline

  if [[ ! -f "${GITUNIDIFFLINES}" ]]; then
    return
  fi

  while read -r line;do
    file=$(echo "${line}" | cut -f1 -d:)
    realline=$(echo "${line}" | cut -f2 -d:)
    text=$(echo "${line}" | cut -f3- -d:)
    idxline="${file}:${realline}:"
    uniline=$(${GREP} "${idxline}" "${GITUNIDIFFLINES}" | cut -f3 -d: )

    for bugs in ${BUGLINECOMMENTS}; do
      if declare -f ${bugs}_linecomments >/dev/null;then
        "${bugs}_linecomments" "${title}" "${file}" "${realline}" "${uniline}" "${text}"
      fi
    done
  done < "${fn}"
}

## @description  Write the final output to the selected bug system
## @audience     private
## @stability    evolving
## @replaceable  no
function bugsystem_finalreport
{
  declare version
  declare bugs

  if [[ -f "${BINDIR}/../VERSION" ]]; then
    version=$(cat "${BINDIR}/../VERSION")
  elif [[ -f "${BINDIR}/VERSION" ]]; then
    version=$(cat "${BINDIR}/VERSION")
  fi

  if [[ "${ROBOT}" = true &&
        -n "${BUILD_URL}" &&
        -n "${BUILD_URL_CONSOLE}" ]]; then
    add_footer_table "Console output" "${BUILD_URL}${BUILD_URL_CONSOLE}"
  fi
  add_footer_table "Powered by" "Apache Yetus ${version}   http://yetus.apache.org"

  for bugs in ${BUGCOMMENTS}; do
    if declare -f ${bugs}_finalreport >/dev/null;then
      "${bugs}_finalreport" "${@}"
    fi
  done
}

## @description  Clean the filesystem as appropriate and then exit
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        runresult
function cleanup_and_exit
{
  local result=$1

  if [[ ${ROBOT} == "true" && ${RELOCATE_PATCH_DIR} == "true" && \
      -e ${PATCH_DIR} && -d ${PATCH_DIR} ]] ; then
    # if PATCH_DIR is already inside BASEDIR, then
    # there is no need to move it since we assume that
    # Jenkins or whatever already knows where it is at
    # since it told us to put it there!
    relative_dir "${PATCH_DIR}" >/dev/null
    if [[ $? == 1 ]]; then
      yetus_debug "mv ${PATCH_DIR} ${BASEDIR}"
      mv "${PATCH_DIR}" "${BASEDIR}"
    fi
  fi
  big_console_header "Finished build."

  # shellcheck disable=SC2086
  exit ${result}
}

## @description  Driver to execute _tests routines
## @audience     private
## @stability    evolving
## @replaceable  no
function runtests
{
  local plugin

  if [[ ${RUN_TESTS} == "true" ]] ; then

    verify_patchdir_still_exists
    check_unittests
  fi

  for plugin in ${TESTTYPES}; do
    verify_patchdir_still_exists
    if declare -f ${plugin}_tests >/dev/null 2>&1; then
      modules_reset
      yetus_debug "Running ${plugin}_tests"
      #shellcheck disable=SC2086
      ${plugin}_tests
    fi
  done
  archive
}

## @description  Calculate the differences between the specified files
## @description  using just the column+ messages (third+ column in a
## @descriptoin  colon delimated flie) and output it to stdout.
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function column_calcdiffs
{
  declare branch=$1
  declare patch=$2
  declare tmp=${PATCH_DIR}/pl.$$.${RANDOM}
  declare j

  # first, strip filenames:line:
  # this keeps column: in an attempt to increase
  # accuracy in case of multiple, repeated errors
  # since the column number shouldn't change
  # if the line of code hasn't been touched
  # shellcheck disable=SC2016
  cut -f3- -d: "${branch}" > "${tmp}.branch"
  # shellcheck disable=SC2016
  cut -f3- -d: "${patch}" > "${tmp}.patch"

  # compare the errors, generating a string of line
  # numbers. Sorry portability: GNU diff makes this too easy
  ${DIFF} --unchanged-line-format="" \
     --old-line-format="" \
     --new-line-format="%dn " \
     "${tmp}.branch" \
     "${tmp}.patch" > "${tmp}.lined"

  # now, pull out those lines of the raw output
  # shellcheck disable=SC2013
  for j in $(cat "${tmp}.lined"); do
    # shellcheck disable=SC2086
    head -${j} "${patch}" | tail -1
  done

  rm "${tmp}.branch" "${tmp}.patch" "${tmp}.lined" 2>/dev/null
}

## @description  Calculate the differences between the specified files
## @description  using just the error messages (last column in a
## @descriptoin  colon delimated flie) and output it to stdout.
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @return       differences
function error_calcdiffs
{
  declare branch=$1
  declare patch=$2
  declare tmp=${PATCH_DIR}/pl.$$.${RANDOM}
  declare j

  # first, pull out just the errors
  # shellcheck disable=SC2016
  ${AWK} -F: '{print $NF}' "${branch}" > "${tmp}.branch"

  # shellcheck disable=SC2016
  ${AWK} -F: '{print $NF}' "${patch}" > "${tmp}.patch"

  # compare the errors, generating a string of line
  # numbers. Sorry portability: GNU diff makes this too easy
  ${DIFF} --unchanged-line-format="" \
     --old-line-format="" \
     --new-line-format="%dn " \
     "${tmp}.branch" \
     "${tmp}.patch" > "${tmp}.lined"

  # now, pull out those lines of the raw output
  # shellcheck disable=SC2013
  for j in $(cat "${tmp}.lined"); do
    # shellcheck disable=SC2086
    head -${j} "${patch}" | tail -1
  done

  rm "${tmp}.branch" "${tmp}.patch" "${tmp}.lined" 2>/dev/null
}

## @description  Wrapper to call specific version of calcdiffs if available
## @description  otherwise calls error_calcdiffs
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        branchlog
## @param        patchlog
## @param        testtype
## @return       differences
function calcdiffs
{
  declare branchlog=$1
  declare patchlog=$2
  declare testtype=$3

  # ensure that both log files exist
  if [[ ! -f "${branchlog}" ]]; then
    touch "${branchlog}"
  fi
  if [[ ! -f "${patchlog}" ]]; then
    touch "${patchlog}"
  fi

  if declare -f ${PROJECT_NAME}_${testtype}_calcdiffs >/dev/null; then
    "${PROJECT_NAME}_${testtype}_calcdiffs" "${branchlog}" "${patchlog}"
  elif declare -f ${BUILDTOOL}_${testtype}_calcdiffs >/dev/null; then
    "${BUILDTOOL}_${testtype}_calcdiffs" "${branchlog}" "${patchlog}"
  elif declare -f ${testtype}_calcdiffs >/dev/null; then
    "${testtype}_calcdiffs" "${branchlog}" "${patchlog}"
  else
    error_calcdiffs "${branchlog}" "${patchlog}"
  fi
}

## @description generate a standarized calcdiff status message
## @audience    public
## @stability   evolving
## @replaceable no
## @param       totalbranchissues
## @param       totalpatchissues
## @param       newpatchissues
## @return      errorstring
function generic_calcdiff_status
{
  declare -i numbranch=$1
  declare -i numpatch=$2
  declare -i addpatch=$3
  declare -i samepatch
  declare -i fixedpatch

  ((samepatch=numpatch-addpatch))
  ((fixedpatch=numbranch-numpatch+addpatch))

  if [[ "${BUILDMODE}" = full ]]; then
    printf "has %i issues." "${addpatch}"
  else
    printf "generated %i new + %i unchanged - %i fixed = %i total (was %i)" \
      "${addpatch}" \
      "${samepatch}" \
      "${fixedpatch}" \
      "${numpatch}" \
      "${numbranch}"
  fi
}

## @description  Helper routine for plugins to ask projects, etc
## @description  to count problems in a log file
## @description  and output it to stdout.
## @audience     public
## @stability    evolving
## @replaceable  no
## @return       number of issues
function generic_logfilter
{
  declare testtype=$1
  declare input=$2
  declare output=$3

  if declare -f ${PROJECT_NAME}_${testtype}_logfilter >/dev/null; then
    "${PROJECT_NAME}_${testtype}_logfilter" "${input}" "${output}"
  elif declare -f ${BUILDTOOL}_${testtype}_logfilter >/dev/null; then
    "${BUILDTOOL}_${testtype}_logfilter" "${input}" "${output}"
  elif declare -f ${testtype}_logfilter >/dev/null; then
    "${testtype}_logfilter" "${input}" "${output}"
  else
    yetus_error "ERROR: ${testtype}: No function defined to filter problems."
    echo 0
  fi
}

## @description  Helper routine for plugins to do a pre-patch prun
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        testype
## @param        multijdk
## @return       1 on failure
## @return       0 on success
function generic_pre_handler
{
  declare testtype=$1
  declare multijdkmode=$2
  declare result=0
  declare -r savejavahome=${JAVA_HOME}
  declare multijdkmode
  declare jdkindex=0
  declare jdklist

  if ! verify_needed_test "${testtype}"; then
     return 0
  fi

  big_console_header "Pre-patch ${testtype} verification on ${PATCH_BRANCH}"

  if verify_multijdk_test "${testtype}"; then
    multijdkmode=true
    jdklist=${JDK_DIR_LIST}
  else
    multijdkmode=false
    jdklist=${JAVA_HOME}
  fi

  for jdkindex in ${jdklist}; do
    if [[ ${multijdkmode} == true ]]; then
      JAVA_HOME=${jdkindex}
    fi

    personality_modules branch "${testtype}"
    "${BUILDTOOL}_modules_worker" branch "${testtype}"

    ((result=result + $?))
    modules_messages branch "${testtype}" true

  done
  JAVA_HOME=${savejavahome}

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Generic post-patch log handler
## @audience     public
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
## @param        origlog
## @param        testtype
## @param        multijdkmode
function generic_postlog_compare
{
  declare origlog=$1
  declare testtype=$2
  declare multijdk=$3
  declare result=0
  declare i
  declare fn
  declare jdk
  declare statusjdk
  declare -i numbranch=0
  declare -i numpatch=0
  declare -i addpatch=0
  declare -i samepatch=0
  declare -i fixedpatch=0
  declare summarize=true

  if [[ ${multijdk} == true ]]; then
    jdk=$(report_jvm_version "${JAVA_HOME}")
    statusjdk=" with JDK v${jdk}"
    jdk="-jdk${jdk}"
    jdk=${jdk// /}
  fi

  i=0
  until [[ ${i} -eq ${#MODULE[@]} ]]; do
    if [[ ${MODULE_STATUS[${i}]} == -1 ]]; then
      ((result=result+1))
      ((i=i+1))
      continue
    fi

    fn=$(module_file_fragment "${MODULE[${i}]}")
    fn="${fn}${jdk}"
    module_suffix=$(basename "${MODULE[${i}]}")
    if [[ ${module_suffix} == \. ]]; then
      module_suffix=root
    fi

    yetus_debug "${testtype}: branch-${origlog}-${fn}.txt vs. patch-${origlog}-${fn}.txt"

    # if it was a new module, this won't exist.
    if [[ ! -f "${PATCH_DIR}/branch-${origlog}-${fn}.txt" ]]; then
      touch "${PATCH_DIR}/branch-${origlog}-${fn}.txt"
    fi

    if [[ ! -f "${PATCH_DIR}/patch-${origlog}-${fn}.txt" ]]; then
      touch "${PATCH_DIR}/patch-${origlog}-${fn}.txt"
    fi

    generic_logfilter "${testtype}" "${PATCH_DIR}/branch-${origlog}-${fn}.txt" "${PATCH_DIR}/branch-${origlog}-${testtype}-${fn}.txt"
    generic_logfilter "${testtype}" "${PATCH_DIR}/patch-${origlog}-${fn}.txt" "${PATCH_DIR}/patch-${origlog}-${testtype}-${fn}.txt"

    # shellcheck disable=SC2016
    numbranch=$(wc -l "${PATCH_DIR}/branch-${origlog}-${testtype}-${fn}.txt" | ${AWK} '{print $1}')
    # shellcheck disable=SC2016
    numpatch=$(wc -l "${PATCH_DIR}/patch-${origlog}-${testtype}-${fn}.txt" | ${AWK} '{print $1}')

    calcdiffs \
      "${PATCH_DIR}/branch-${origlog}-${testtype}-${fn}.txt" \
      "${PATCH_DIR}/patch-${origlog}-${testtype}-${fn}.txt" \
      "${testtype}" \
      > "${PATCH_DIR}/diff-${origlog}-${testtype}-${fn}.txt"

    # shellcheck disable=SC2016
    addpatch=$(wc -l "${PATCH_DIR}/diff-${origlog}-${testtype}-${fn}.txt" | ${AWK} '{print $1}')

    ((fixedpatch=numbranch-numpatch+addpatch))

    statstring=$(generic_calcdiff_status "${numbranch}" "${numpatch}" "${addpatch}" )

    if [[ ${addpatch} -gt 0 ]]; then
      ((result = result + 1))
      module_status "${i}" -1 "diff-${origlog}-${testtype}-${fn}.txt" "${fn}${statusjdk} ${statstring}"
    elif [[ ${fixedpatch} -gt 0 ]]; then
      module_status "${i}" +1 "${MODULE_STATUS_LOG[${i}]}" "${fn}${statusjdk} ${statstring}"
      summarize=false
    fi
    ((i=i+1))
  done

  modules_messages patch "${testtype}" "${summarize}"
  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Generic post-patch handler
## @audience     public
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
## @param        origlog
## @param        testtype
## @param        multijdkmode
## @param        run commands
function generic_post_handler
{
  declare origlog=$1
  declare testtype=$2
  declare multijdkmode=$3
  declare need2run=$4
  declare i
  declare result=0
  declare fn
  declare -r savejavahome=${JAVA_HOME}
  declare jdk=""
  declare jdkindex=0
  declare statusjdk
  declare -i numbranch=0
  declare -i numpatch=0

  if ! verify_needed_test "${testtype}"; then
    yetus_debug "${testtype} not needed"
    return 0
  fi

  big_console_header "${testtype} verification: ${BUILDMODE}"

  for jdkindex in ${JDK_DIR_LIST}; do
    if [[ ${multijdkmode} == true ]]; then
      JAVA_HOME=${jdkindex}
      yetus_debug "Using ${JAVA_HOME} to run this set of tests"
    fi

    if [[ ${need2run} = true ]]; then
      personality_modules "${codebase}" "${testtype}"
      "${BUILDTOOL}_modules_worker" "${codebase}" "${testtype}"

      if [[ ${UNSUPPORTED_TEST} = true ]]; then
        return 0
      fi
    fi

    generic_postlog_compare "${origlog}" "${testtype}" "${multijdkmode}"
    ((result=result+$?))
  done
  JAVA_HOME=${savejavahome}

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Execute the compile phase. This will callout
## @description  to _compile
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        branch|patch
## @return       0 on success
## @return       1 on failure
function compile_jvm
{
  declare codebase=$1
  declare result=0
  declare -r savejavahome=${JAVA_HOME}
  declare multijdkmode
  declare jdkindex=0
  declare jdklist

  if verify_multijdk_test compile; then
    multijdkmode=true
    jdklist=${JDK_DIR_LIST}
  else
    multijdkmode=false
    jdklist=${JAVA_HOME}
  fi

  for jdkindex in ${jdklist}; do
    if [[ ${multijdkmode} == true ]]; then
      JAVA_HOME=${jdkindex}
    fi

    compile_nonjvm "${codebase}" "${multijdkmode}"

  done
  JAVA_HOME=${savejavahome}

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Execute the compile phase. This will callout
## @description  to _compile
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        branch|patch
## @return       0 on success
## @return       1 on failure
function compile_nonjvm
{
  declare codebase=$1
  declare result=0
  declare -r savejavahome=${JAVA_HOME}
  declare multijdkmode=${2:-false}
  declare jdkindex=0

  personality_modules "${codebase}" compile
  "${BUILDTOOL}_modules_worker" "${codebase}" compile
  modules_messages "${codebase}" compile true

  modules_backup

  for plugin in ${TESTTYPES}; do
    modules_restore
    verify_patchdir_still_exists
    if declare -f ${plugin}_compile >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_compile ${codebase} ${multijdkmode}"
      "${plugin}_compile" "${codebase}" "${multijdkmode}"
      ((result = result + $?))
      archive
    fi
  done

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Execute the compile phase. This will callout
## @description  to _compile
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        branch|patch
## @return       0 on success
## @return       1 on failure
function compile
{
  declare codebase=$1

  if ! verify_needed_test compile; then
     return 0
  fi

  if [[ ${codebase} = "branch" ]]; then
    big_console_header "${PATCH_BRANCH} compilation: pre-patch"
  else
    big_console_header "${PATCH_BRANCH} compilation: ${BUILDMODE}"
  fi

  yetus_debug "Is JVM Required? ${JVM_REQUIRED}"
  if [[ "${JVM_REQUIRED}" = true ]]; then
    compile_jvm "${codebase}"
  else
    compile_nonjvm "${codebase}"
  fi
}

## @description  Execute the static analysis test cycle.
## @description  This will callout to _precompile, compile, _postcompile and _rebuild
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        branch|patch
## @return       0 on success
## @return       1 on failure
function compile_cycle
{
  declare codebase=$1
  declare result=0
  declare plugin

  find_changed_modules "${codebase}"

  for plugin in ${PROJECT_NAME} ${BUILDTOOL} ${TESTTYPES} ${TESTFORMATS}; do
    if declare -f ${plugin}_precompile >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_precompile"
      #shellcheck disable=SC2086
      ${plugin}_precompile ${codebase}
      if [[ $? -gt 0 ]]; then
        ((result = result+1))
      fi
      archive
    fi
  done

  compile "${codebase}"

  for plugin in ${PROJECT_NAME} ${BUILDTOOL} ${TESTTYPES} ${TESTFORMATS}; do
    if declare -f ${plugin}_postcompile >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_postcompile"
      #shellcheck disable=SC2086
      ${plugin}_postcompile ${codebase}
      if [[ $? -gt 0 ]]; then
        ((result = result+1))
      fi
      archive
    fi
  done

  for plugin in ${PROJECT_NAME} ${BUILDTOOL} ${TESTTYPES} ${TESTFORMATS}; do
    if declare -f ${plugin}_rebuild >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_rebuild"
      #shellcheck disable=SC2086
      ${plugin}_rebuild ${codebase}
      if [[ $? -gt 0 ]]; then
        ((result = result+1))
      fi
      archive
    fi
  done

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Execute the patch file test phase. Calls out to
## @description  to _patchfile
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        branch|patch
## @return       0 on success
## @return       1 on failure
function patchfiletests
{
  declare plugin
  declare result=0

  for plugin in ${BUILDTOOL} ${TESTTYPES} ${TESTFORMATS}; do
    if declare -f ${plugin}_patchfile >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_patchfile"
      #shellcheck disable=SC2086
      ${plugin}_patchfile "${PATCH_DIR}/patch"
      if [[ $? -gt 0 ]]; then
        ((result = result+1))
      fi
      archive
    fi
  done

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}


## @description  Wipe the repo clean to not invalidate tests
## @audience     public
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function distclean
{
  declare result=0
  declare plugin

  big_console_header "Cleaning the source tree"

  for plugin in ${TESTTYPES} ${TESTFORMATS}; do
    if declare -f ${plugin}_clean >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_distclean"
      #shellcheck disable=SC2086
      ${plugin}_clean
      if [[ $? -gt 0 ]]; then
        ((result = result+1))
      fi
    fi
  done

  personality_modules branch distclean
  "${BUILDTOOL}_modules_worker" branch distclean
  (( result = result + $? ))

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}

## @description  Setup to execute
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        $@
## @return       0 on success
## @return       1 on failure
function initialize
{
  setup_defaults

  parse_args "$@"

  importplugins

  parse_args_plugins "$@"

  BUGCOMMENTS=${BUGCOMMENTS:-${BUGSYSTEMS}}
  if [[ ! ${BUGCOMMENTS} =~ console ]]; then
    BUGCOMMENTS="${BUGCOMMENTS} console"
  fi

  BUGLINECOMMENTS=${BUGLINECOMMENTS:-${BUGCOMMENTS}}

  # we need to do this BEFORE plugins initalize
  # because they may change what they do based upon
  # docker support
  # note that docker support still isn't guaranteed
  # to be working even after this is executed here!
  if declare -f docker_initialize >/dev/null; then
    docker_initialize
  fi

  plugins_initialize
  if [[ ${RESULT} != 0 ]]; then
    cleanup_and_exit 1
  fi

  echo "Modes: ${EXEC_MODES}"

  if [[ "${BUILDMODE}" = patch ]]; then
    locate_patch

    # from here on out, we'll be in ${BASEDIR} for cwd
    # plugins need to pushd/popd if they change.
    git_checkout

    determine_issue
    if [[ "${ISSUE}" == 'Unknown' ]]; then
      echo "Testing patch on ${PATCH_BRANCH}."
    else
      echo "Testing ${ISSUE} patch on ${PATCH_BRANCH}."
    fi

    patchfile_dryrun_driver "${PATCH_DIR}/patch"
    if [[ $? != 0 ]]; then
      ((RESULT = RESULT + 1))
      yetus_error "ERROR: ${PATCH_OR_ISSUE} does not apply to ${PATCH_BRANCH}."
      add_vote_table -1 patch "${PATCH_OR_ISSUE} does not apply to ${PATCH_BRANCH}. Rebase required? Wrong Branch? See ${PATCH_NAMING_RULE} for help."
      bugsystem_finalreport 1
      cleanup_and_exit 1
    fi

  else

    git_checkout

  fi

  find_changed_files

  # re-verify that our dockerfile is still there (branch switch, etc)
  # note that there is still a chance that docker mode will be
  # disabled from here. Plug-ins should plan appropriately!
  if declare -f docker_fileverify >/dev/null; then
    docker_fileverify
  fi

  check_reexec

  determine_needed_tests

  prepopulate_footer
}

## @description perform prechecks
## @audience private
## @stability evolving
## @return   exits on failure
function prechecks
{
  declare plugin
  declare result=0

  for plugin in ${BUILDTOOL} ${NEEDED_TESTS} ${TESTFORMATS}; do
    verify_patchdir_still_exists

    if declare -f ${plugin}_precheck >/dev/null 2>&1; then

      yetus_debug "Running ${plugin}_precheck"
      #shellcheck disable=SC2086
      ${plugin}_precheck

      (( result = result + $? ))
      if [[ ${result} != 0 ]] ; then
        bugsystem_finalreport 1
        cleanup_and_exit 1
      fi
    fi
  done
}

## @description import core library routines
## @audience private
## @stability evolving
function import_core
{
  declare filename

  for filename in "${BINDIR}/core.d"/*; do
    # shellcheck disable=SC1091
    # shellcheck source=core.d/00-yetuslib.sh
    # shellcheck source=core.d/01-common.sh
    . "${filename}"
  done
}

###############################################################################
###############################################################################
###############################################################################

import_core

if [[ "${BINNAME}" =~ qbt ]]; then
  initialize --empty-patch "$@"
else
  initialize "$@"
fi

prechecks

if [[ "${BUILDMODE}" = patch ]]; then
  patchfiletests

  compile_cycle branch

  distclean

  apply_patch_file

  compute_gitdiff
fi

compile_cycle patch

runtests

finish_vote_table

finish_footer_table

bugsystem_finalreport ${RESULT}
cleanup_and_exit ${RESULT}
