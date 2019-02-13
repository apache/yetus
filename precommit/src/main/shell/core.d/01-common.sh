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
  BUGSYSTEMS=()
  BUILDTOOL=""
  BUILDTOOLS=()
  #shellcheck disable=SC2034
  EXEC_MODES=()
  #shellcheck disable=SC2034
  EXCLUDE_PATHS=()
  ROBOTTYPE=""
  LOAD_SYSTEM_PLUGINS=true
  #shellcheck disable=SC2034
  OFFLINE=false
  GIT_ASKPASS=${GIT_ASKPASS:-/bin/true}
  #shellcheck disable=SC2034
  GIT_OFFLINE=false
  #shellcheck disable=SC2034
  GIT_SHALLOW=false
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
  #shellcheck disable=SC2034
  PATCH_SYSTEM=""
  PROJECT_NAME=unknown
  # seed $RANDOM
  RANDOM=$$
  RESULT=0
  #shellcheck disable=SC2034
  ROBOT=false
  #shellcheck disable=SC2034
  SENTINEL=false
  #shellcheck disable=SC2034
  TESTTYPES=()
  TESTFORMATS=()
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
      STAT=${STAT:-stat}
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
      STAT=${STAT:-stat}
    ;;
  esac

  RSYNC=${RSYNC:-rsync}
}

## @description  Interpret the common command line parameters used by test-patch,
## @description  smart-apply-patch, and the bug system plugins
## @audience     private
## @stability    stable
## @replaceable  no
## @param        $@
## @return       May exit on failure
function common_args
{
  declare i
  declare showhelp=false
  declare showversion=false
  declare version

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
      --git-offline)
        #shellcheck disable=SC2034
        GIT_OFFLINE=true
      ;;
      --git-shallow)
        #shellcheck disable=SC2034
        GIT_SHALLOW=true
      ;;
      --grep-cmd=*)
        GREP=${i#*=}
      ;;
      --help|-help|-h|help|--h|--\?|-\?|\?)
        showhelp=true
      ;;
      --list-plugins)
        list_plugins
        exit 0
      ;;
      --offline)
        #shellcheck disable=SC2034
        OFFLINE=true
        #shellcheck disable=SC2034
        GIT_OFFLINE=true
      ;;
      --patch-cmd=*)
        PATCH=${i#*=}
      ;;
      --patch-dir=*)
        PATCH_DIR=${i#*=}
      ;;
      --plugins=*)
        ENABLED_PLUGINS=${i#*=}
        ENABLED_PLUGINS=${ENABLED_PLUGINS//,/ }
      ;;
      --project=*)
        PROJECT_NAME=${i#*=}
      ;;
      --rsync-cmd=*)
        RSYNC=${i#*=}
      ;;
      --skip-system-plugins)
        LOAD_SYSTEM_PLUGINS=false
      ;;
      --sed-cmd=*)
        SED=${i#*=}
      ;;
      --stat-cmd=*)
        # This is used by Docker-in-Docker mode presently, but if other
        # things end up needing it later, it's better to just put it here
        #shellcheck disable=SC2034
        STAT=${i#*=}
      ;;
      --user-plugins=*)
        USER_PLUGIN_DIR=${i#*=}
      ;;
      --version)
        showversion=true
      ;;
      *)
      ;;
    esac
  done

  activate_robots "$@"

  set_yetus_version

  if [[ ${showhelp} == true ]]; then
    yetus_usage
    exit 0
  fi
  if [[ ${showversion} == true ]]; then
    echo "${VERSION}"
    exit 0
  fi

  # Absolutely require v1.7.3 or higher
  # versions lower than this either have bugs with
  # git apply or don't support all the
  # expected options
  version=$(${GIT} --version)
  # shellcheck disable=SC2181
  if [[ $? != 0 ]]; then
    yetus_error "ERROR: ${GIT} failed during version detection."
    exit 1
  fi

  # shellcheck disable=SC2016
  version=$(echo "${version}" | "${AWK}" '{print $NF}')
  if [[ ${version} =~ ^0
     || ${version} =~ ^1.[0-6]
     || ${version} =~ ^1.7.[0-2]$
    ]]; then
    yetus_error "ERROR: ${GIT} v1.7.3 or higher is required (found ${version})."
    exit 1
  fi
}

## @description  List all installed plug-ins, regardless of whether
## @description  they have been enabled
## @audience     public
## @stability    evolving
## @replaceable  no
function list_plugins
{
  declare plugintype
  declare name
  declare plugref
  declare plugarray

  ENABLED_PLUGINS="all"
  importplugins

  printf "Reminder: every plug-in may be enabled via 'all'.\\n\\n"
  for plugintype in BUILDTOOLS TESTTYPES BUGSYSTEMS TESTFORMATS; do
    printf '%s:\n\t' ${plugintype}
    plugref="${plugintype}[@]"
    plugarray=("${!plugref}")
    for name in "${plugarray[@]}"; do
      printf "%s " "${name}"
    done
    echo ""
  done
}

## @description  Let plugins also get a copy of the arguments
## @audience     private
## @stability    evolving
## @replaceable  no
function parse_args_plugins
{
  declare plugin

  for plugin in "${TESTTYPES[@]}" "${BUGSYSTEMS[@]}" "${TESTFORMATS[@]}" "${BUILDTOOLS[@]}"; do
    if declare -f "${plugin}_parse_args" >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_parse_args"
      "${plugin}_parse_args" "$@"
      (( RESULT = RESULT + $? ))
    fi
  done
}

## @description  Initialize all enabled plugins
## @audience     private
## @stability    evolving
## @replaceable  no
function plugins_initialize
{
  declare plugin

  for plugin in "${TESTTYPES[@]}" "${BUGSYSTEMS[@]}" "${TESTFORMATS[@]}" "${BUILDTOOL}"; do
    if declare -f "${plugin}_initialize" >/dev/null 2>&1; then
      yetus_debug "Running ${plugin}_initialize"
      "${plugin}_initialize"
      (( RESULT = RESULT + $? ))
    fi
  done
}

## @description  Determine if a plugin was enabled by the user
## @description  ENABLED_PLUGINS must be defined
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test
function verify_plugin_enabled
{
  declare toadd=$1
  declare bar
  declare idx
  declare strip
  declare stridx

  yetus_debug "Testing if $1 has been enabled by user"

  bar=""
  for idx in ${ENABLED_PLUGINS}; do
    stridx=${idx// }
    yetus_debug "verify_plugin_enabled: processing ${stridx}"
    case ${stridx} in
      all)
        bar=${toadd}
      ;;
      -*)
        strip=${stridx#-}
        if [[ ${strip} = "${toadd}" ]]; then
          bar=""
        fi
        ;;
      +*|*)
        strip=${stridx#+}
        if [[ ${strip} = "${toadd}" ]]; then
          bar=${toadd}
        fi
      ;;
    esac
  done

  if [[ -n ${bar} ]]; then
    yetus_debug "Post-parsing: checking ${bar} = ${toadd}"
  fi
  [[ ${bar} = "${toadd}" ]]
}

## @description  Personality-defined plug-in list
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        plug-in list string
function personality_plugins
{
  if [[ -z "${ENABLED_PLUGINS}" ]]; then
    ENABLED_PLUGINS="$1"
    ENABLED_PLUGINS=${ENABLED_PLUGINS//,/ }
    yetus_debug "Using personality plug-in list: ${ENABLED_PLUGINS}"
  fi
}

## @description  Add the given test type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test
function add_test
{
  if verify_plugin_enabled "${1}"; then
    yetus_add_array_element NEEDED_TESTS "${1}"
  fi
}

## @description  Remove the given test type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test
function delete_test
{
  yetus_del_array_element NEEDED_TESTS "${1}"
}

## @description  Verify if a given test was requested
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test
## @return       0 = yes
## @return       1 = no
function verify_needed_test
{
  yetus_ver_array_element NEEDED_TESTS "${1}"
}

## @description  Add the given test type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        plugin
function add_test_type
{
  if verify_plugin_enabled "${1}"; then
    yetus_add_array_element TESTTYPES "${1}"
  fi
}

## @description  Remove the given test type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        plugin
function delete_test_type
{
  yetus_del_array_element TESTTYPES "${1}"
}

## @description  Add the given bugsystem type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        bugsystem
function add_bugsystem
{
  if verify_plugin_enabled "${1}"; then
    yetus_add_array_element BUGSYSTEMS "${1}"
  fi
}

## @description  Remove the given bugsystem type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        bugsystem
function delete_bugsystem
{
  yetus_del_array_element BUGSYSTEMS "${1}"
}

## @description  Add the given test format type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test format
function add_test_format
{
  if verify_plugin_enabled "${1}"; then
    yetus_add_array_element TESTFORMATS "${1}"
  fi
}

## @description  Remove the given test format type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        test format
function delete_test_format
{
  yetus_del_array_element TESTFORMATS "${1}"
}

## @description  Add the given build tool type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        build tool
function add_build_tool
{
  if verify_plugin_enabled "${1}"; then
    yetus_add_array_element BUILDTOOLS "${1}"
  fi
}

## @description  Remove the given build tool type
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        build tool
function delete_build_tool
{
  yetus_del_array_element BUILDTOOLS "${1}"
}

## @description  Import content from test-patch.d and optionally
## @description  from user provided plugin directory
## @audience     private
## @stability    evolving
## @replaceable  no
function importplugins
{
  local i
  local plugin
  local files=()

  #BUG: this will break horribly if there are spaces in the paths. :(

  if [[ ${LOAD_SYSTEM_PLUGINS} == "true" ]]; then
    if [[ -d "${BINDIR}/test-patch.d" ]]; then
      #shellcheck disable=SC2206
      files=(${BINDIR}/test-patch.d/*.sh)
    fi
  fi

  if [[ -n "${USER_PLUGIN_DIR}" && -d "${USER_PLUGIN_DIR}" ]]; then
    yetus_debug "Loading user provided plugins from ${USER_PLUGIN_DIR}"
    #shellcheck disable=SC2206
    files+=(${USER_PLUGIN_DIR}/*.sh)
  fi

  if [[ -n ${PERSONALITY} && ! -f ${PERSONALITY} ]]; then
    yetus_error "ERROR: Can't find ${PERSONALITY} to import."
    unset PERSONALITY
  fi

  if [[ -z ${PERSONALITY}
      && -f "${BINDIR}/personality/${PROJECT_NAME}.sh"
      && ${LOAD_SYSTEM_PLUGINS} = "true" ]]; then
    yetus_debug "Using project personality."
    PERSONALITY="${BINDIR}/personality/${PROJECT_NAME}.sh"
  fi

  if [[ -n ${PERSONALITY} && -f ${PERSONALITY} ]]; then
    yetus_debug "Importing ${PERSONALITY}"
    # shellcheck disable=SC1090
    . "${PERSONALITY}"
  fi

  for i in "${files[@]}"; do
    if [[ -f ${i} ]]; then
      yetus_debug "Importing ${i}"
      #shellcheck disable=SC1090
      . "${i}"
    fi
  done

  if [[ ${ROBOT} == true ]]; then
    if declare -f "${ROBOTTYPE}"_set_plugin_defaults >/dev/null; then
      "${ROBOTTYPE}"_set_plugin_defaults
    fi
  fi

  if declare -f personality_globals > /dev/null; then
    personality_globals
  fi
}

## @description  Print the plugin's usage info
## @audience     public
## @stability    evolving
## @replaceable  no
## @param        array
function plugin_usage_output
{
  echo ""
  echo "${YETUS_USAGE_HEADER}"
  echo ""
}

## @description  Verifies the existence of a command
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        commandname
## @param        commandpath
## @return       0 = ok
## @return       1 = error
function verify_command
{
  local cmd_name="$1"
  local cmd_path="$2"

  if [[ -z ${cmd_path} ]]; then
    yetus_error "executable for '${cmd_name}' was not specified."
    return 1
  fi
  if [[ ! "${cmd_path}" =~ / ]]; then
    cmd_path=$(command -v "${cmd_path}")
  fi
  if [[ ! -f ${cmd_path} ]]; then
    yetus_error "executable '${cmd_path}' for '${cmd_name}' does not exist."
    return 1
  fi
  if [[ ! -x ${cmd_path} ]]; then
    yetus_error "executable '${cmd_path}' for '${cmd_name}' is not executable."
    return 1
  fi
  return 0
}

## @description  Faster dirname, given the assumption that
## @description  dirs are always absolute (e.g., start with /)
## @description  DO NOT USE with relative paths or where
## @description  assumption may not be valid!
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        fileobj
function faster_dirname
{
  declare o=$1

  if [[ "${o}" =~ / ]]; then
    echo "${o%/*}"
  else
    echo .
  fi
}

## @description  Set the USER_NAME, USER_ID, and GROUP_ID env vars
## @audience     private
## @stability    evolving
## @replaceable  no
function determine_user
{
  # in some situations, USER isn't properly defined
  # (e.g., Jenkins).  bash doesn't like you to set this
  # so don't spit any errors to the screen
  USER=$(id -u -n) 2>/dev/null
  USER_NAME=${SUDO_USER:=$USER}
  # shellcheck disable=SC2034
  USER_ID=$(id -u "${USER_NAME}")
  # shellcheck disable=SC2034
  GROUP_ID=$(id -g "${USER_NAME}")
}

## @description  Kill a process id
## @audience     private
## @stability    evolving
## @replaceable  yes
## @param        pid
function pid_kill
{
  declare pid=$1
  declare cmd
  declare kill_timeout=3

  kill "${pid}" >/dev/null 2>&1
  sleep "${kill_timeout}"
  if kill -0 "${pid}" > /dev/null 2>&1; then
    yetus_error "WARNING: ${pid} did not stop gracefully after ${kill_timeout} second(s): Trying to kill with kill -9"
    kill -9 "${pid}" >/dev/null 2>&1
  fi
  if ps -p "${pid}" > /dev/null 2>&1; then
    cmd=$(ps -o args "${pid}")
    yetus_error "ERROR: Unable to kill ${pid}: ${cmd}"
  fi
}

## @description  set VERSION to the current version if not set
## @audience     private
## @stability    evolving
## @replaceable  yes
function set_yetus_version
{

  if [[ -n "${VERSION}" ]]; then
    return
  fi

  if [[ -f "${BINDIR}/../VERSION" ]]; then
    # old src version file
    VERSION=$(cat "${BINDIR}/../VERSION")
  elif [[ -f "${BINDIR}/VERSION" ]]; then
    # dist version file
    VERSION=$(cat "${BINDIR}/VERSION")
  elif [[ -f "${BINDIR}/../../../pom.xml" ]]; then
    # this way we have no dependency on Maven being installed
    VERSION=$(${GREP} "<version>" "${BINDIR}/../../../pom.xml" 2>/dev/null \
      | head -1 \
      | ${SED}  -e 's|^ *<version>||' -e 's|</version>.*$||' 2>/dev/null)
  fi
}

## @description  import and set defaults based upon any auto-detected automation
## @audience     private
## @stability    evolving
## @replaceable  yes
function activate_robots
{
  declare -a files
  declare i

  if [[ -d "${BINDIR}/robots.d" ]]; then
    for i in "${BINDIR}"/robots.d/*.sh; do
      if [[ -f ${i} ]]; then
        yetus_debug "Importing ${i}"
        #shellcheck disable=SC1090
        . "${i}"
      fi
    done
  fi
}

## @description  attempt to guess what the build tool should be
## @audience     public
## @stability    evolving
## @replaceable  no
function guess_build_tool
{
  declare plugin
  declare filename

  for plugin in "${BUILDTOOLS[@]}"; do
    if [[ "${plugin}" != "nobuild" ]] && declare -f "${plugin}_buildfile" >/dev/null 2>&1; then
      filename=$("${plugin}_buildfile")
      if [[ -n "${filename}" ]] &&
         [[ -f "${BASEDIR}/${filename}" ]]; then
        BUILDTOOL=${plugin}
      fi
    fi
  done

  if [[ -z ${BUILDTOOL} ]]; then
    BUILDTOOL=nobuild
  fi

  echo "Setting build tool to ${BUILDTOOL}"
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
    #shellcheck disable=SC1003
    echo "$1" | tr '/' '_' | tr '\\' '_'
  fi
}