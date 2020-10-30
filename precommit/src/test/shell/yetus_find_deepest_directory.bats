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

@test "yetus_find_deepest_directory (simple find1)" {
  # shellcheck disable=SC2034
  ARRAY=("/a")
  run yetus_find_deepest_directory ARRAY "/a"
  [ "${output}" = "/a" ]
}

@test "yetus_find_deepest_directory (simple find2)" {
  # shellcheck disable=SC2034
  ARRAY=("/a")
  run yetus_find_deepest_directory ARRAY "/a/1"
  [ "${output}" = "/a" ]
}

@test "yetus_find_deepest_directory (simple fail)" {
  # shellcheck disable=SC2034
  ARRAY=("/a")
  run yetus_find_deepest_directory ARRAY "/b/1"
  [ "${output}" = "" ]
}

@test "yetus_find_deepest_directory (two path find)" {
  # shellcheck disable=SC2034
  ARRAY=("/a/b" "/a/c")
  run yetus_find_deepest_directory ARRAY "/a/b/k"
  [ "${output}" = "/a/b" ]
}

@test "yetus_find_deepest_directory (two+two path find)" {
  # shellcheck disable=SC2034
  ARRAY=("/a/b/c" "/a/b/d")
  run yetus_find_deepest_directory ARRAY "/a/b/d/j"
  [ "${output}" = "/a/b/d" ]
}


@test "yetus_find_deepest_directory (complex path find1)" {
  # shellcheck disable=SC2034
  ARRAY=("/a/b/c" "/a/b/d" "/a/b/e" "/a/b/d/f" "/a/b/d/g")
  run yetus_find_deepest_directory ARRAY "/a/b/d"
  [ "${output}" = "/a/b/d" ]
}

@test "yetus_find_deepest_directory (complex path find2)" {
  # shellcheck disable=SC2034
  ARRAY=("/a/b" "/a/b/c" "/a/b/d/f/k/j" "/a/b/d/g")
  run yetus_find_deepest_directory ARRAY "/a/b/d/f/k/e"
  [ "${output}" = "/a/b" ]
}

@test "yetus_find_deepest_directory (complex path find3)" {
  # shellcheck disable=SC2034
  ARRAY=("/a/b" "/a/b/c" "/a/b/d" "/a/b/d/f/k/j" "/a/b/d/g")
  run yetus_find_deepest_directory ARRAY "/a/b/d/f/k/e"
  [ "${output}" = "/a/b/d" ]
}