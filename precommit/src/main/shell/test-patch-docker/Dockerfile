
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

FROM ubuntu:focal

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
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

####
# Install java (first, since we want to dicate what form of Java)
####

####
# OpenJDK 8
####
RUN apt-get -q update && apt-get -q install --no-install-recommends -y openjdk-8-jdk-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

####
# OpenJDK 11 (but keeps default to JDK8)
# NOTE: This default only works when Apache Yetus is launched
# _in_ the container and not outside of it!
####
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
RUN apt-get -q update && apt-get -q install --no-install-recommends -y ant \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

####
# Install GNU automake, GNU make, and related
####
RUN apt-get -q update && apt-get -q install --no-install-recommends -y autoconf automake libtool make \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

####
# Install bats (TAP-capable unit testing for shell scripts)
####
RUN git clone --branch v1.2.1 \
      https://github.com/bats-core/bats-core.git \
      /tmp/bats-core \
    && /tmp/bats-core/install.sh /usr/local \
    && rm -rf /tmp/bats-core

####
# Install cmake
####
RUN apt-get -q update && apt-get -q install --no-install-recommends -y cmake \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

###
# Install docker
###
RUN curl -sSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository -y \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable" \
    && apt-get -q update && apt-get -q install --no-install-recommends -y docker-ce \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

######
# Install findbugs
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y findbugs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
ENV FINDBUGS_HOME /usr

#####
# Install SpotBugs
#####
RUN curl -sSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/4.1.2/spotbugs-4.1.2.tgz -o spotbugs.tgz \
    && curl -sSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/4.1.2/spotbugs-4.1.2.tgz.sha1 -o spotbugs.tgz.sha1 \
    && echo -n "  spotbugs.tgz" >> spotbugs.tgz.sha1 \
    && shasum -c spotbugs.tgz.sha1 \
    && mkdir -p /opt/spotbugs \
    && tar -C /opt/spotbugs --strip-components 1 -xpf spotbugs.tgz \
    && rm spotbugs.tgz spotbugs.tgz.sha1 \
    && chmod a+rx /opt/spotbugs/bin/*
ENV SPOTBUGS_HOME /opt/spotbugs

####
# Install GNU C/C++
####
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        g++ \
        gcc \
        libc-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

######
# Install maven
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y maven \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

######
# Install perl
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        perl \
        libperl-critic-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

######
# Install python3 and pylint3
# astroid and pylint go hand-in-hand.  Upgrade both at the same time.
######
# hadolint ignore=DL3008,DL3013
RUN add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get -q update && apt-get -q install --no-install-recommends -y \
        python3 \
        python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
    && python3 /tmp/get-pip.py \
    && rm /usr/local/bin/pip /tmp/get-pip.py \
    && pip3 install -v \
        astroid==2.4.2 \
        docker-compose==1.26.2 \
        pylint==2.6.0 \
        yamllint==1.24.2 \
    && rm -rf /root/.cache \
    && mv /usr/local/bin/pylint /usr/local/bin/pylint3

######
# Install python, pylint2, and yamllint
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        python2 \
        python-pkg-resources \
        python-setuptools \
        python-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
    && python2 /tmp/get-pip.py \
    && rm /tmp/get-pip.py /usr/local/bin/pip \
    && pip2 install -v \
        astroid==1.6.5 \
        configparser==4.0.2 \
        isort==4.3.21 \
        pylint==1.9.2 \
        python-dateutil==2.7.3 \
    && rm -rf /root/.cache \
    && mv /usr/local/bin/pylint /usr/local/bin/pylint2

#####
# all of the world's python2 code stopped working, right?
#####
RUN ln -s /usr/local/bin/pylint3 /usr/local/bin/pylint

####
# Install ruby and associated bits
###
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc \
    && apt-get -q update && apt-get -q install --no-install-recommends -y \
       ruby \
       ruby-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && gem install rake -v 13.0.1 \
    && gem install rubocop -v 0.90.0 \
    && gem install bundler -v 2.1.4 \
    && rm -rf /root/.gem
# set some reasonable defaults for ruby
# user's can always override these as needed
ENV PATH ${PATH}:/var/tmp/.bundler-gems/bin
ENV BUNDLE_PATH /var/tmp/.bundler-gems

####
# Install shellcheck (shell script lint)
####
RUN curl -sSL \
    https://github.com/koalaman/shellcheck/releases/download/v0.7.1/shellcheck-v0.7.1.linux.x86_64.tar.xz \
        | tar --strip-components 1 --wildcards -xJf - '*/shellcheck' \
    && chmod a+rx shellcheck \
    && mv shellcheck /bin/shellcheck \
    && shasum -a 512 /bin/shellcheck \
    | awk '$1!="aae813283d49f18f95a205dca1c5184267d07534a08abc952ebea1958fee06f8a0207373b6770a083079ba875458ea9da443f2b9910a50dcd93b935048bc14f5" {exit(1)}'

###
# Install hadolint
####
RUN curl -sSL \
        https://github.com/hadolint/hadolint/releases/download/v1.18.0/hadolint-Linux-x86_64 \
        -o /bin/hadolint \
    && chmod a+rx /bin/hadolint \
    && shasum -a 512 /bin/hadolint \
    | awk '$1!="df27253d374c143a606483b07a26234ac7b4bca40b4eba53e79609c81aa70146e7d5c145f90dcec71d6d1aad1048b7d9d2de68d92284f48a735d04d19c5c5559" {exit(1)}'

###
# Install npm and JSHint
###
# hadolint ignore=DL3008
RUN curl -sSL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get -q install --no-install-recommends -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g jshint@2.12.0 markdownlint-cli@0.23.2 \
    && rm -rf /root/.npm

###
# Install golang and supported helpers
###
# hadolint ignore=DL3008
RUN add-apt-repository -y ppa:longsleep/golang-backports \
    && apt-get -q update \
    && apt-get -q install --no-install-recommends -y golang-go \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && go get -u github.com/mgechev/revive \
    && go get -u github.com/mrtazz/checkmake \
    && (GO111MODULE=on go get github.com/golangci/golangci-lint/cmd/golangci-lint@v1.30.0) \
    && mv /root/go/bin/* /usr/local/bin \
    && rm -rf /root/go /root/.cache/go-build

RUN curl -sSL \
      https://github.com/bufbuild/buf/releases/download/v0.21.0/buf-Linux-x86_64.tar.gz \
      -o buf.tar.gz \
    && shasum -a 256 buf.tar.gz \
    | awk '$1!="95aba62ac0ecc5a9120cc58c65cdcc85038633a816bddfe8398c5ae3b32803f1" {exit(1)}' \
    && tar -xzf buf.tar.gz -C /usr/local --strip-components 1 \
    && rm buf.tar.gz

####
# YETUS CUT HERE
# Anthing after the above line is ignored by Yetus, so could
# include other requirements not needed by your development
# (but not build) environment
###
