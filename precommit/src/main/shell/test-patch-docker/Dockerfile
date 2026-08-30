
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

###############
#
# Example Apache Yetus Dockerfile that includes all functionality supported
# as well as enough bits to build and release Apache Yetus itself.
#
###############

FROM ubuntu:noble AS yetusbase

## NOTE to committers: if this gets moved from Xenial to something else, be
## sure to also fix the gpg link in asf-site-src as appropriate

WORKDIR /root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_TERSE=true

######
# Install some basic Apache Yetus requirements
# some git repos need ssh-client so do it too
# Adding libffi-dev for all the programming languages
# that take advantage of it. Also throw in
# xmllint here since so much links against libxml anyway.
######
# hadolint ignore=DL3008
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        curl \
        dirmngr \
        git \
        gpg \
        gpg-agent \
        libffi-dev \
        libicu-dev \
        libxml2-utils \
        locales \
        patch \
        pkg-config \
        rsync \
        software-properties-common \
        ssh-client \
        xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

###
# Set the locale
###
#hadolint ignore=DL3059
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

####
# Install GNU C/C++ and GNU make (everything generally needs this)
####
# hadolint ignore=DL3008
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        g++ \
        gcc \
        libc-dev \
        make \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

###
# Install golang as part of base so we can do each
# helper utility in parallel. go bins are typically
# statically linked, so this is perfectly safe.
###
# hadolint ignore=DL3008,DL3059
RUN add-apt-repository -y ppa:longsleep/golang-backports \
    && apt-get -q update \
    && apt-get -q install --no-install-recommends -y golang-go \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

############
# Fetch all of the non-conflicting bits in parallel
#############

####
# Install Apache Creadur RAT jar
####
FROM yetusbase AS yetusapacherat
ARG APACHE_RAT_VERSION=0.18
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /opt/apache-rat \
    && curl -f -s -L -o /tmp/rat.tgz \
        "https://archive.apache.org/dist/creadur/apache-rat-$APACHE_RAT_VERSION/apache-rat-$APACHE_RAT_VERSION-bin.tar.gz" \
    && curl -f -s -L -o /tmp/rat.tgz.sha512 \
        "https://archive.apache.org/dist/creadur/apache-rat-$APACHE_RAT_VERSION/apache-rat-$APACHE_RAT_VERSION-bin.tar.gz.sha512" \
    && echo "$(cat /tmp/rat.tgz.sha512)  /tmp/rat.tgz" > /tmp/rat.tgz.verify \
    && shasum -a 512 -c /tmp/rat.tgz.verify \
    && tar --strip-components 1 -C /opt/apache-rat -xpzf /tmp/rat.tgz \
    && rm /tmp/rat.tgz /tmp/rat.tgz.sha512 /tmp/rat.tgz.verify \
    && mv "/opt/apache-rat/apache-rat-$APACHE_RAT_VERSION.jar" /opt/apache-rat/apache-rat.jar

#####
# Install SpotBugs
#####
FROM yetusbase AS yetusspotbugs
ARG SPOTBUGS_VERSION=4.9.8
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/$SPOTBUGS_VERSION/spotbugs-$SPOTBUGS_VERSION.tgz -o spotbugs.tgz \
    && curl -sSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/$SPOTBUGS_VERSION/spotbugs-$SPOTBUGS_VERSION.tgz.sha1 -o spotbugs.tgz.sha1 \
    && echo -n "  spotbugs.tgz" >> spotbugs.tgz.sha1 \
    && shasum -c spotbugs.tgz.sha1 \
    && mkdir -p /opt/spotbugs \
    && tar -C /opt/spotbugs --strip-components 1 -xpf spotbugs.tgz \
    && rm spotbugs.tgz spotbugs.tgz.sha1 \
    && chmod a+rx /opt/spotbugs/bin/*
## NOTE: SPOTBUGS_HOME is set below

####
# Install shellcheck (shell script lint)
####
FROM yetusbase AS yetusshellcheck
ARG SHELLCHECK_VERSION=0.10.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
    https://github.com/koalaman/shellcheck/releases/download/v$SHELLCHECK_VERSION/shellcheck-v$SHELLCHECK_VERSION.linux."$(uname -m)".tar.xz \
        | tar --strip-components 1 --wildcards -xJf - '*/shellcheck' \
    && chmod a+rx shellcheck \
    && mv shellcheck /bin/shellcheck

####
# Install hadolint (dockerfile lint)
####
FROM yetusbase AS yetushadolint
ARG HADOLINT_VERSION=2.12.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN if [[ "$(uname -m)" == "x86_64" ]]; then curl -sSL \
        https://github.com/hadolint/hadolint/releases/download/v$HADOLINT_VERSION/hadolint-Linux-x86_64 \
        -o /bin/hadolint \
        && chmod a+rx /bin/hadolint; \
    elif [[ "$(uname -m)" == "aarch64" ]]; then curl -sSL \
        https://github.com/hadolint/hadolint/releases/download/v$HADOLINT_VERSION/hadolint-Linux-arm64 \
        -o /bin/hadolint \
        && chmod a+rx /bin/hadolint; \
    else \
        touch /bin/hadolint; \
    fi

####
# Install buf (protobuf lint)
####
FROM yetusbase AS yetusbuf
ARG BUF_VERSION=1.50.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
      https://github.com/bufbuild/buf/releases/download/v$BUF_VERSION/buf-Linux-"$(uname -m)".tar.gz \
      -o buf.tar.gz \
    && tar -xzf buf.tar.gz -C /usr/local --strip-components 1 \
    && rm buf.tar.gz

####
# Install bats (TAP-capable unit testing for shell scripts)
####
FROM yetusbase AS yetusbats
ARG BATS_VERSION=1.11.1
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN git clone --branch v$BATS_VERSION \
      https://github.com/bats-core/bats-core.git \
      /tmp/bats-core \
    && /tmp/bats-core/install.sh /opt/bats \
    && rm -rf /tmp/bats-core

####
# revive (golint on steroids)
####
FROM yetusbase AS yetusrevive
ARG REVIVE_VERSION=1.15.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
      https://github.com/mgechev/revive/releases/download/v$REVIVE_VERSION/revive_"$(go env GOOS)"_"$(go env GOARCH)".tar.gz \
      -o revive.tar.gz \
    && tar -xzf revive.tar.gz -C /usr/local/bin revive \
    && rm revive.tar.gz


####
# checkmake (Makefile linter)
####
FROM yetusbase AS yetuscheckmake
ARG CHECKMAKE_VERSION=0.3.2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
      https://github.com/checkmake/checkmake/releases/download/v$CHECKMAKE_VERSION/checkmake-v$CHECKMAKE_VERSION."$(go env GOOS)"."$(go env GOARCH)" \
      -o /usr/local/bin/checkmake \
    && chmod +x /usr/local/bin/checkmake

####
# golangci-lint (Multi-tool golang linter)
#
# NOTE: go must be installed prior to executing this block!
####
FROM yetusbase AS yetusgolangci
ARG GOLANGCILINT_VERSION=1.64.4
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
      https://github.com/golangci/golangci-lint/releases/download/v$GOLANGCILINT_VERSION/golangci-lint-$GOLANGCILINT_VERSION-"$(go env GOOS)"-"$(go env GOARCH)".tar.gz \
      -o golangcilint.tar.gz \
    && tar -xzf golangcilint.tar.gz -C /usr/local/bin --strip-components 1 \
    && rm golangcilint.tar.gz

########
#
#
# Content that needs to be installed in order due to packages...
#
#
########

FROM yetusbase
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

####
# Install java (first, since we want to dictate what form of Java)
####

####
# OpenJDK 21
# NOTE: This default only works when Apache Yetus is launched
# _in_ the container and not outside of it!
####
# hadolint ignore=DL3008,DL3059
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        default-jdk-headless \
        openjdk-21-jdk-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV SPOTBUGS_HOME=/opt/spotbugs

####
# Install ant
####
# hadolint ignore=DL3008
RUN apt-get -q update && apt-get -q install --no-install-recommends -y ant \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

####
# Install GNU automake and related
####
# hadolint ignore=DL3008,DL3059
RUN apt-get -q update && apt-get -q install --no-install-recommends -y autoconf automake libtool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

####
# Install cmake
####
# hadolint ignore=DL3008,DL3059
RUN apt-get -q update && apt-get -q install --no-install-recommends -y cmake \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

###
# Install docker
###
# hadolint ignore=DL3008,DL3059
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get -q update && apt-get -q install --no-install-recommends -y docker-ce docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

######
# Install maven
######
# hadolint ignore=DL3008,DL3059
ARG MVN_VERSION=3.9.9
ARG MVN_TGZ=apache-maven-$MVN_VERSION-bin.tar.gz
RUN curl -sSL \
        -o $MVN_TGZ \
        https://archive.apache.org/dist/maven/maven-3/$MVN_VERSION/binaries/$MVN_TGZ \
    && tar xzpf $MVN_TGZ \
    && mkdir -p /opt \
    && mv apache-maven-$MVN_VERSION /opt \
    && ln -s /opt/apache-maven-$MVN_VERSION/bin/mvn /bin \
    && curl -sSL \
        -o KEYS \
        https://downloads.apache.org/maven/KEYS \
    && gpg --import KEYS \
    && curl -sSL \
        -o $MVN_TGZ.asc \
         https://archive.apache.org/dist/maven/maven-3/$MVN_VERSION/binaries/$MVN_TGZ.asc \
    && gpg --verify $MVN_TGZ.asc $MVN_TGZ \
    && rm -rf $MVN_TGZ* /root/.gnupg KEYS

######
# Install perl
######
# hadolint ignore=DL3008,DL3059
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        perl \
        libperl-critic-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

######
# Install python3 and pylint3 (historical; most stuff uses "pylint" now)
# astroid and pylint go hand-in-hand.  Upgrade both at the same time.
######
#ARG PY3_ANSIBLE_VERSION=7.5.0
ARG PY3_ANSIBLELINT_VERSION=26.3.0
ARG PY3_ASTROID_VERSION=4.0.4
ARG PY3_CODESPELL_VERSION=2.4.2
ARG PY3_DETECT_SECRETS=1.5.0
ARG PY3_PYLINT_VERSION=4.0.5
ARG PY3_YAMLLINT_VERSION=1.38.0
# hadolint ignore=DL3008
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        python3-full \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-dateutil \
        python3-dockerpty \
        python3-yaml \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv --copies /usr/local \
    && /usr/local/bin/pip install --no-cache-dir -v \
        python-dateutil \
        ansible-lint==$PY3_ANSIBLELINT_VERSION \
        astroid==$PY3_ASTROID_VERSION \
        codespell==$PY3_CODESPELL_VERSION \
        detect-secrets==$PY3_DETECT_SECRETS \
        pylint==$PY3_PYLINT_VERSION \
        yamllint==$PY3_YAMLLINT_VERSION \
    && ln -sf /usr/local/bin/pylint /usr/local/bin/pylint3 \
    && chmod -R a+w /usr/local/lib/python3.12/site-packages /usr/local/bin \
    && rm -rf /root/.cache /root/.config /root/.local

####
# Install ruby and associated bits
###
ARG RUBY_BUNDLER_VERSION=4.0.8
ARG RUBY_RAKE_VERSION=13.2.1
ARG RUBY_RUBOCOP_VERSION=1.86.0
# hadolint ignore=DL3008
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc \
    && apt-get -q update && apt-get -q install --no-install-recommends -y \
       ruby \
       ruby-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && gem install bundler -v $RUBY_BUNDLER_VERSION \
    && gem install rake -v $RUBY_RAKE_VERSION \
    && gem install rubocop -v $RUBY_RUBOCOP_VERSION \
    && rm -rf /root/.gem /root/.config /root/.local
# set some reasonable defaults for ruby
# user's can always override these as needed
ENV PATH=${PATH}:/var/tmp/.bundler-gems/bin
ENV BUNDLE_PATH=/var/tmp/.bundler-gems

###
# Install npm and JSHint
###
ARG JSHINT_VERSION=2.13.6
ARG MARKDOWNLINTCLI_VERSION=0.48.0
ARG JSONLINT_VERSION=17.0.1
# hadolint ignore=DL3008
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get -q update \
    && apt-get -q install --no-install-recommends -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g \
        jshint@$JSHINT_VERSION \
        @prantlf/jsonlint@$JSONLINT_VERSION \
        markdownlint-cli@$MARKDOWNLINTCLI_VERSION \
    && rm -rf /root/.npm /root/.config /root/.local

#####
# Now all the stuff that was built in parallel
#####

COPY --from=yetusapacherat /opt/apache-rat /opt/apache-rat
COPY --from=yetusspotbugs /opt/spotbugs /opt/spotbugs
COPY --from=yetusshellcheck /bin/shellcheck /bin/shellcheck
COPY --from=yetushadolint /bin/hadolint /bin/hadolint
COPY --from=yetusbuf /usr/local/bin/buf /usr/local/bin/buf
COPY --from=yetusbats /opt/bats /opt/bats
RUN ln -s /opt/bats/bin/bats /usr/local/bin/bats

COPY --from=yetusrevive /usr/local/bin/revive /usr/local/bin
COPY --from=yetuscheckmake /usr/local/bin/checkmake /usr/local/bin
COPY --from=yetusgolangci /usr/local/bin/golangci-lint /usr/local/bin

####
# YETUS CUT HERE
# Magic text above! Everything from here on is ignored
# by Yetus, so could include anything not needed
# by your testing environment
###
