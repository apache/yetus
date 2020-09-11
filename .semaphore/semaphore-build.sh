#!/usr/bin/env bash
#
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

PRECOMMITDIR=precommit/src/main/shell

"${PRECOMMITDIR}/test-patch.sh" \
  --plugins=all \
  --mvn-custom-repos \
  --mvn-custom-repos-dir=/tmp/yetus-m2 \
  --patch-dir=/tmp/yetus-out \
  --tests-filter=checkstyle,javadoc,rubocop,test4tests \
  --docker \
  --pylint=pylint2 \
  --dockerfile="${PRECOMMITDIR}/test-patch-docker/Dockerfile" \
  --docker-cache-from=apache/yetus-base:main,ubuntu:focal
