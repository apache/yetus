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

ARG DOCKER_TAG=main
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
      apache2 \
      pinentry-curses \
      pinentry-tty \
      ruby-eventmachine \
      ruby-fastimage \
      ruby-ffi \
      ruby-listen \
      ruby-nokogiri \
      ruby-sassc \
      subversion \
      sudo \
      vim \
      zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# hadolint disable=DL3059
RUN echo "export GPG_TTY=\$(tty)" >>  /root/.bashrc
# hadolint disable=DL3059
RUN groupadd --non-unique -g "${GROUP_ID}" "${USER_NAME}" \
    && useradd -l -g "${GROUP_ID}" -u "${USER_ID}" -k /root -m "${USER_NAME}"
# hadolint disable=DL3059,SC2039,SC1117
RUN echo -e "${USER_NAME}\\tALL=NOPASSWD: ALL" > "/etc/sudoers.d/yetus-build-${USER_ID}" # pragma: allowlist secret
ENV HOME /home/${USER_NAME}

WORKDIR /home/${USER_NAME}

ENV APACHE_PID_FILE /tmp/website/pid
ENV APACHE_LOG_DIR /tmp/website/logdir
ENV APACHE_RUN_DIR /tmp/website/rundir
ENV APACHE_RUN_USER ${USER_NAME}
ENV APACHE_RUN_GROUP ${USER_NAME}

# hadolint ignore=DL3013
RUN mkdir -p /tmp/website/{logdir,rundir} \
    && chown -R ${USER_ID}:${GROUP_ID} /var/www/html /tmp/website \
    && ln -s /var/www/html /tmp/website/html \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && sed -i "s,Listen 80,Listen 8123," /etc/apache2/ports.conf \
    && sed -i "s,:80,:8123," /etc/apache2/sites-available/000-default.conf \
    && pip3 install --no-cache-dir git+https://github.com/linkchecker/linkchecker.git

USER ${USER_NAME}

RUN bundle config --global github.https true \
    && bundle config --global path "${BUNDLE_PATH}"
ENV GEM_HOME ${BUNDLE_PATH}

# pre-install most of the middleman stack to save time
# on re-launches
# hadolint ignore=DL3028
RUN gem install bundler \
        middleman:'4.4.2' \
        middleman-livereload \
        middleman-syntax \
        nokogiri:1.13.3 \
        sassc:2.4.0 \
        tzinfo-data

CMD ["/bin/bash"]
