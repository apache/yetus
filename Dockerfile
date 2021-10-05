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

ARG DOCKER_TAG=main
ARG DOCKER_REPO=apache/yetus
FROM ${DOCKER_REPO}-base:${DOCKER_TAG}

LABEL org.apache.yetus=""
COPY . /ysrc/
COPY entrypoint.sh /entrypoint.sh
RUN chmod a+rx /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# hadolint ignore=DL3003,DL3059
RUN cd /ysrc \
    && mvn clean install -DskipTests \
    && rm -rf /.m2 \
    && cd /usr \
    && tar xzpf /ysrc/yetus-dist/target/artifacts/apache-yetus*bin.tar.gz \
       --strip 1 \
    && rm -rf /ysrc /root/.m2
