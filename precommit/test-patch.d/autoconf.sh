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
# WITHOUT WARRCMAKEIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

add_build_tool autoconf

## @description  autoconf usage hook
## @audience     private
## @stability    evolving
## @replaceable  no
function autoconf_usage
{
  yetus_add_option "--autoconf-configure-flags=<cmd>" "Extra, non-'--prefix' 'configure' flags to use"
}

## @description  autoconf argument parser
## @audience     private
## @stability    evolving
## @param        args
function autoconf_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --autoconf-configure-flags=*)
        AUTOCONF_CONF_FLAGS=${i#*=}
      ;;
    esac
  done
}

## @description  initialize autoconf
## @audience     private
## @stability    evolving
## @replaceable  no
function autoconf_initialize
{
  if ! declare -f make_executor > /dev/null; then
    yetus_error "ERROR: autoconf requires make to be enabled."
    return 1
  fi
}

## @description  get the name of the autoconf build filename
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       autoconf build file
function autoconf_buildfile
{
  echo "Makefile.am"
}

## @description  get the name of the autoconf binary
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       filename
## @param        params
function autoconf_executor
{
  make_executor "$@"
}

## @description  precompile for autoconf
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       status
## @param        repostatus
function autoconf_precompile
{
  declare repostatus=$1
  declare result=0

  if [[ ${BUILDTOOL} != autoconf ]]; then
    return 0
  fi

  if [[ "${repostatus}" = branch ]]; then
    big_console_header "autoconf verification: ${PATCH_BRANCH}"
  else
    big_console_header "autoconf verification: ${BUILDMODE}"
  fi

  personality_modules "${repostatus}" autoreconf

  pushd "${BASEDIR}" >/dev/null
  echo_and_redirect "${PATCH_DIR}/${repostatus}-autoconf-autoreconf" autoreconf -fi
  result=$?
  popd >/dev/null

  if [[ ${result} != 0 ]]; then
    if [[ "${repostatus}" = branch ]]; then
      # shellcheck disable=SC2153
      add_vote_table -1 autoreconf "${PATCH_BRANCH} unable to autoreconf"
    else
      add_vote_table -1 autoreconf "${BUILDMODEMSG} is unable to autoreconf"
    fi
    add_footer_table "autoreconf" "@@BASE@@/${repostatus}-autoconf-autoreconf"
    return 1
  else
    if [[ "${repostatus}" = branch ]]; then
      # shellcheck disable=SC2153
      add_vote_table +1 autoreconf "${PATCH_BRANCH} autoreconf successful"
    else
      add_vote_table +1 autoreconf "${BUILDMODEMSG} can autoreconf"
    fi
  fi

  personality_modules "${repostatus}" configure

  pushd "${BASEDIR}" >/dev/null
  #shellcheck disable=SC2086
  echo_and_redirect \
    "${PATCH_DIR}/${repostatus}-autoconf-configure" \
      ./configure \
      --prefix="${PATCH_DIR}/${repostatus}-install-dir" \
      ${AUTOCONF_CONF_FLAGS}
  result=$?
  popd >/dev/null

  if [[ ${result} != 0 ]]; then
    if [[ "${repostatus}" = branch ]]; then
      # shellcheck disable=SC2153
      add_vote_table -1 configure "${PATCH_BRANCH} unable to configure"
    else
      add_vote_table -1 configure "${BUILDMODEMSG} is unable to configure"
    fi
    add_footer_table "configure" "@@BASE@@/${repostatus}-autoconf-configure"
    return 1
  else
    if [[ "${repostatus}" = branch ]]; then
      # shellcheck disable=SC2153
      add_vote_table +1 configure "${PATCH_BRANCH} configure successful"
    else
      add_vote_table +1 configure "${BUILDMODEMSG} can configure"
    fi
  fi
  return 0
}

## @description  autoconf worker
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       status
## @param        repostatus
## @param        test
function autoconf_modules_worker
{
  declare repostatus=$1
  declare tst=$2

  # shellcheck disable=SC2034
  UNSUPPORTED_TEST=false

  if [[ "${tst}" = distclean ]]; then
    modules_workers "${repostatus}" distclean distclean
  else
    make_modules_worker "$@"
  fi
}

## @description  autoconf module queuer
## @audience     private
## @stability    evolving
## @replaceable  no
function autoconf_builtin_personality_modules
{
  make_builtin_personality_modules "$@"
}

## @description  autoconf test determiner
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        filename
function autoconf_builtin_personality_file_tests
{
  declare filename=$1

  if [[ ${filename} =~ \.m4$
    || ${filename} =~ \.in$ ]]; then
    yetus_debug "tests/units: ${filename}"
    add_test compile
    add_test unit
  else
    make_builtin_personality_file_tests "${filename}"
  fi
}
