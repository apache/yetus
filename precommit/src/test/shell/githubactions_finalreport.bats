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

load functions_test_helper

setup_gha() {
  # Source the githubactions robot
  # shellcheck disable=SC1090
  . "${BATS_TEST_DIRNAME}/../../main/shell/robots.d/githubactions.sh"

  # Mock required functions
  big_console_header() { :; }
  clock_display() { echo "$1s"; }
  get_artifact_url() { echo ""; }
  yetus_error() { echo "$*" >&2; }
  SED="sed"

  # Set up step summary file
  GITHUB_STEP_SUMMARY="${TMP}/step_summary.md"
  touch "${GITHUB_STEP_SUMMARY}"
  export GITHUB_STEP_SUMMARY

  # Initialize arrays and settings
  TP_VOTE_TABLE=()
  TP_TEST_TABLE=()
  TP_HEADER=()
  TP_FOOTER_TABLE=()
  VERSION="0.0.0-test"
  GITHUB_USE_EMOJI_VOTE=false
}

@test "githubactions_finalreport (no GITHUB_STEP_SUMMARY)" {
  setup_gha
  unset GITHUB_STEP_SUMMARY
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
}

@test "githubactions_finalreport (GITHUB_STEP_SUMMARY not writable)" {
  setup_gha
  GITHUB_STEP_SUMMARY="/nonexistent/path/summary.md"
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
}

@test "githubactions_finalreport (success result)" {
  setup_gha
  RESULT=0
  TP_VOTE_TABLE=("|+1| compile |60||passed|")
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
  grep -q ":confetti_ball:" "${GITHUB_STEP_SUMMARY}"
  grep -q "+1 overall" "${GITHUB_STEP_SUMMARY}"
  grep -q "compile" "${GITHUB_STEP_SUMMARY}"
}

@test "githubactions_finalreport (failure result)" {
  setup_gha
  RESULT=1
  TP_VOTE_TABLE=("|-1| unit |120||tests failed|")
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
  grep -q ":broken_heart:" "${GITHUB_STEP_SUMMARY}"
  grep -q -- "-1 overall" "${GITHUB_STEP_SUMMARY}"
  grep -q "unit" "${GITHUB_STEP_SUMMARY}"
}

@test "githubactions_finalreport (with headers)" {
  setup_gha
  RESULT=0
  TP_HEADER=("Build completed successfully")
  TP_VOTE_TABLE=("|+1| compile |60||passed|")
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
  grep -q "Build completed successfully" "${GITHUB_STEP_SUMMARY}"
}

@test "githubactions_finalreport (with failed tests)" {
  setup_gha
  RESULT=1
  TP_VOTE_TABLE=("|-1| unit |120||tests failed|")
  TP_TEST_TABLE=("| Failed tests | org.example.TestFoo |")
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
  grep -q "Failed Tests" "${GITHUB_STEP_SUMMARY}"
  grep -q "TestFoo" "${GITHUB_STEP_SUMMARY}"
}

@test "githubactions_finalreport (vote table header row)" {
  setup_gha
  RESULT=0
  TP_VOTE_TABLE=("|H||||Prechecks|")
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
  grep -q "_Prechecks_" "${GITHUB_STEP_SUMMARY}"
}

@test "githubactions_finalreport (emoji vote enabled)" {
  setup_gha
  RESULT=0
  GITHUB_USE_EMOJI_VOTE=true
  TP_VOTE_TABLE=("|+1| compile |60||passed|")
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
  grep -q ":green_heart:" "${GITHUB_STEP_SUMMARY}"
}

@test "githubactions_finalreport (emoji vote disabled)" {
  setup_gha
  RESULT=0
  GITHUB_USE_EMOJI_VOTE=false
  TP_VOTE_TABLE=("|+1| compile |60||passed|")
  run githubactions_finalreport
  [ "${status}" -eq 0 ]
  # Should have +1 but not the emoji
  grep -q "+1" "${GITHUB_STEP_SUMMARY}"
  ! grep -q ":green_heart:" "${GITHUB_STEP_SUMMARY}"
}

setup_docker_support() {
  # Source the githubactions robot
  # shellcheck disable=SC1090
  . "${BATS_TEST_DIRNAME}/../../main/shell/robots.d/githubactions.sh"

  # Mock add_docker_env
  DOCKER_EXTRAENVS=()
  add_docker_env() {
    for k in "$@"; do
      DOCKER_EXTRAENVS+=("${k}")
    done
  }

  DOCKER_EXTRAARGS=()
  DOCKER_WORK_DIR="/workdir"
}

@test "githubactions_docker_support (no GITHUB_STEP_SUMMARY)" {
  setup_docker_support
  unset GITHUB_STEP_SUMMARY
  run githubactions_docker_support
  [ "${status}" -eq 0 ]
  [ "${#DOCKER_EXTRAARGS[@]}" -eq 0 ]
}

@test "githubactions_docker_support (GITHUB_STEP_SUMMARY file missing)" {
  setup_docker_support
  GITHUB_STEP_SUMMARY="/nonexistent/path/summary.md"
  run githubactions_docker_support
  [ "${status}" -eq 0 ]
  [ "${#DOCKER_EXTRAARGS[@]}" -eq 0 ]
}

@test "githubactions_docker_support (mounts summary file)" {
  setup_docker_support
  GITHUB_STEP_SUMMARY="${TMP}/step_summary.md"
  touch "${GITHUB_STEP_SUMMARY}"
  githubactions_docker_support
  [[ "${DOCKER_EXTRAARGS[*]}" == *"-v"* ]]
  [[ "${DOCKER_EXTRAARGS[*]}" == *"${TMP}/step_summary.md:/workdir/step_summary.md"* ]]
  [ "${GITHUB_STEP_SUMMARY}" = "/workdir/step_summary.md" ]
  [[ "${DOCKER_EXTRAENVS[*]}" == *"GITHUB_STEP_SUMMARY"* ]]
}
