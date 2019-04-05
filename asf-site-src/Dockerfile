# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG DOCKER_TAG=master
ARG DOCKER_REPO=apache/yetus
FROM ${DOCKER_REPO}-build:${DOCKER_TAG}

WORKDIR /root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG GROUP_ID
ARG USER_ID
ARG USER_NAME

# hadolint ignore=DL3008
RUN apt-get -q update \
    && apt-get -q install --no-install-recommends -y \
      gnupg2 \
      gnupg-agent \
      pinentry-curses \
      pinentry-tty \
      subversion \
      sudo \
      vim \
      zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# we really want gpg2 to be the default gpg implementation
# it doesn't appear Xenial supports that though
RUN ln -s /usr/bin/gpg2 /usr/local/bin/gpg

RUN echo "export GPG_TTY=\$(tty)" >>  /root/.bashrc
RUN groupadd --non-unique -g "${GROUP_ID}" "${USER_NAME}"
RUN useradd -g "${GROUP_ID}" -u "${USER_ID}" -k /root -m "${USER_NAME}"
# shellcheck disable=SC2039,SC1117
RUN echo -e "${USER_NAME}\\tALL=NOPASSWD: ALL" > "/etc/sudoers.d/yetus-build-${USER_ID}"
ENV HOME /home/${USER_NAME}

WORKDIR /home/${USER_NAME}

USER ${USER_NAME}

RUN bundle config --global github.https true
RUN bundle config --global path "${BUNDLE_PATH}"
ENV GEM_HOME ${BUNDLE_PATH}

# pre-install most of the middleman stack to save time
# on re-launches
RUN gem install bundler \
    middleman:'~>3.4.0' \
    middleman-livereload \
    middleman-syntax \
    redcarpet \
    therubyracer \
    tzinfo-data \
    rake:10.3.1 \
    nokogiri:1.8.5

CMD ["/bin/bash"]
