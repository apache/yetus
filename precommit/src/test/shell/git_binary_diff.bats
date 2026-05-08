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

@test "git diff --binary round-trip preserves binary content" {
  mkdir -p "${TMP}/repo"
  pushd "${TMP}/repo" >/dev/null || return 1
  git init -q --initial-branch=main
  git config user.email "test@test.com"
  git config user.name "Test"
  git config commit.gpgsign false
  git config tag.gpgsign false
  git config core.hooksPath /dev/null

  echo "initial" > readme.txt
  git add readme.txt
  git commit -q -m "initial"

  git checkout -q -b feature
  printf '\x00\x01\x02\x03BINARY\xff\xfe' > binary.dat
  echo "modified" > readme.txt
  git add binary.dat readme.txt
  git commit -q -m "add binary"

  local merge_base
  merge_base=$(git merge-base main feature 2>/dev/null || git merge-base master feature)
  git diff --binary "${merge_base}..feature" > "${TMP}/test.diff"

  git checkout -q main 2>/dev/null || git checkout -q master
  git apply --binary "${TMP}/test.diff"

  [ -f binary.dat ]
  local actual
  actual=$(xxd -p binary.dat | tr -d '\n')
  [ "${actual}" = "0001020342494e415259fffe" ]
  [ "$(cat readme.txt)" = "modified" ]

  popd >/dev/null || return 1
}
