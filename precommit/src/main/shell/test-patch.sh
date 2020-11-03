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
  GLOBALTIMER=$("${AWK}" 'BEGIN {srand(); print srand()}')
  # shellcheck disable=SC2034
  ISODATESTART=$(date +"%Y-%m-%dT%H:%M:%SZ")

  set_yetus_version

  #shellcheck disable=SC2153
  if [[ ${VERSION} =~ SNAPSHOT$ ]]; then
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

  CONTINUOUS_IMPROVEMENT=false

  PROC_LIMIT=1000
  REEXECED=false
  RESETREPO=false
  REPORT_UNKNOWN_OPTIONS=true
  BUILDMODE=${BUILDMODE:-patch}
  # shellcheck disable=SC2034
  BUILDMODEMSG=${BUILDMODEMSG:-"The patch"}
  ISSUE=${ISSUE:-""}
  TIMER=$("${AWK}" 'BEGIN {srand(); print srand()}')
  JVM_REQUIRED=true
  yetus_add_array_element JDK_TEST_LIST compile
  yetus_add_array_element JDK_TEST_LIST unit
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
  TIMER=$(yetus_get_ctime)
}

## @description  Print the elapsed time in seconds since the start of the local timer
## @audience     public
## @stability    stable
## @replaceable  no
function stop_clock
{
  local -r stoptime=$(yetus_get_ctime)
  local -r elapsed=$((stoptime-TIMER))

  echo ${elapsed}
}

## @description  Print the elapsed time in seconds since the start of the global timer
## @audience     private
## @stability    stable
## @replaceable  no
function stop_global_clock
{
  local -r stoptime=$(yetus_get_ctime)
  local -r elapsed=$((stoptime-GLOBALTIMER))
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
## @description  if the vote is H, then that designates that "subsystem" should be a
## @description  header in the vote table comment output. The other parameters are
## @description  ignored
## @audience     public
## @stability    stable
## @replaceable  no
## @param        +1/0/-1/H
## @param        subsystem
## @param        logfile
## @param        string
function add_vote_table_v2
{
  declare value=$1
  declare subsystem=$2
  declare logfile=$3
  shift 3

  # apparently shellcheck doesn't know about declare -r
  #shellcheck disable=SC2155
  declare -r elapsed=$(stop_clock)
  declare filt

  yetus_debug "add_vote_table_v2 >${value}< >${subsystem}< >${logfile}< >${elapsed}< ${*}"

  if [[ "${value}" = H ]]; then
    TP_VOTE_TABLE[${TP_VOTE_COUNTER}]="|${value}| | | | ${subsystem} |"
    ((TP_VOTE_COUNTER=TP_VOTE_COUNTER+1))
    return
  fi

  if [[ ${value} == "1" ]]; then
    value="+1"
  fi

  for filt in "${VOTE_FILTER[@]}"; do
    if [[ "${subsystem}" == "${filt}" && "${value}" == -1 ]]; then
      value=-0
    fi
  done

  # shellcheck disable=SC2034
  TP_VOTE_TABLE[${TP_VOTE_COUNTER}]="| ${value} | ${subsystem} | ${elapsed} | ${logfile} | $* |"
  ((TP_VOTE_COUNTER=TP_VOTE_COUNTER+1))

  if [[ "${value}" = -1 ]]; then
    ((RESULT = RESULT + 1))
  fi
}

## @description  Deprecated. Use add_vote_table_v2 instead.
## @audience     public
## @stability    stable
## @replaceable  no
function add_vote_table
{
  declare param1=$1
  declare param2=$2
  shift 2
  add_vote_table_v2 "${param1}" "${param2}" "" "$@"
}

## @description  Report the JVM vendor and version of the given directory
## @stability    stable
## @audience     private
## @replaceable  yes
## @param        directory
## @return       vendor and version string
function report_jvm_version
{
  local properties
  local vendor
  local version

  properties="$("${1}/bin/java" -XshowSettings:properties -version 2>&1)"
  #shellcheck disable=SC2016 # shellcheck cannot see through "${AWK}"
  vendor="$(echo "${properties}" | "${GREP}" java.vendor | head -1 | "${AWK}" 'BEGIN {FS = " = "} ; {print $NF}')"
  #shellcheck disable=SC2016 # shellcheck cannot see through "${AWK}"
  version="$(echo "${properties}" | "${GREP}" java.runtime.version | head -1 | "${AWK}" 'BEGIN {FS = " = "} ; {print $NF}')"
  echo "${vendor}-${version}"
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

  if [[ "${#JDK_DIR_LIST[@]}" -lt 2 ]] ; then
    yetus_debug "MultiJDK not configured."
    return 1
  fi

  if yetus_ver_array_element JDK_TEST_LIST "${i}"; then
    yetus_debug "${i} is in JDK_TEST_LIST and MultiJDK configured."
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

  add_footer_table "git revision" "${PATCH_BRANCH} / ${GIT_BRANCH_SHA}"
}

## @description  Last minute entries on the footer table
## @audience     private
## @stability    stable
## @replaceable  no
function finish_footer_table
{
  declare counter

  if [[ -f "${PATCH_DIR}/threadcounter.txt" ]]; then
    counter=$(cat "${PATCH_DIR}/threadcounter.txt")
    add_footer_table "Max. process+thread count" "${counter} (vs. ulimit of ${PROC_LIMIT})"
  fi

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

  if [[ "${ROBOTTYPE}" == 'githubactions' ]]; then
    echo "::endgroup::"
    echo "::group::${text}"
  fi

  printf '\n\n'
  echo "============================================================================"
  echo "============================================================================"
  printf '%*s\n'  ${spacing} "${text}"
  echo "============================================================================"
  echo "============================================================================"
  printf '\n\n'
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
    if declare -f "${bug}_write_comment" >/dev/null; then
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

  if [[ ! -d ${PATCH_DIR} ]]; then
    rm "${commentfile}" 2>/dev/null

    echo "(!) The patch artifact directory has been removed! " > "${commentfile}"
    echo "This is a fatal error for test-patch.sh.  Aborting. " >> "${commentfile}"
    echo
    cat ${commentfile}
    echo
    if [[ ${ROBOT} == true ]]; then
      if declare -f "${ROBOTTYPE}"_verify_patchdir >/dev/null; then
        "${ROBOTTYPE}"_verify_patchdir "${commentfile}"
      fi

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

  pushd "${BASEDIR}" >/dev/null || return 1
  "${GIT}" add --all --intent-to-add
  while read -r line; do
    if [[ ${line} =~ ^\+\+\+ ]]; then
      file=$(echo "${line}" | cut -f2- -d/)
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
      # https://unix.stackexchange.com/questions/47407/cat-line-x-to-line-y-on-a-huge-file
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
          printf '%s:%s:%s\n' "${file}" "${actual}" "${content}" >> "${GITDIFFCONTENT}"
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

  popd >/dev/null || return 1
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
  declare logfile=$1
  shift

  verify_patchdir_still_exists

  find "${BASEDIR}" -type d -exec chmod +x {} \;
  # to the screen
  echo "cd $(pwd)"
  echo "${*} > ${logfile} 2>&1"

  if [[ ${BASH_VERSINFO[0]} -gt 3 ]]; then

    # use a coprocessor with the
    # lower proc limit so that yetus can
    # do stuff unimpacted by it

    e_a_r_helper "${logfile}" "${@}" >> "${COPROC_LOGFILE}" 2>&1

    # now that it's off as a separate process, we need to wait
    # for it to finish. wait will either return 0, exit code
    # of the coproc, or 127. all of which is
    # perfectly fine for us.


    # shellcheck disable=SC2154,SC2086
    wait ${yrr_coproc_PID}

  else

    # if bash < 4 (e.g., OS X), just run it
    # the ulimit was set earlier

    yetus_run_and_redirect "${logfile}" "${@}"
  fi
}

## @description  Print the usage information
## @audience     public
## @stability    stable
## @replaceable  no
function yetus_usage
{
  declare bugsys
  declare jdktlist
  declare buildtools

  importplugins

  bugsys=$(yetus_array_to_comma BUGSYSTEMS )
  jdktlist=$(yetus_array_to_comma JDK_TEST_LIST )
  buildtools=$(yetus_array_to_comma BUILDTOOLS )

  bugsys=${bugsys:-"None: no plugins enabled"}
  jdktlist=${jdktlist:-"None: no plugins enabled"}
  buildtools=${buildtools:-"None: no plugins enabled"}

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
  yetus_add_option "--basedir=<dir>" "The directory to apply the patch to (default: current directory)"
  yetus_add_option "--branch-default=<ref>" "If the branch isn't forced and we don't detect one in the patch name, use this branch (default 'main')"
  yetus_add_option "--branch=<ref>" "Forcibly set the branch"
  yetus_add_option "--bugcomments=<bug>" "Only write comments to the screen and this comma delimited list (default: '${bugsys}')"
  yetus_add_option "--build-native=<bool>" "If true, then build native components (default 'true')"
  yetus_add_option "--build-tool=<tool>" "Pick which build tool to focus around (default: autodetect from '${buildtools}')"
  yetus_add_option "--continuous-improvement=<bool>" "If true, then do not exit with failure on branches (default: ${CONTINUOUS_IMPROVEMENT})"
  yetus_add_option "--contrib-guide=<url>" "URL to point new users towards project conventions. (default: ${PATCH_NAMING_RULE} )"
  yetus_add_option "--debug" "If set, then output some extra stuff to stderr"
  yetus_add_option "--dirty-workspace" "Allow the local git workspace to have uncommitted changes"
  yetus_add_option "--empty-patch" "Create a summary of the current source tree"
  yetus_add_option "--excludes=<file>" "File of regexs to keep project files out of the set of changes passed to plugins."
  yetus_add_option "--git-offline" "Do not fail if git cannot do certain remote operations"
  yetus_add_option "--git-shallow" "Repo does not know about other branches or tags"
  yetus_add_option "--ignore-unknown-options=<bool>" "Continue despite unknown options (default: ${IGNORE_UNKNOWN_OPTIONS})"
  yetus_add_option "--java-home=<path>" "Set JAVA_HOME (In Docker mode, this should be local to the image)"
  yetus_add_option "--linecomments=<bug>" "Only write line comments to this comma delimited list (default: same as --bugcomments)"
  yetus_add_option "--list-plugins" "List all installed plug-ins and then exit"
  yetus_add_option "--modulelist=<list>" "Specify additional modules to test (comma delimited)"
  yetus_add_option "--multijdkdirs=<paths>" "Comma delimited lists of JDK paths to use for multi-JDK tests"
  yetus_add_option "--multijdktests=<list>" "Comma delimited tests to use when multijdkdirs is used. (default: '${jdktlist}')"
  yetus_add_option "--offline" "Avoid connecting to the network"
  yetus_add_option "--patch-dir=<dir>" "The directory for working and output files (default '/tmp/test-patch-${PROJECT_NAME}/pid')"
  yetus_add_option "--personality=<file>" "The personality file to load"
  yetus_add_option "--plugins=<list>" "Specify which plug-ins to add/delete (comma delimited; use 'all' for all found) e.g. --plugins=all,-ant,-scalac (all plugins except ant and scalac)"
  yetus_add_option "--proclimit=<num>" "Limit on the number of processes (default: ${PROC_LIMIT})"
  yetus_add_option "--project=<name>" "The short name for project currently using test-patch (default 'yetus')"
  yetus_add_option "--report-unknown-options=<bool>" "Print a warning in the report if --ignore-unknown-options=true and unknown options were found (default: ${REPORT_UNKNOWN_OPTIONS})"
  yetus_add_option "--resetrepo" "Forcibly clean the repo"
  yetus_add_option "--run-tests" "Run all relevant tests below the base directory"
  yetus_add_option "--skip-dirs=<list>" "Skip following directories for module finding"
  yetus_add_option "--skip-system-plugins" "Do not load plugins from ${BINDIR}/test-patch.d"
  yetus_add_option "--summarize=<bool>" "Allow tests to summarize results"
  yetus_add_option "--test-parallel=<bool>" "Run multiple tests in parallel (default false in developer mode, true in Jenkins mode)"
  yetus_add_option "--test-threads=<int>" "Number of tests to run in parallel (default defined in ${PROJECT_NAME} build)"
  yetus_add_option "--tests-filter=<list>" "Lists of tests to turn failures into warnings"
  yetus_add_option "--unit-test-filter-file=<file>" "The unit test filter file to load"
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
  yetus_add_option "--build-url-artifacts=<location>" "Location relative to --build-url of the --patch-dir (Default: '${BUILD_URL_ARTIFACTS}')"
  yetus_add_option "--build-url-console=<location>" "Location relative to --build-url of the console (Default: '${BUILD_URL_CONSOLE}')"
  yetus_add_option "--build-url=<url>" "Set the build location web page (Default: '${BUILD_URL}')"
  yetus_add_option "--console-report-file=<file>" "Save the final console-based report to a file in addition to the screen"
  yetus_add_option "--console-urls" "Use the build URL instead of path on the console report"
  yetus_add_option "--instance=<string>" "Parallel execution identifier string"
  yetus_add_option "--mv-patch-dir" "Move the patch-dir into the basedir during cleanup"
  yetus_add_option "--robot" "Assume this is an automated run (default: auto-detect supported CI system)"
  yetus_add_option "--sentinel" "A very aggressive robot (auto: --robot)"

  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage


  echo ""
  echo "Docker options:"
  docker_usage
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage

  echo ""
  echo "Reaper options:"
  reaper_usage
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage

  # shellcheck disable=SC2153
  for plugin in "${BUILDTOOLS[@]}" "${TESTTYPES[@]}" "${BUGSYSTEMS[@]}" "${TESTFORMATS[@]}"; do
    if declare -f "${plugin}_usage" >/dev/null 2>&1; then
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
        delete_parameter "${i}"
        yetus_comma_to_array ARCHIVE_LIST "${i#*=}"
        yetus_debug "Set to archive: ${ARCHIVE_LIST[*]}"
      ;;
      --bugcomments=*)
        delete_parameter "${i}"
        BUGCOMMENTS=${i#*=}
        BUGCOMMENTS=${BUGCOMMENTS//,/ }
      ;;
      --build-native=*)
        delete_parameter "${i}"
        BUILD_NATIVE=${i#*=}
      ;;
      --build-tool=*)
        delete_parameter "${i}"
        BUILDTOOL=${i#*=}
      ;;
      --build-url=*)
        delete_parameter "${i}"
        BUILD_URL=${i#*=}
      ;;
      --build-url-artifacts=*)
        delete_parameter "${i}"
        # shellcheck disable=SC2034
        BUILD_URL_ARTIFACTS=${i#*=}
      ;;
      --build-url-console=*)
        delete_parameter "${i}"
        # shellcheck disable=SC2034
        BUILD_URL_CONSOLE=${i#*=}
      ;;
      --console-report-file=*)
        delete_parameter "${i}"
        CONSOLE_REPORT_FILE=${i#*=}
      ;;
      --console-urls)
        delete_parameter "${i}"
        # shellcheck disable=SC2034
        CONSOLE_USE_BUILD_URL=true
      ;;
      --contrib-guide=*)
        delete_parameter "${i}"
        PATCH_NAMING_RULE=${i#*=}
      ;;
      --continuous-improvement=*)
        delete_parameter "${i}"
        CONTINUOUS_IMPROVEMENT=${i#*=}
      ;;
      --dirty-workspace)
        delete_parameter "${i}"
        DIRTY_WORKSPACE=true
      ;;
      --excludes=*)
        delete_parameter "${i}"
        EXCLUDE_PATHS_FILE="${i#*=}"
      ;;
      --instance=*)
        delete_parameter "${i}"
        INSTANCE=${i#*=}
      ;;
      --empty-patch)
        delete_parameter "${i}"
        BUILDMODE=full
      ;;
      --java-home=*)
        delete_parameter "${i}"
        JAVA_HOME=${i#*=}
      ;;
      --linecomments=*)
        delete_parameter "${i}"
        BUGLINECOMMENTS=${i#*=}
        BUGLINECOMMENTS=${BUGLINECOMMENTS//,/ }
        if [[ -z "${BUGLINECOMMENTS}" ]]; then
          BUGLINECOMMENTS=" "
        fi
      ;;
      --modulelist=*)
        delete_parameter "${i}"
        yetus_comma_to_array USER_MODULE_LIST "${i#*=}"
        yetus_debug "Manually forcing modules ${USER_MODULE_LIST[*]}"
      ;;
      --multijdkdirs=*)
        delete_parameter "${i}"
        yetus_comma_to_array JDK_DIR_LIST "${i#*=}"
        yetus_debug "Multi-JDK mode activated with ${JDK_DIR_LIST[*]}"
        yetus_add_array_element EXEC_MODES MultiJDK
      ;;
      --multijdktests=*)
        delete_parameter "${i}"
        yetus_comma_to_array JDK_TEST_LIST "${i#*=}"
        yetus_debug "MultiJDK test list=${JDK_TEST_LIST[*]}"
      ;;
      --mv-patch-dir)
        delete_parameter "${i}"
        RELOCATE_PATCH_DIR=true;
      ;;
      --personality=*)
        delete_parameter "${i}"
        PERSONALITY=${i#*=}
      ;;
      --proclimit=*)
        delete_parameter "${i}"
        PROC_LIMIT=${i#*=}
      ;;
      --reexec)
        delete_parameter "${i}"
        REEXECED=true
      ;;
      --resetrepo)
        delete_parameter "${i}"
        RESETREPO=true
      ;;
      --robot)
        delete_parameter "${i}"
        ROBOT=true
      ;;
      --run-tests)
        delete_parameter "${i}"
        RUN_TESTS=true
      ;;
      --sentinel)
        delete_parameter "${i}"
        # shellcheck disable=SC2034
        ROBOT=true
        # shellcheck disable=SC2034
        SENTINEL=true
        yetus_add_array_element EXEC_MODES Sentinel
      ;;
      --skip-dirs=*)
        delete_parameter "${i}"
        MODULE_SKIPDIRS=${i#*=}
        MODULE_SKIPDIRS=${MODULE_SKIPDIRS//,/ }
        yetus_debug "Setting skipdirs to ${MODULE_SKIPDIRS}"
      ;;
      --summarize=*)
        delete_parameter "${i}"
        ALLOWSUMMARIES=${i#*=}
      ;;
      --test-parallel=*)
        delete_parameter "${i}"
        # shellcheck disable=SC2034
        TEST_PARALLEL=${i#*=}
      ;;
      --test-threads=*)
        delete_parameter "${i}"
        # shellcheck disable=SC2034
        TEST_THREADS=${i#*=}
      ;;
      --unit-test-filter-file=*)
        delete_parameter "${i}"
        UNIT_TEST_FILTER_FILE=${i#*=}
      ;;
      --tests-filter=*)
        delete_parameter "${i}"
        yetus_comma_to_array VOTE_FILTER "${i#*=}"
      ;;
      --tpglobaltimer=*)
        delete_parameter "${i}"
        GLOBALTIMER=${i#*=}
      ;;
      --tpinstance=*)
        delete_parameter "${i}"
        INSTANCE=${i#*=}
      ;;
      --tpperson=*)
        delete_parameter "${i}"
        REEXECPERSONALITY=${i#*=}
      ;;
      --tpreexectimer=*)
        delete_parameter "${i}"
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

  reaper_parse_args "$@"

  if [[ -z "${PATCH_OR_ISSUE}"
       && "${BUILDMODE}" = patch ]]; then
    yetus_error "ERROR: No patch given."
    yetus_usage
    exit 1
  fi

  set_buildmode

  if [[ ${ROBOT} = true ]]; then
    # shellcheck disable=SC2034
    TEST_PARALLEL=true
    RESETREPO=true
    RUN_TESTS=true
    ISSUE=${PATCH_OR_ISSUE}
    yetus_add_array_element EXEC_MODES Robot
  fi

  if [[ -n $UNIT_TEST_FILTER_FILE ]]; then
    if [[ -f $UNIT_TEST_FILTER_FILE ]]; then
      UNIT_TEST_FILTER_FILE=$(yetus_abs "${UNIT_TEST_FILTER_FILE}")
    else
      yetus_error "ERROR: Unit test filter file (${UNIT_TEST_FILTER_FILE}) does not exist!"
      cleanup_and_exit 1
    fi
  fi

  if [[ -n ${REEXECLAUNCHTIMER} ]]; then
    TIMER=${REEXECLAUNCHTIMER};
  else
    start_clock
  fi

  if [[ "${DOCKERMODE}" = true || "${DOCKERSUPPORT}" = true ]]; then
    if [[ "${DOCKER_DESTRCUTIVE}" = true ]]; then
      yetus_add_array_element EXEC_MODES DestructiveDocker
    else
      yetus_add_array_element EXEC_MODES Docker
    fi
    add_vote_table_v2 0 reexec "" "Docker mode activated."
    start_clock
  elif [[ "${REEXECED}" = true ]]; then
    yetus_add_array_element EXEC_MODES Re-exec
    add_vote_table_v2 0 reexec "" "Precommit patch detected."
    start_clock
  fi

  # we need absolute dir for ${BASEDIR}
  cd "${STARTINGDIR}" || cleanup_and_exit 1
  BASEDIR=$(yetus_abs "${BASEDIR}")

  if [[ -z "${PERSONALITY}" ]] && [[ -f "${BASEDIR}/.yetus/personality.sh" ]]; then
    PERSONALITY="${BASEDIR}/.yetus/personality.sh"
  fi

  if [[ -n ${USER_PATCH_DIR} ]]; then
    PATCH_DIR="${USER_PATCH_DIR}"
  fi

  # we need absolute dir for PATCH_DIR
  cd "${STARTINGDIR}" || cleanup_and_exit 1
  if [[ ! -d ${PATCH_DIR} ]]; then
    if mkdir -p "${PATCH_DIR}"; then
      echo "${PATCH_DIR} has been created"
    else
      echo "Unable to create ${PATCH_DIR}"
      cleanup_and_exit 1
    fi
  fi
  PATCH_DIR=$(yetus_abs "${PATCH_DIR}")
  COPROC_LOGFILE="${PATCH_DIR}/coprocessors.txt"

  if [[ -n "${EXCLUDE_PATHS_FILE}" ]]; then
    # shellcheck disable=SC2034
    EXCLUDE_PATHS_FILE_SAVEOFF=${EXCLUDE_PATHS_FILE}
    if [[ -f "${EXCLUDE_PATHS_FILE}" ]]; then
      EXCLUDE_PATHS_FILE=$(yetus_abs "${EXCLUDE_PATHS_FILE}")
    elif [[ -f "${BASEDIR}/${EXCLUDE_PATHS_FILE}" ]]; then
      EXCLUDE_PATHS_FILE=$(yetus_abs "${BASEDIR}/${EXCLUDE_PATHS_FILE}")
    else
      yetus_error "WARNING: Excluded paths file (${EXCLUDE_PATHS_FILE}}) does not exist (yet?)."
      unset EXCLUDE_PATHS_FILE
    fi
  fi

  # we need absolute dir for ${CONSOLE_REPORT_FILE}
  if [[ -n "${CONSOLE_REPORT_FILE}" ]]; then
    if : > "${CONSOLE_REPORT_FILE}"; then
      CONSOLE_REPORT_FILE_ORIG="${CONSOLE_REPORT_FILE}"
      CONSOLE_REPORT_FILE=$(yetus_abs "${CONSOLE_REPORT_FILE_ORIG}")
    else
      yetus_error "ERROR: cannot write to ${CONSOLE_REPORT_FILE}. Disabling console report file."
      unset CONSOLE_REPORT_FILE
    fi
  fi

  if [[ ${RESETREPO} == "true" ]] ; then
    yetus_add_array_element EXEC_MODES ResetRepo
  fi

  if [[ ${RUN_TESTS} == "true" ]] ; then
    yetus_add_array_element EXEC_MODES UnitTests
  fi

  if [[ -n "${USER_PLUGIN_DIR}" ]]; then
    USER_PLUGIN_DIR=$(yetus_abs "${USER_PLUGIN_DIR}")
  elif [[ -d "${BASEDIR}/.yetus/plugins" ]]; then
    USER_PLUGIN_DIR="${BASEDIR}/.yetus/plugins"
  fi

  GITDIFFLINES="${PATCH_DIR}/gitdifflines.txt"
  GITDIFFCONTENT="${PATCH_DIR}/gitdiffcontent.txt"

  if [[ "${REEXECED}" = true
     && -f "${PATCH_DIR}/precommit/personality/provided.sh" ]]; then
    PERSONALITY="${PATCH_DIR}/precommit/personality/provided.sh"
  fi
}

## @description  Switch BUILDMODE. Callers are responsible for setting
## @description  the appropriate vars.  Use with caution.
## @audience     private
## @stability    evolving
## @replaceable  no
function set_buildmode
{
  # if both a patch and --empty-patch has been set, a choice needs
  # to be made.  If our exec is called qbt, then go full.
  # otherwise, defer to the patch
  if [[ -n "${PATCH_OR_ISSUE}" && "${BUILDMODE}" == full ]]; then
    if [[ "${BINNAME}" =~ qbt ]]; then
      BUILDMODE="full"
    else
      BUILDMODE="patch"
    fi
  fi

  if [[ "${BUILDMODE}" == full ]]; then
    # shellcheck disable=SC2034
    BUILDMODEMSG="The source tree"
  else
    BUILDMODEMSG="The patch"
  fi
}

## @description  check if repo requires creds to do remote operations
## @description  also sets and uses GIT_OFFLINE as appropriate
## @audience     private
## @stability    stable
## @replaceable  no
## @return       0 = no
## @return       1 = yes
function git_requires_creds
{
  declare status

  if [[ "${GIT_OFFLINE}" == true ]]; then
    return 1
  fi

  pushd "${BASEDIR}" >/dev/null || cleanup_and_exit 1

  if ! "${GIT}" fetch --dry-run >/dev/null 2>&1; then
    GIT_OFFLINE=true
    return 1
  fi

  popd >/dev/null || cleanup_and_exit 1
  GIT_OFFLINE=false
  return 0
}

## @description  git clean the repository
## @audience     public
## @stability    stable
## @replaceable  no
## @return       0 on success
function git_clean
{
  declare exemptdir

  if [[ ${RESETREPO} == "true" ]]; then
    # if PATCH_DIR is in BASEDIR, then we don't want
    # git wiping it out.
    exemptdir=$(yetus_relative_dir "${BASEDIR}" "${PATCH_DIR}")
    if [[ $? == 1 ]]; then
      "${GIT}" clean -xdf
    else
      # we do, however, want it emptied of all _files_.
      # we need to leave _directories_ in case we are in
      # re-exec mode (which places a directory full of stuff in it)
      yetus_debug "Exempting ${exemptdir} from clean"
      "${GIT}" clean -xdf -e "${exemptdir}"
    fi
  fi
}

## @description  Forcibly reset the tree back to it's original state
## @audience     public
## @stability    stable
## @replaceable  no
## @return       0 on success
function git_checkout_force
{
  declare exemptdir

  if [[ ${RESETREPO} == "true" ]]; then
    git_clean && "${GIT}" checkout --force "${PATCH_BRANCH}"
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
  declare currentbranch
  declare exemptdir
  declare status

  big_console_header "Confirming git environment"

  # if this still hasn't been set by now, set it.
  PATCH_BRANCH_DEFAULT=${PATCH_BRANCH_DEFAULT:="main"}

  git_requires_creds

  if [[ ${ROBOT} == true ]]; then
    if declare -f "${ROBOTTYPE}"_pre_git_checkout >/dev/null; then
      "${ROBOTTYPE}"_pre_git_checkout
    fi
  fi

  cd "${BASEDIR}" || cleanup_and_exit 1
  if [[ ! -e .git ]]; then
    yetus_error "ERROR: ${BASEDIR} is not a git repo."
    cleanup_and_exit 1
  fi

  if [[ ${RESETREPO} == "true" ]] ; then

    if [[ -d .git/rebase-apply ]]; then
      yetus_error "ERROR: a previous rebase failed. Aborting it."
      "${GIT}" rebase --abort
    fi

    if ! "${GIT}" reset --hard; then
      yetus_error "ERROR: git reset is failing"
      cleanup_and_exit 1
    fi

    if ! git_clean; then
      yetus_error "ERROR: git clean is failing"
      cleanup_and_exit 1
    fi

    # if PATCH_DIR is in BASEDIR, then we don't want
    # git wiping it out.
    if yetus_relative_dir "${BASEDIR}" "${PATCH_DIR}" >/dev/null; then
      # we need to empty out PATCH_DIR, but
      # leave _directories_ in case we are in
      # re-exec mode (which places a directory full of stuff in it)
      yetus_debug "Exempting ${exemptdir} from clean"
      rm "${PATCH_DIR}/*" 2>/dev/null
    fi

    if [[ "${GIT_SHALLOW}" == false ]]; then
      if ! "${GIT}" checkout --force "${PATCH_BRANCH_DEFAULT}"; then
        yetus_error "WARNING: git checkout --force ${PATCH_BRANCH_DEFAULT} is failing; assuming shallow"
        GIT_SHALLOW=true
      fi
    fi

    determine_branch

    # we need to explicitly fetch in case the
    # git ref hasn't been brought in tree yet
    if [[ ${GIT_OFFLINE} == false ]]; then
      if ! "${GIT}" pull --rebase --tags --force; then
          yetus_error "ERROR: git pull is failing"
          cleanup_and_exit 1
      fi
    fi

    if [[ ${GIT_SHALLOW} == false ]]; then
      # forcibly checkout this branch or git ref
      if ! "${GIT}" checkout --force "${PATCH_BRANCH}"; then
        yetus_error "ERROR: git checkout ${PATCH_BRANCH} is failing"
        cleanup_and_exit 1
      fi
    fi

    # if we've selected a feature branch that has new changes
    # since our last build, we'll need to reset to the latest FETCH_HEAD.
    if [[ ${OFFLINE} == false ]]; then

      # previous clause where GIT_OFFLINE would get set is also
      # protected by OFFLINE == false

      if [[ "${GIT_OFFLINE}" == false ]]; then

        # if it is a tag, then the pull rebase should have done
        # the trick already
        if [[ ! -f ".git/refs/tags/${PATCH_BRANCH}" ]]; then
          if ! "${GIT}" fetch; then
            yetus_error "ERROR: git fetch is failing"
            cleanup_and_exit 1
          fi

          if ! "${GIT}" reset --hard FETCH_HEAD; then
            yetus_error "ERROR: git reset is failing"
            cleanup_and_exit 1
          fi
        fi
      fi

      if ! git_clean; then
        yetus_error "ERROR: git clean is failing"
        cleanup_and_exit 1
      fi
    fi

  else

    status=$("${GIT}" status --porcelain)
    if [[ "${status}" != "" && -z ${DIRTY_WORKSPACE} ]] ; then
      yetus_error "ERROR: --dirty-workspace option not provided."
      yetus_error "ERROR: can't run in a workspace that contains the following modifications"
      yetus_error "${status}"
      cleanup_and_exit 1
    fi

    determine_branch

    currentbranch=$("${GIT}" rev-parse --abbrev-ref HEAD)
    if [[ "${currentbranch}" != "${PATCH_BRANCH}" ]];then
      if [[ "${BUILDMODE}" = patch ]]; then
        echo "WARNING: Current git branch is ${currentbranch} but patch is built for ${PATCH_BRANCH}."
        echo "WARNING: Continuing anyway..."
      fi
      PATCH_BRANCH=${currentbranch}
    fi
  fi

  if [[ -z "${GIT_BRANCH_SHA}" ]]; then
    GIT_BRANCH_SHA=$("${GIT}" log -1 --format="%H")
  fi

  return 0
}

## @description  Confirm the given branch is a git reference
## @description  or a valid gitXYZ commit hash
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
      if "${GIT}" cat-file -t "${hash}" >/dev/null 2>&1; then
        PATCH_BRANCH=${hash}
        return 0
      fi
      return 1
    else
      return 1
    fi
  fi

  "${GIT}" show-ref "${check}" >/dev/null 2>&1
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

  pushd "${BASEDIR}" > /dev/null || return 1

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

  for bugs in "${BUGSYSTEMS[@]}"; do
    if declare -f "${bugs}_determine_branch" >/dev/null;then
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
  popd >/dev/null || return 1
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

  for bugsys in "${BUGSYSTEMS[@]}"; do
    if declare -f "${bugsys}_determine_issue" >/dev/null; then
      if "${bugsys}_determine_issue" "${PATCH_OR_ISSUE}"; then
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

  exclude_paths_from_changed_files

  for i in "${CHANGED_FILES[@]}"; do
    yetus_debug "Determining needed tests for ${i}"
    personality_file_tests "${i}"

    for plugin in "${TESTTYPES[@]}" ${BUILDTOOL}; do
      if declare -f "${plugin}_filefilter" >/dev/null 2>&1; then
        "${plugin}_filefilter" "${i}"
      fi
    done
  done

  add_footer_table "Optional Tests" "${NEEDED_TESTS[*]}"
}

## @description  Given ${INPUT_APPLIED_FILE}, actually apply the patch
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       exit on failure
function apply_patch_file
{

  if [[ "${INPUT_APPLIED_FILE}" ==  "${INPUT_DIFF_FILE}" ]]; then
    add_vote_table_v2 '-0' patch "" "Used diff version of patch file. Binary files and potentially other changes not applied. Please rebase and squash commits if necessary."
    big_console_header "Applying diff to ${PATCH_BRANCH}"
  else
    big_console_header "Applying patch to ${PATCH_BRANCH}"
  fi

  if ! patchfile_apply_driver "${INPUT_APPLIED_FILE}"; then
    echo "PATCH APPLICATION FAILED"
    ((RESULT = RESULT + 1))
    add_vote_table_v2 -1 patch "" "${PATCH_OR_ISSUE} does not apply to ${PATCH_BRANCH}. Rebase required? Wrong Branch? See ${PATCH_NAMING_RULE} for help."
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
  # we need to copy/consolidate all the bits that might have changed
  # that are considered part of test-patch.  This *might* break
  # things that do off-path includes, but there isn't much we can
  # do about that, I don't think.

  # if we've already copied, then don't bother doing it again
  if [[ ${STARTINGDIR} == ${PATCH_DIR}/precommit ]]; then
    yetus_debug "Skipping copytpbits; already copied once"
    return
  fi

  pushd "${STARTINGDIR}" >/dev/null || return 1
  mkdir -p "${PATCH_DIR}/precommit/user-plugins"
  mkdir -p "${PATCH_DIR}/precommit/personality"
  mkdir -p "${PATCH_DIR}/precommit/test-patch-docker"

  # copy our entire universe, preserving links, etc.
  yetus_debug "copying '${BINDIR}' over to '${PATCH_DIR}/precommit'"
  # shellcheck disable=SC2164
  (cd "${BINDIR}"; tar cpf - . ) | (cd "${PATCH_DIR}/precommit"; tar xpf - )

  echo "${VERSION}" > "${PATCH_DIR}/precommit/VERSION"

  if [[ -n "${USER_PLUGIN_DIR}"
    && -d "${USER_PLUGIN_DIR}"  ]]; then
    yetus_debug "copying '${USER_PLUGIN_DIR}' over to ${PATCH_DIR}/precommit/user-plugins"
    cp -pr "${USER_PLUGIN_DIR}"/. \
      "${PATCH_DIR}/precommit/user-plugins"
  fi
  # Set to be relative to ${PATCH_DIR}/precommit
  USER_PLUGIN_DIR="${PATCH_DIR}/precommit/user-plugins"

  if [[ -n ${EXCLUDE_PATHS_FILE}
    && -f ${EXCLUDE_PATHS_FILE} ]]; then
    yetus_debug "copying '${EXCLUDE_PATHS_FILE}' over to '${PATCH_DIR}/precommit/excluded.txt'"
    cp -pr "${EXCLUDE_PATHS_FILE}" "${PATCH_DIR}/precommit/excluded.txt"
  fi
  if [[ -n ${PERSONALITY}
    && -f ${PERSONALITY} ]]; then
    yetus_debug "copying '${PERSONALITY}' over to '${PATCH_DIR}/precommit/personality/provided.sh'"
    cp -pr "${PERSONALITY}" "${PATCH_DIR}/precommit/personality/provided.sh"
  fi

  if [[ -n ${UNIT_TEST_FILTER_FILE}
    && -f ${UNIT_TEST_FILTER_FILE} ]]; then
    yetus_debug "copying '${UNIT_TEST_FILTER_FILE}' over to '${PATCH_DIR}/precommit/unit_test_filter_file.txt'"
    cp -pr "${UNIT_TEST_FILTER_FILE}" "${PATCH_DIR}/precommit/unit_test_filter_file.txt"
  fi

  popd >/dev/null || return 1
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
      mkdir -p "${BUILDTOOLCWD}" || return 1
    fi
    pushd "${BUILDTOOLCWD}" >/dev/null || return 1
    return 0
  fi

  case "${BUILDTOOLCWD}" in
    basedir)
      pushd "${BASEDIR}" >/dev/null || return 1
    ;;
    module)
      if [[ ! -d "${BASEDIR}/${MODULE[${modindex}]}" ]]; then
        return 1
      fi
      pushd "${BASEDIR}/${MODULE[${modindex}]}" >/dev/null || return 1
    ;;
    *)
      pushd "$(pwd)" >/dev/null || return 1
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
    tpdir=$(yetus_relative_dir "${BASEDIR}" "${testdir}")
    # shellcheck disable=SC2181
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
      add_vote_table_v2 -1 precommit "" "Couldn't test precommit changes because we aren't configured to destructively change the working directory."
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

    #if we are doing docker, then we re-exec, but underneath the
    #container

    docker_handler
    exit $?
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
        if [[ ${MODULE_STATUS[${modindex}]} == -1
          && -n "${MODULE_STATUS_LOG[${modindex}]}" ]]; then
          add_vote_table_v2 \
            "${MODULE_STATUS[${modindex}]}" \
            "${testtype}" \
            "@@BASE@@/${MODULE_STATUS_LOG[${modindex}]}" \
            "${MODULE_STATUS_MSG[${modindex}]}"
          bugsystem_linecomments_queue \
            "${testtype}" \
            "${PATCH_DIR}/${MODULE_STATUS_LOG[${modindex}]}"
        else
          add_vote_table_v2 \
            "${MODULE_STATUS[${modindex}]}" \
            "${testtype}" \
            "" \
            "${MODULE_STATUS_MSG[${modindex}]}"
        fi
      fi
      ((modindex=modindex+1))
    done

    if [[ ${failure} == false ]]; then
      start_clock
      offset_clock "${goodtime}"
      add_vote_table_v2 +1 "${testtype}" "" "${repo} passed${statusjdk}"
    fi
  else
    until [[ ${modindex} -eq ${#MODULE[@]} ]]; do
      start_clock
      echo ""
      echo "${MODULE_STATUS_MSG[${modindex}]}"
      echo ""
      offset_clock "${MODULE_STATUS_TIMER[${modindex}]}"
      if [[ ${MODULE_STATUS[${modindex}]} == -1
        && -n "${MODULE_STATUS_LOG[${modindex}]}" ]]; then
        add_vote_table_v2 \
          "${MODULE_STATUS[${modindex}]}" \
          "${testtype}" \
          "@@BASE@@/${MODULE_STATUS_LOG[${modindex}]}" \
          "${MODULE_STATUS_MSG[${modindex}]}"
      else
        add_vote_table_v2 \
          "${MODULE_STATUS[${modindex}]}" \
          "${testtype}" \
          "" \
          "${MODULE_STATUS_MSG[${modindex}]}"
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
      MODULE_STATUS_JDK[${index}]=" with JDK ${jdk}"
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
  declare execvalue

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
    statusjdk=" with JDK ${jdk}"
    jdk="-jdk${jdk}"
    jdk=${jdk// /}
    yetus_debug "Starting MultiJDK mode${statusjdk} on ${testtype}"
  fi

  until [[ ${modindex} -eq ${#MODULE[@]} ]]; do
    start_clock

    fn=$(module_file_fragment "${MODULE[${modindex}]}")
    fn="${fn}${jdk}"
    modulesuffix=$(basename "${MODULE[${modindex}]}")
    if [[ ${modulesuffix} = \. ]]; then
      modulesuffix="root"
    fi

    if ! buildtool_cwd "${modindex}"; then
      echo "${BASEDIR}/${MODULE[${modindex}]} no longer exists. Skipping."
      ((modindex=modindex+1))
      savestop=$(stop_clock)
      MODULE_STATUS_TIMER[${modindex}]=${savestop}
      continue
    fi

    argv=("${@//@@@MODULEFN@@@/${fn}}")
    argv=("${argv[@]//@@@MODULEDIR@@@/${BASEDIR}/${MODULE[${modindex}]}}")

    # shellcheck disable=2086,2046
    echo_and_redirect "${PATCH_DIR}/${repostatus}-${testtype}-${fn}.txt" \
      $("${BUILDTOOL}_executor" "${testtype}") \
      ${MODULEEXTRAPARAM[${modindex}]//@@@MODULEFN@@@/${fn}} \
      "${argv[@]}"
    execvalue=$?

    reaper_post_exec "${modulesuffix}" "${repostatus}-${testtype}-${fn}"
    ((execvalue = execvalue + $? ))

    if [[ ${execvalue} == 0 ]] ; then
      module_status \
        "${modindex}" \
        +1 \
        "${repostatus}-${testtype}-${fn}.txt" \
        "${modulesuffix} in ${repo} passed${statusjdk}."
    else
      module_status \
        "${modindex}" \
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
    popd >/dev/null || return 1
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
  declare -a jdklist
  declare statusjdk
  declare formatresult=0
  declare needlog

  if ! verify_needed_test unit; then
    return 0
  fi

  big_console_header "Running unit tests"

  if verify_multijdk_test unit; then
    multijdkmode=true
    jdklist=("${JDK_DIR_LIST[@]}")
  else
    multijdkmode=false
    jdklist=("${JAVA_HOME}")
  fi

  for jdkindex in "${jdklist[@]}"; do
    if [[ ${multijdkmode} == true ]]; then
      JAVA_HOME=${jdkindex}
      jdk=$(report_jvm_version "${JAVA_HOME}")
      statusjdk="JDK ${jdk} "
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
      for testsys in "${TESTFORMATS[@]}"; do
        if declare -f "${testsys}_process_tests" >/dev/null; then
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

      popd >/dev/null || return 1

      ((i=i+1))
    done

    for testsys in "${TESTFORMATS[@]}"; do
      if declare -f "${testsys}_finalize_results" >/dev/null; then
        yetus_debug "Calling ${testsys}_finalize_results"
        "${testsys}_finalize_results" "${statusjdk}"
      fi
    done

  done
  JAVA_HOME=${savejavahome}

  modules_messages patch unit false

  if [[ "${ROBOT}" == true ]]; then
    if declare -f "${ROBOTTYPE}"_unittest_footer >/dev/null; then
      "${ROBOTTYPE}"_unittest_footer "${statusjdk}"
    fi
  fi

  if [[ ${result} -gt 0 ]]; then
    return 1
  fi
  return 0
}


## @description  Write the final output to the selected bug system
## @audience     private
## @stability    evolving
## @replaceable  no
function bugsystem_finalreport
{
  declare version
  declare bugs

  if [[ "${ROBOT}" = true ]]; then
    if declare -f "${ROBOTTYPE}"_finalreport >/dev/null; then
      "${ROBOTTYPE}"_finalreport
    fi
  fi

  if [[ "${#VERSION_DATA[@]}" -gt 0 ]]; then
    add_footer_table "versions" "${VERSION_DATA[@]}"
  fi

  add_footer_table "Powered by" "Apache Yetus ${VERSION} https://yetus.apache.org"

  big_console_header "Generating Reports . . ."

  bugsystem_linecomments_trigger

  for bugs in ${BUGCOMMENTS}; do
    if declare -f "${bugs}_finalreport" >/dev/null;then
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

  if [[ ${ROBOT} == "true" ]]; then
    if declare -f "${ROBOTTYPE}"_cleanup_and_exit >/dev/null; then
      "${ROBOTTYPE}"_cleanup_and_exit "${result}"
    fi

    if [[ ${RELOCATE_PATCH_DIR} == "true" && \
        -e ${PATCH_DIR} && -d ${PATCH_DIR} ]] ; then
      # if PATCH_DIR is already inside BASEDIR, then
      # there is no need to move it since we assume that
      # Jenkins or whatever already knows where it is at
      # since it told us to put it there!
      yetus_relative_dir "${BASEDIR}" "${PATCH_DIR}" >/dev/null
      if [[ $? == 1 ]]; then
        yetus_debug "mv ${PATCH_DIR} ${BASEDIR}"
        mv "${PATCH_DIR}" "${BASEDIR}"
      fi
    fi
  fi

  # docker mode will print this after exit
  if [[ "${DOCKERMODE}" == false ]]; then
    big_console_header "Finished build."
  fi

  if [[ "${DOCKERMODE}" != true ]]; then
    rm "${PATCH_DIR}/pidfile.txt"
  fi

  if [[ "${BUILDMODE}" == 'full' ]] && [[ "${CONTINUOUS_IMPROVEMENT}" == true ]]; then
    exit 0
  fi

  #shellcheck disable=SC2086
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

  for plugin in "${TESTTYPES[@]}"; do
    verify_patchdir_still_exists
    if declare -f "${plugin}_tests" >/dev/null 2>&1; then
      modules_reset
      yetus_debug "Running ${plugin}_tests"
      "${plugin}_tests"
    fi
  done
  archive
}

## @description  Calculate the differences between the specified files
## @description  using just the column+ messages (third+ column in a
## @description  colon delimated file) and output it to stdout.
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
  cut -f3- -d: "${branch}" > "${tmp}.branch"
  cut -f3- -d: "${patch}" > "${tmp}.patch"

  # compare the errors, generating a string of line
  # numbers. Sorry portability: GNU diff makes this too easy
  "${DIFF}" --unchanged-line-format="" \
     --old-line-format="" \
     --new-line-format="%dn " \
     "${tmp}.branch" \
     "${tmp}.patch" > "${tmp}.lined"

  if [[ "${BUILDMODE}" == full ]]; then
    cat "${patch}"
  else
    # now, pull out those lines of the raw output
    # shellcheck disable=SC2013
    for j in $(cat "${tmp}.lined"); do
      head -"${j}" "${patch}" | tail -1
    done
  fi

  rm "${tmp}.branch" "${tmp}.patch" "${tmp}.lined" 2>/dev/null
}

## @description  Calculate the differences between the specified files
## @description  using just the error messages (last column in a
## @description  colon delimated file) and output it to stdout.
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
  "${AWK}" -F: '{print $NF}' "${branch}" > "${tmp}.branch"

  # shellcheck disable=SC2016
  "${AWK}" -F: '{print $NF}' "${patch}" > "${tmp}.patch"

  # compare the errors, generating a string of line
  # numbers. Sorry portability: GNU diff makes this too easy
  "${DIFF}" --unchanged-line-format="" \
     --old-line-format="" \
     --new-line-format="%dn " \
     "${tmp}.branch" \
     "${tmp}.patch" > "${tmp}.lined"

  if [[ "${BUILDMODE}" == full ]]; then
    cat "${patch}"
  else

    # now, pull out those lines of the raw output
    # shellcheck disable=SC2013
    for j in $(cat "${tmp}.lined"); do
      head -"${j}" "${patch}" | tail -1
    done
  fi

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

  if declare -f "${PROJECT_NAME}_${testtype}_calcdiffs" >/dev/null; then
    "${PROJECT_NAME}_${testtype}_calcdiffs" "${branchlog}" "${patchlog}"
  elif declare -f "${BUILDTOOL}_${testtype}_calcdiffs" >/dev/null; then
    "${BUILDTOOL}_${testtype}_calcdiffs" "${branchlog}" "${patchlog}"
  elif declare -f "${testtype}_calcdiffs" >/dev/null; then
    "${testtype}_calcdiffs" "${branchlog}" "${patchlog}"
  else
    error_calcdiffs "${branchlog}" "${patchlog}"
  fi
}

## @description generate a standardized calcdiff status message
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

  if declare -f "${PROJECT_NAME}_${testtype}_logfilter" >/dev/null; then
    "${PROJECT_NAME}_${testtype}_logfilter" "${input}" "${output}"
  elif declare -f "${BUILDTOOL}_${testtype}_logfilter" >/dev/null; then
    "${BUILDTOOL}_${testtype}_logfilter" "${input}" "${output}"
  elif declare -f "${testtype}_logfilter" >/dev/null; then
    "${testtype}_logfilter" "${input}" "${output}"
  else
    yetus_error "ERROR: ${testtype}: No function defined to filter problems."
    echo 0
  fi
}

## @description  Deprecated. Use module_pre_handler instead.
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        testype
## @param        multijdk
## @return       1 on failure
## @return       0 on success
function generic_pre_handler
{
  module_pre_handler "$@"
}

## @description  Helper routine for plugins to do a pre-patch run
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        testype
## @param        multijdk
## @return       1 on failure
## @return       0 on success
function module_pre_handler
{
  declare testtype=$1
  declare multijdkmode=$2
  declare result=0
  declare -r savejavahome=${JAVA_HOME}
  declare multijdkmode
  declare jdkindex=0
  declare -a jdklist

  if ! verify_needed_test "${testtype}"; then
     return 0
  fi

  big_console_header "Pre-patch ${testtype} verification on ${PATCH_BRANCH}"

  if verify_multijdk_test "${testtype}"; then
    multijdkmode=true
    jdklist=("${JDK_DIR_LIST[@]}")
  else
    multijdkmode=false
    jdklist=("${JAVA_HOME}")
  fi

  for jdkindex in "${jdklist[@]}"; do
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

## @description  Deprecated. Use module_postlog_compare instead.
## @audience     public
## @stability    evolving
function generic_postlog_compare
{
  module_postlog_compare "$@"
}

## @description  Module post-patch log handler
## @audience     public
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
## @param        origlog
## @param        testtype
## @param        multijdkmode
function module_postlog_compare
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
  declare tmpvar


  if [[ ${multijdk} == true ]]; then
    jdk=$(report_jvm_version "${JAVA_HOME}")
    statusjdk=" with JDK ${jdk}"
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

    tmpvar=$(wc -l "${PATCH_DIR}/branch-${origlog}-${testtype}-${fn}.txt")
    numbranch=${tmpvar%% *}
    tmpvar=$(wc -l "${PATCH_DIR}/patch-${origlog}-${testtype}-${fn}.txt")
    numpatch=${tmpvar%% *}

    calcdiffs \
      "${PATCH_DIR}/branch-${origlog}-${testtype}-${fn}.txt" \
      "${PATCH_DIR}/patch-${origlog}-${testtype}-${fn}.txt" \
      "${testtype}" \
      > "${PATCH_DIR}/results-${origlog}-${testtype}-${fn}.txt"

    tmpvar=$(wc -l "${PATCH_DIR}/results-${origlog}-${testtype}-${fn}.txt")
    addpatch=${tmpvar%% *}

    ((fixedpatch=numbranch-numpatch+addpatch))

    statstring=$(generic_calcdiff_status "${numbranch}" "${numpatch}" "${addpatch}" )

    if [[ ${addpatch} -gt 0 ]]; then
      ((result = result + 1))
      module_status "${i}" -1 "results-${origlog}-${testtype}-${fn}.txt" "${fn}${statusjdk} ${statstring}"
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

## @description  Root-level post-patch log handler. Files should be
## @description  linecomments compatible!
## @audience     public
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
## @param        testtype
## @param        branchlog
## @param        patchlog
function root_postlog_compare
{
  declare testtype=$1
  declare branchlog=$2
  declare patchlog=$3
  declare fn
  declare -i numbranch=0
  declare -i numpatch=0
  declare -i addpatch=0
  declare -i samepatch=0
  declare -i fixedpatch=0
  declare tmpvar

  yetus_debug "${testtype}: ${branchlog} vs. ${patchlog}"

  # if it was a new module, this won't exist.
  if [[ ! -f "${branchlog}" ]]; then
    touch "${branchlog}"
  fi

  if [[ ! -f "${patchlog}" ]]; then
    touch "${patchlog}"
  fi

  difflog="results-${testtype}.txt"

  tmpvar=$(wc -l "${branchlog}")
  numbranch="${tmpvar%% *}"
  tmpvar=$(wc -l "${patchlog}")
  numpatch="${tmpvar%% *}"

  calcdiffs \
    "${branchlog}" \
    "${patchlog}" \
    "${testtype}" \
    > "${PATCH_DIR}/${difflog}"

  tmpvar=$(wc -l "${PATCH_DIR}/${difflog}")
  addpatch="${tmpvar%% *}"

  ((fixedpatch=numbranch-numpatch+addpatch))

  statstring=$(generic_calcdiff_status "${numbranch}" "${numpatch}" "${addpatch}" )

  if [[ ${addpatch} -gt 0 ]]; then
    add_vote_table_v2 -1 "${testtype}" "@@BASE@@/${difflog}" "${BUILDMODEMSG} ${statstring}"
    bugsystem_linecomments_queue "${testtype}" "${PATCH_DIR}/${difflog}"
    return 1
  elif [[ ${fixedpatch} -gt 0 ]]; then
   add_vote_table_v2 +1 "${testtype}" "" "${BUILDMODEMSG} ${statstring}"
   return 0
  fi

  if [[ "${BUILDMODE}" == "full" ]]; then
    add_vote_table_v2 +1 "${testtype}" "" "No issues."
  else
    add_vote_table_v2 +1 "${testtype}" "" "No new issues."
  fi
  return 0
}

## @description  Deprecated. Use module_post_handler instead.
## @audience     public
## @stability    evolving
function generic_post_handler
{
  module_post_handler "$@"
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
function module_post_handler
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

  for jdkindex in "${JDK_DIR_LIST[@]}"; do
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

    module_postlog_compare "${origlog}" "${testtype}" "${multijdkmode}"
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
  declare -a jdklist

  if verify_multijdk_test compile; then
    multijdkmode=true
    jdklist=("${JDK_DIR_LIST[@]}")
  else
    multijdkmode=false
    jdklist=("${JAVA_HOME}")
  fi

  for jdkindex in "${jdklist[@]}"; do
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

  for plugin in "${TESTTYPES[@]}"; do
    modules_restore
    verify_patchdir_still_exists
    if declare -f "${plugin}_compile" >/dev/null 2>&1; then
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

  for plugin in ${PROJECT_NAME} ${BUILDTOOL} "${TESTTYPES[@]}" "${TESTFORMATS[@]}"; do
    if declare -f "${plugin}_precompile" >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_precompile"
      if ! "${plugin}_precompile" "${codebase}"; then
        ((result = result+1))
      fi
      archive
    fi
  done

  compile "${codebase}"

  for plugin in ${PROJECT_NAME} ${BUILDTOOL} "${TESTTYPES[@]}" "${TESTFORMATS[@]}"; do
    if declare -f "${plugin}_postcompile" >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_postcompile"
      if ! "${plugin}_postcompile" "${codebase}"; then
        ((result = result+1))
      fi
      archive
    fi
  done

  for plugin in ${PROJECT_NAME} ${BUILDTOOL} "${TESTTYPES[@]}" "${TESTFORMATS[@]}"; do
    if declare -f "${plugin}_rebuild" >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_rebuild"
      if ! "${plugin}_rebuild" "${codebase}"; then
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

  for plugin in ${BUILDTOOL} "${TESTTYPES[@]}" "${TESTFORMATS[@]}"; do
    if declare -f "${plugin}_patchfile" >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_patchfile"
      if ! "${plugin}_patchfile" "${INPUT_APPLIED_FILE}"; then
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

  for plugin in "${TESTTYPES[@]}" "${TESTFORMATS[@]}"; do
    if declare -f "${plugin}_clean" >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_clean"
      if ! "${plugin}_clean"; then
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

## @description  Start any coprocessors
## @audience     private
## @stability    evolving
## @replaceable  yes
function start_coprocessors
{

  declare filename

  # Eventually, we might open this up for plugins
  # and other operating environments
  # but for now, this is private and only for us

  if [[ "${BASH_VERSINFO[0]}" -gt 3 ]]; then

    for filename in "${BINDIR}/coprocs.d"/*; do
      # shellcheck disable=SC1091
      # shellcheck source=coprocs.d/process_counter.sh
      . "${filename}"
    done

    determine_user

    process_counter_coproc_start

    reaper_coproc_start

  fi
}

## @description  Stop any coprocessors
## @audience     private
## @stability    evolving
## @replaceable  yes
function stop_coprocessors
{
  if [[ "${BASH_VERSINFO[0]}" -gt 3 ]]; then
    # shellcheck disable=SC2154
    if [[ -n "${process_counter_coproc_PID}" ]]; then
      # shellcheck disable=SC2086
      echo exit >&${process_counter_coproc[1]}
    fi

    #shellcheck disable=SC2154
    if [[ -n "${reaper_coproc_PID}" ]]; then
      # shellcheck disable=SC2086
      echo exit >&${reaper_coproc[1]}
    fi
  fi
}

## @description  Additional setup work when in patch mode, including
## @description  setting ${INPUT_APPLIED_FILE} so that the system knows
## @description  which one to use because it will have passed dryrun.
## @audience     private
## @stability    evolving
## @replaceable  no
function patch_setup_work
{

  # from here on out, we'll be in ${BASEDIR} for cwd
  # plugins need to pushd/popd if they change.
  determine_issue

  if ! dryrun_both_files; then
      ((RESULT = RESULT + 1))
      yetus_error "ERROR: ${PATCH_OR_ISSUE} does not apply to ${PATCH_BRANCH}."
      add_vote_table_v2 -1 patch "" "${PATCH_OR_ISSUE} does not apply to ${PATCH_BRANCH}. Rebase required? Wrong Branch? See ${PATCH_NAMING_RULE} for help."
      bugsystem_finalreport 1
      cleanup_and_exit 1
  fi

  if [[ "${ISSUE}" == 'Unknown' ]]; then
    echo ""
    echo "Testing ${INPUT_APPLY_TYPE} on ${PATCH_BRANCH}."
  else
    echo ""
    echo "Testing ${ISSUE} ${INPUT_APPLY_TYPE} on ${PATCH_BRANCH}."
  fi
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

  if [[ -z "${BUILDTOOL}" ]]; then
    guess_build_tool
  fi

  parse_args_plugins "$@"

  if declare -f personality_parse_args >/dev/null; then
    personality_parse_args "$@"
  fi

  BUGCOMMENTS=${BUGCOMMENTS:-"${BUGSYSTEMS[@]}"}
  if [[ ! ${BUGCOMMENTS} =~ console ]]; then
    BUGCOMMENTS="${BUGCOMMENTS} console"
  fi

  if [[ "${BUGLINECOMMENTS}" == " " ]]; then
    BUGLINECOMMENTS=""
  else
    BUGLINECOMMENTS=${BUGLINECOMMENTS:-${BUGCOMMENTS}}
  fi

  # we need to do this BEFORE plugins initialize
  # because they may change what they do based upon
  # docker support
  # note that docker support still isn't guaranteed
  # to be working even after this is executed here!
  if declare -f docker_initialize >/dev/null; then
    docker_initialize
  fi

  if [[ "${DOCKERMODE}" != true ]]; then
    echo "$$" > "${PATCH_DIR}/pidfile.txt"
  fi

  plugins_initialize
  if [[ ${RESULT} != 0 ]]; then
    cleanup_and_exit 1
  fi

  echo "Modes: ${EXEC_MODES[*]}"

  if [[ "${BUILDMODE}" = patch ]]; then
    locate_patch
  fi

  git_checkout

  if [[ "${BUILDMODE}" = patch ]]; then
    patch_setup_work
  fi

  find_changed_files

  # re-verify that our dockerfile is still there (branch switch, etc)
  # note that there is still a chance that docker mode will be
  # disabled from here. Plug-ins should plan appropriately!
  if declare -f docker_fileverify >/dev/null; then
    docker_fileverify
  fi

  check_reexec

  if [[ "${#PARAMETER_TRACKER}" -gt 0 ]]; then
    yetus_error "ERROR: Unprocessed flag(s): ${PARAMETER_TRACKER[*]}"
    if [[ "${IGNORE_UNKNOWN_OPTIONS}" == true ]]; then
      if [[ "${REPORT_UNKNOWN_OPTIONS}" == true ]]; then
        add_vote_table_v2 "-0" yetus "" "Unprocessed flag(s): ${PARAMETER_TRACKER[*]}"
      fi
    else
      add_vote_table_v2 -1 yetus "" "Unprocessed flag(s): ${PARAMETER_TRACKER[*]}"
      bugsystem_finalreport 1
      cleanup_and_exit 1
    fi
  fi

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

  for plugin in ${BUILDTOOL} "${NEEDED_TESTS[@]}" "${TESTFORMATS[@]}"; do
    verify_patchdir_still_exists

    if declare -f "${plugin}_precheck" >/dev/null 2>&1; then

      yetus_debug "Running ${plugin}_precheck"
      "${plugin}_precheck"

      (( result = result + $? ))
      if [[ ${result} != 0 ]] ; then
        bugsystem_finalreport 1
        cleanup_and_exit 1
      fi
    fi
  done
}

## @description perform prechecks
## @audience private
## @stability evolving
## @return   exits on failure
function postcleanups
{
  declare plugin
  declare result=0

  for plugin in ${BUILDTOOL} "${NEEDED_TESTS[@]}" "${TESTFORMATS[@]}"; do
    verify_patchdir_still_exists

    if declare -f "${plugin}_postcleanup" >/dev/null 2>&1; then

      yetus_debug "Running ${plugin}_postcleanup"
      "${plugin}_postcleanup"

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

###############################################################################
###############################################################################
###############################################################################

# robots will change USER_PARAMS so must
# do this before importing other code
setup_parameter_tracker

import_core

if [[ "${BINNAME}" =~ qbt ]]; then
  initialize --empty-patch "$@"
else
  initialize "$@"
fi


if [[ ${BASH_VERSINFO[0]} -gt 3 ]]; then
  yetus_debug "Starting coprocessors"

  # we need to catch out and err bz the coproc
  # command is extremely noisy on both startup
  # and shutdown
  start_coprocessors >> "${COPROC_LOGFILE}" 2>&1
else

  # If we aren't using bash4 (e.g. OS X), then set the ulimit now.
  # bash4 gets it set in an (on demand) coprocessor

  ulimit -Su "${PROC_LIMIT}"
  yetus_debug "Changed process/Java native thread limit to ${PROC_LIMIT}"
fi

add_vote_table_v2 H "Prechecks"

prechecks

if [[ "${BUILDMODE}" = patch ]]; then

  patchfiletests

  add_vote_table_v2 H "${PATCH_BRANCH} Compile Tests"

  compile_cycle branch

  distclean

  apply_patch_file

  exclude_paths_from_changed_files

  compute_gitdiff

  add_vote_table_v2 H "Patch Compile Tests"

else

  add_vote_table_v2 H "Compile Tests"

fi

compile_cycle patch

add_vote_table_v2 H "Other Tests"

runtests

stop_coprocessors

postcleanups

finish_vote_table

finish_footer_table

bugsystem_finalreport "${RESULT}"
cleanup_and_exit "${RESULT}"
