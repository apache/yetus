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

@test "yetus_sort_array (empty)" {
  yetus_sort_array ARRAY
}

@test "yetus_sort_array (single value)" {
  ARRAY=("value")
  yetus_sort_array ARRAY
}

@test "yetus_sort_array (multiple value)" {
  ARRAY=("b" "c" "a")
  preifsod=$(echo "${IFS}" | od -c)
  yetus_sort_array ARRAY
  postifsod=$(echo "${IFS}" | od -c)

  [ "${ARRAY[0]}" = "a" ]
  [ "${ARRAY[1]}" = "b" ]
  [ "${ARRAY[2]}" = "c" ]
  [ "${preifsod}" = "${postifsod}" ]
}

@test "yetus_sort_array (multiple duplicate values)" {
  ARRAY=("b" "c" "b" "a" "a" "c")
  preifsod=$(echo "${IFS}" | od -c)
  yetus_sort_array ARRAY
  postifsod=$(echo "${IFS}" | od -c)

  [ "${ARRAY[0]}" = "a" ]
  [ "${ARRAY[1]}" = "a" ]
  [ "${ARRAY[2]}" = "b" ]
  [ "${ARRAY[3]}" = "b" ]
  [ "${ARRAY[4]}" = "c" ]
  [ "${ARRAY[5]}" = "c" ]

  [ "${preifsod}" = "${postifsod}" ]
}