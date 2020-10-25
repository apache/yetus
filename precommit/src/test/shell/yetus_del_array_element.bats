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

@test "yetus_del_array_element (empty array)" {
  yetus_del_array_element ARRAY value
  [ "${#ARRAY[@]}" -eq 0 ]
}

@test "yetus_del_array_element (not exist)" {
  ARRAY=("val2")
  yetus_del_array_element ARRAY val1
  [ "${ARRAY[0]}" = val2 ]
  [ "${#ARRAY[@]}" -eq 1 ]
}

@test "yetus_add_array_element (single exist)" {
  ARRAY=("val1")
  yetus_del_array_element ARRAY val1
  echo ">${ARRAY[*]}<"
  [ "${#ARRAY[@]}" -eq 0 ]
}

@test "yetus_del_array_element (size 2, exist)" {
  ARRAY=("val2" "val1")
  yetus_del_array_element ARRAY val1
  [ "${ARRAY[0]}" = val2 ]
  [ "${ARRAY[1]}" = '' ]
  [ "${#ARRAY[@]}" -eq 1 ]
}

@test "yetus_del_array_element (size 2, exist, squash)" {
  ARRAY=("val2" "val1")
  yetus_del_array_element ARRAY val2
  [ "${ARRAY[0]}" = val1 ]
  [ "${ARRAY[1]}" = '' ]
  [ "${#ARRAY[@]}" -eq 1 ]
}

@test "yetus_del_array_element (size 3, exist, squash)" {
  ARRAY=("val3" "val2" "val1")
  yetus_del_array_element ARRAY val2
  [ "${ARRAY[0]}" = val3 ]
  [ "${ARRAY[1]}" = val1 ]
  [ "${#ARRAY[@]}" -eq 2 ]
}