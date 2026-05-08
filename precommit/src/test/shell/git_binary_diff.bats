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

TESTREPOS=()

init_test_repo() {
  local repodir
  repodir=$(mktemp -d /tmp/yetus-bats-XXXXXX)
  TESTREPOS+=("${repodir}")
  unset GIT_DIR GIT_WORK_TREE GIT_DISCOVERY_ACROSS_FILESYSTEM
  export GIT_CEILING_DIRECTORIES=/tmp
  pushd "${repodir}" >/dev/null || return 1
  git init -q --initial-branch=main
  git config user.email "test@test.com"
  git config user.name "Test"
  git config commit.gpgsign false
  git config tag.gpgsign false
  git config core.hooksPath /dev/null
}

teardown() {
  popd >/dev/null 2>&1 || true
  for d in "${TESTREPOS[@]}"; do
    rm -rf "${d}"
  done
  TESTREPOS=()
  if [[ -n "${TMP}" ]]; then
    rm -rf "${TMP}"
  fi
}

@test "git diff --binary round-trip preserves binary content" {
  init_test_repo

  echo "initial" > readme.txt
  git add readme.txt
  git commit -q -m "initial"

  git checkout -q -b feature
  printf '\x00\x01\x02\x03BINARY\xff\xfe' > binary.dat
  echo "modified" > readme.txt
  git add binary.dat readme.txt
  git commit -q -m "add binary"

  local merge_base
  merge_base=$(git merge-base main feature)
  git diff --binary "${merge_base}..feature" > "${TESTREPOS[0]}/test.diff"

  git checkout -q main
  git apply --binary "${TESTREPOS[0]}/test.diff"

  [ -f binary.dat ]
  local actual
  actual=$(od -A n -t x1 binary.dat | tr -d ' \n')
  [ "${actual}" = "0001020342494e415259fffe" ] # pragma: allowlist secret
  [ "$(cat readme.txt)" = "modified" ]
}

@test "YETUS-983: format-patch leaves stale file after add-delete, cumulative diff does not" {
  init_test_repo

  echo "initial" > Helper.java
  git add -A && git commit -q -m "initial"

  git checkout -q -b feature

  printf 'public class BigController {\n    public void doStuff() {}\n}\n' > BigController.java
  git add BigController.java && git commit -q -m "add BigController"

  printf 'public class BigController {\n    public void doStuff() {}\n    public void doMore() {}\n}\n' > BigController.java
  git add -A && git commit -q -m "modify BigController"

  git rm -q BigController.java
  printf 'public class SmallController {\n    public void doStuff() {}\n}\n' > SmallController.java
  git add -A && git commit -q -m "replace BigController with SmallController"

  printf 'public class SmallController {\n    public void doStuff() {}\n    public void doExtra() {}\n}\n' > SmallController.java
  git add -A && git commit -q -m "modify SmallController"

  local merge_base patchfile difffile tmpfiles
  merge_base=$(git merge-base main feature)
  tmpfiles=$(mktemp -d /tmp/yetus-bats-XXXXXX)
  TESTREPOS+=("${tmpfiles}")
  patchfile="${tmpfiles}/multi.patch"
  difffile="${tmpfiles}/cumulative.diff"
  git format-patch --stdout "${merge_base}..feature" > "${patchfile}"
  git diff --binary "${merge_base}..feature" > "${difffile}"

  # format-patch dry-run passes (this is the YETUS-983 trap)
  git checkout -q main
  git apply --binary --check -p1 "${patchfile}"

  # format-patch actual apply "succeeds" but leaves stale file
  git apply --binary -p1 "${patchfile}"
  [ -f BigController.java ]

  # cumulative diff produces correct tree
  git checkout -f -q main
  git clean -fd -q
  git apply --binary -p1 "${difffile}"
  [ ! -f BigController.java ]
  [ -f SmallController.java ]
}
