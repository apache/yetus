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

declare -i result

echo "::group::mvn install"
mvn --batch-mode install
echo "::endgroup::"

echo "::group::mvn site"
mvn --batch-mode site site:stage </dev/null
echo "::endgroup::"

echo "::group::tar"
tar -C /tmp/website/html --strip-components 1 \
  -xpf yetus-dist/target/artifacts/apache-yetus-*-SNAPSHOT-site.tar.gz
echo "::endgroup::"

echo "::group::start apache httpd"
apache2
echo "::endgroup::"

echo "::group::linkchecker"
linkchecker \
  --ignore-url 'http://localhost:8123/documentation/[0-9]+.[0-9]+.[0-9]+' \
  --ignore-url 'resources/fonts/dejavu.css' \
  --no-robots --file-output=csv \
  http://localhost:8123
result=$?
echo "::endgroup::"

#
# urlname;parentname;base;result;warningstring;infostring;valid;url;line;column;name;dltime;size;checktime;cached;level;modified
# in-page reference: $1
# generated page: $2
# error code: $4
# expected page: $8
#
echo "::group::github actions check annotations"
grep -v '^#' linkchecker-out.csv \
 | grep -v '^urlname' \
 | awk '-F;' \
   '{print "::error::["$4"] mdref: ("$1") | pageref: "$2" | expected page: "$8}'
echo "::endgroup::"
exit ${result}
