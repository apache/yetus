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

create_fake () {
  mkdir "${TMP}/j"
  touch "${TMP}/j/k"
  ln -s j "${TMP}/l"
  mkdir "${TMP}/m"
  touch "${TMP}/m/n"
  ln -s m "${TMP}/o"
}


@test "yetus_relative_dir (simple dir)" {
  create_fake
  run yetus_relative_dir "${TMP}" "${TMP}/j"
  [ "${status}" -eq 0 ]
  [ "${output}" = "j" ]
}

@test "yetus_relative_dir (simple file)" {
  create_fake
  run yetus_relative_dir "${TMP}/j" "${TMP}/j/k"
  [ "${status}" -eq 0 ]
  [ "${output}" = "k" ]
}

@test "yetus_relative_dir (simple symlink)" {
  create_fake
  run yetus_relative_dir "${TMP}" "${TMP}/l"
  [ "${status}" -eq 0 ]
  [ "${output}" = "l" ]
}

@test "yetus_relative_dir (fail simple dir)" {
  create_fake
  run yetus_relative_dir "${TMP}/j" "${TMP}/m"
  [ "${status}" -eq 1 ]
  [ "${output}" = "${TMP}/m" ]
}

@test "yetus_relative_dir (fail simple file)" {
  create_fake
  run yetus_relative_dir "${TMP}/j" "${TMP}/m/n"
  [ "${status}" -eq 1 ]
  [ "${output}" = "${TMP}/m/n" ]
}

@test "yetus_relative_dir (fail simple symlink)" {
  create_fake
  run yetus_relative_dir "${TMP}/j" "${TMP}/o"
  [ "${status}" -eq 1 ]
  [ "${output}" = "${TMP}/o" ]
}