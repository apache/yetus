
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

FROM ubuntu:focal AS yetusbase

## NOTE to committers: if this gets moved from Xenial to something else, be
## sure to also fix the gpg link in asf-site-src as appropriate

WORKDIR /root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_TERSE true

######
# Install some basic Apache Yetus requirements
# some git repos need ssh-client so do it too
# Adding libffi-dev for all the programming languages
# that take advantage of it.
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
        locales \
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
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

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
FROM yetusbase AS apacherat
ARG APACHE_RAT_VERSION=0.13
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /opt/apache-rat \
    && curl -f -s -L -o /tmp/rat.tgz \
        "https://dlcdn.apache.org/creadur/apache-rat-$APACHE_RAT_VERSION/apache-rat-$APACHE_RAT_VERSION-bin.tar.gz" \
    && shasum -a 512 /tmp/rat.tgz \
        | awk '$1!="2c1e12eace7b80a9b6373c2f5080fbf63d3fa8d9248f3a17bd05de961cd3ca3c4549817b8b7320a84f0c323194edad0abdb86bdfec3976227a228e2143e14a54" {exit(1)}' \
    && tar --strip-components 1 -C /opt/apache-rat -xpzf /tmp/rat.tgz \
    && rm /tmp/rat.tgz \
    && mv /opt/apache-rat/apache-rat-$APACHE_RAT_VERSION.jar /opt/apache-rat/apache-rat.jar

#####
# Install SpotBugs
#####
FROM yetusbase AS spotbugs
ARG SPOTBUGS_VERSION=4.4.1
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/$SPOTBUGS_VERSION/spotbugs-$SPOTBUGS_VERSION.tgz -o spotbugs.tgz \
    && curl -sSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/$SPOTBUGS_VERSION/spotbugs-$SPOTBUGS_VERSION.tgz.sha1 -o spotbugs.tgz.sha1 \
    && echo -n "  spotbugs.tgz" >> spotbugs.tgz.sha1 \
    && shasum -c spotbugs.tgz.sha1 \
    && mkdir -p /opt/spotbugs \
    && tar -C /opt/spotbugs --strip-components 1 -xpf spotbugs.tgz \
    && rm spotbugs.tgz spotbugs.tgz.sha1 \
    && chmod a+rx /opt/spotbugs/bin/*
ENV SPOTBUGS_HOME /opt/spotbugs

####
# Install shellcheck (shell script lint)
####
FROM yetusbase AS shellcheck
ARG SHELLCHECK_VERSION=0.7.2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
    https://github.com/koalaman/shellcheck/releases/download/v$SHELLCHECK_VERSION/shellcheck-v$SHELLCHECK_VERSION.linux.x86_64.tar.xz \
        | tar --strip-components 1 --wildcards -xJf - '*/shellcheck' \
    && chmod a+rx shellcheck \
    && mv shellcheck /bin/shellcheck \
    && shasum -a 512 /bin/shellcheck \
    | awk '$1!="0977b3d34f6e7e6d5c95ba46ca648ab55a6168e6304484d0daffefb0724c2309f9b0a2c8121d72ddcee977ba5614a5e7e83efc419b294600e0f73d748ec263a0" {exit(1)}'

####
# Install hadolint (dockerfile lint)
####
FROM yetusbase AS hadolint
ARG HADOLINT_VERSION=2.7.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
        https://github.com/hadolint/hadolint/releases/download/v$HADOLINT_VERSION/hadolint-Linux-x86_64 \
        -o /bin/hadolint \
    && chmod a+rx /bin/hadolint \
    && shasum -a 512 /bin/hadolint \
    | awk '$1!="176eb3fd9f6a3cb9eda7f23b69a98069ea77cefc2078cf6234ebb3cb45897078934ee6925bec32b6e5c10915e8ff39bf24ebec36f37b226a2c8c4068a456ee30" {exit(1)}'

####
# Install buf (protobuf lint)
####
FROM yetusbase AS buf
ARG BUF_VERSION=0.56.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
      https://github.com/bufbuild/buf/releases/download/v$BUF_VERSION/buf-Linux-x86_64.tar.gz \
      -o buf.tar.gz \
    && shasum -a 512 buf.tar.gz \
    | awk '$1!="52b8ef7ba924b6679d59134df0765fe456749e83a9842ce289875489261b62b5261a21fc9849a22778a6afb3c5fcc6e86b856e06d1b62564d794c3e8f4da10ca" {exit(1)}' \
    && tar -xzf buf.tar.gz -C /usr/local --strip-components 1 \
    && rm buf.tar.gz

####
# Install bats (TAP-capable unit testing for shell scripts)
####
FROM yetusbase AS bats
ARG BATS_VERSION=1.4.1
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN git clone --branch v$BATS_VERSION \
      https://github.com/bats-core/bats-core.git \
      /tmp/bats-core \
    && /tmp/bats-core/install.sh /opt/bats \
    && rm -rf /tmp/bats-core


####
# revive (golint on steroids)
####
FROM yetusbase AS revive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN go get -u github.com/mgechev/revive


####
# checkmake (Makefile linter)
#
# requires go 1.15 as of 2021-03-02
#
####
FROM yetusbase AS checkmake
ARG CHECKMAKE_VERSION=8915bd40945dd20b153cfcecb787ecdb5020ba38
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV BUILDER_NAME='Apache Yetus'
ENV BUILDER_EMAIL='dev@apache.yetus.org'
RUN git clone \
      https://github.com/mrtazz/checkmake.git /tmp/checkmake \
    && git -C /tmp/checkmake checkout $CHECKMAKE_VERSION \
    && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 make -C /tmp/checkmake binaries \
    && make -C /tmp/checkmake test

####
# golangci-lint (Multi-tool golang linter)
####
FROM yetusbase as golangci
ARG GOLANGCILINT_VERSION=1.42.1
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN (GO111MODULE=on go get github.com/golangci/golangci-lint/cmd/golangci-lint@v$GOLANGCILINT_VERSION)

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
# Install java (first, since we want to dicate what form of Java)
####

####
# OpenJDK 8
####
# hadolint ignore=DL3008
RUN apt-get -q update && apt-get -q install --no-install-recommends -y openjdk-8-jdk-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

####
# OpenJDK 11 (but keeps default to JDK8)
# NOTE: This default only works when Apache Yetus is launched
# _in_ the container and not outside of it!
####
# hadolint ignore=DL3008,DL3059
RUN apt-get -q update && apt-get -q install --no-install-recommends -y default-jre-headless openjdk-11-jdk-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && update-java-alternatives -s java-1.8.0-openjdk-amd64 \
    && rm -f /usr/lib/jvm/default-java \
    && ln -s java-8-openjdk-amd64 /usr/lib/jvm/default-java
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

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
# hadolint ignore=DL3059
RUN curl -sSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
# hadolint ignore=DL3008,DL3059
RUN add-apt-repository -y \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable" \
    && apt-get -q update && apt-get -q install --no-install-recommends -y docker-ce \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

######
# Install maven
######
# hadolint ignore=DL3008,DL3059
RUN apt-get -q update && apt-get -q install --no-install-recommends -y maven \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
# Install python3 and pylint3
# astroid and pylint go hand-in-hand.  Upgrade both at the same time.
######
ARG PY3_ANSIBLE_VERSION=4.7.0
ARG PY3_ANSIBLELINT_VERSION=5.2.1
ARG PY3_ASTROID_VERSION=2.8.0
ARG PY3_CODESPELL_VERSION=2.1.0
ARG PY3_DETECT_SECRETS=1.0.3
ARG PY3_DOCKER_COMPOSE=1.29.2
ARG PY3_PYLINT_VERSION=2.11.1
ARG PY3_YAMLLINT_VERSION=1.26.3
# hadolint ignore=DL3008
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        python3 \
        python3-bcrypt \
        python3-cffi \
        python3-cryptography \
        python3-dateutil \
        python3-dev \
        python3-isort \
        python3-dockerpty \
        python3-nacl \
        python3-pyrsistent \
        python3-setuptools \
        python3-singledispatch \
        python3-six \
        python3-wheel \
        python3-wrapt \
        python3-yaml \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
    && python3 /tmp/get-pip.py \
    && rm /usr/local/bin/pip /tmp/get-pip.py \
    && pip3 install --no-cache-dir -v \
        ansible==$PY3_ANSIBLE_VERSION \
        ansible-lint==$PY3_ANSIBLELINT_VERSION \
        astroid==$PY3_ASTROID_VERSION \
        codespell==$PY3_CODESPELL_VERSION \
        detect-secrets==$PY3_DETECT_SECRETS \
        docker-compose==$PY3_DOCKER_COMPOSE \
        pylint==$PY3_PYLINT_VERSION \
        yamllint==$PY3_YAMLLINT_VERSION \

    && rm -rf /root/.cache \
    && mv /usr/local/bin/pylint /usr/local/bin/pylint3 \
    && ln -s /usr/local/bin/pylint3 /usr/local/bin/pylint \
    && ln -s /usr/local/bin/pip3 /usr/local/bin/pip

####
# Install ruby and associated bits
###
ARG RUBY_BUNDLER_VERSION=2.2.27
ARG RUBY_RAKE_VERSION=13.0.3
ARG RUBY_RUBOCOP_VERSION=1.21.0
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
    && rm -rf /root/.gem
# set some reasonable defaults for ruby
# user's can always override these as needed
ENV PATH ${PATH}:/var/tmp/.bundler-gems/bin
ENV BUNDLE_PATH /var/tmp/.bundler-gems

###
# Install npm and JSHint
###
ARG JSHINT_VERSION=2.13.1
ARG MARKDOWNLINTCLI_VERSION=0.28.1
# hadolint ignore=DL3008
RUN curl -sSL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get -q install --no-install-recommends -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g \
        jshint@$JSHINT_VERSION \
        markdownlint-cli@0$MARKDOWNLINTCLI_VERSION \
    && rm -rf /root/.npm

#####
# Now all the stuff that was built in parallel
#####

COPY --from=apacherat /opt/apache-rat /opt/apache-rat
COPY --from=spotbugs /opt/spotbugs /opt/spotbugs
COPY --from=shellcheck /bin/shellcheck /bin/shellcheck
COPY --from=hadolint /bin/hadolint /bin/hadolint
COPY --from=buf /usr/local/bin/buf /usr/local/bin/buf
COPY --from=bats /opt/bats /opt/bats
RUN ln -s /opt/bats/bin/bats /usr/local/bin/bats

COPY --from=revive /root/go/bin/* /usr/local/bin
COPY --from=checkmake /tmp/checkmake/checkmake /usr/local/bin
COPY --from=golangci /root/go/bin/* /usr/local/bin

####
# YETUS CUT HERE
# Magic text above! Everything from here on is ignored
# by Yetus, so could include anything not needed
# by your testing environment
###
