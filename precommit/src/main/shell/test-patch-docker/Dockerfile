
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

FROM ubuntu:xenial

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
    ca-certificates \
    curl \
    dirmngr \
    git \
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
RUN git clone --branch v1.1.0 \
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
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository -y \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
RUN apt-get -q update && apt-get -q install --no-install-recommends -y docker-ce \
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
RUN curl -fsSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/4.0.1/spotbugs-4.0.1.tgz -o spotbugs.tgz \
    && curl -fsSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/4.0.1/spotbugs-4.0.1.tgz.sha1 -o spotbugs.tgz.sha1 \
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
######
RUN add-apt-repository -y ppa:deadsnakes/ppa
# hadolint ignore=DL3008
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        python3.7 \
        python3.7-dev \
   && apt-get clean \
   && rm -rf /var/lib/apt/lists/*
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
   && python3.7 get-pip.py \
   && rm /usr/local/bin/pip
# astroid and pylint go hand-in-hand.  Upgrade both at the same time.
# hadolint ignore=DL3013
RUN pip3 install -v \
        astroid==2.3.3 \
        docker-compose==1.25.4 \
        pylint==2.4.4 \
        yamllint==1.20.0 \
    && rm -rf /root/.cache
RUN mv /usr/local/bin/pylint /usr/local/bin/pylint3

######
# Install python, pylint2, and yamllint
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        python \
        python2.7 \
        python-pip \
        python-pkg-resources \
        python-setuptools \
        python-wheel \
        python-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN pip2 install -v \
        astroid==1.6.5 \
        configparser==4.0.2 \
        pylint==1.9.2 \
        python-dateutil==2.7.3 \
    && rm -rf /root/.cache
RUN mv /usr/local/bin/pylint /usr/local/bin/pylint2

#####
# all of the world's python2 code stopped working, right?
#####
RUN ln -s /usr/local/bin/pylint3 /usr/local/bin/pylint

####
# Install ruby and associated bits
###
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
    ruby \
    ruby-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN gem install rake -v 13.0.1 \
    && gem install rubocop -v 0.80.1 \
    && gem install bundler -v 2.1.4 \
    && rm -rf /root/.gem
# set some reasonable defaults for ruby
# user's can always override these as needed
ENV PATH ${PATH}:/var/tmp/.bundler-gems/bin
ENV BUNDLE_PATH /var/tmp/.bundler-gems

####
# Install shellcheck (shell script lint)
####
RUN curl -L -s -S \
   https://github.com/koalaman/shellcheck/releases/download/v0.7.0/shellcheck-v0.7.0.linux.x86_64.tar.xz \
   | tar --strip-components 1 --wildcards -xJf - '*/shellcheck' \
   && chmod a+rx shellcheck \
   && mv shellcheck /bin/shellcheck \
   && shasum -a 512 /bin/shellcheck \
   | awk '$1!="ccc6ffa932ab6f98dd2e14bd6175282af8f2131d5f07fe85a55a0f0058a45a55e7284b31f0c94ebb5738a80370c405094a9b0f01c342888ef2945882b18b655d" {exit(1)}'


###
# Install hadolint
####
RUN curl -L -s -S \
   https://github.com/hadolint/hadolint/releases/download/v1.17.5/hadolint-Linux-x86_64 \
   -o /bin/hadolint && \
   chmod a+rx /bin/hadolint && \
   shasum -a 512 /bin/hadolint | \
   awk '$1!="550b861641866685292417c02a290853592ea5ad9845d40a6d9bfab6ecfc1b03c24a41c3a44d27154abb4fff373d80972784a148dbc191f8455de706ae331845" {exit(1)}'

###
# Install npm and JSHint
###
# hadolint ignore=DL3008
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get -q install --no-install-recommends -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g jshint@2.11.0 markdownlint-cli@0.22.0 \
    && rm -rf /root/.npm

###
# Install golang and supported helpers
###
# hadolint ignore=DL3008
RUN add-apt-repository -y ppa:longsleep/golang-backports \
    && apt-get -q update \
    && apt-get -q install --no-install-recommends -y golang-go \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN go get -u github.com/mgechev/revive \
    && go get -u github.com/mrtazz/checkmake \
    && (GO111MODULE=on go get github.com/golangci/golangci-lint/cmd/golangci-lint@v1.24.0) \
    && mv /root/go/bin/* /usr/local/bin \
    && rm -rf /root/go /root/.cache/go-build

RUN curl -L -s -S \
      https://github.com/bufbuild/buf/releases/download/v0.18.1/buf-Linux-x86_64.tar.gz \
      -o buf.tar.gz \
    && shasum -a 256 buf.tar.gz \
    | awk '$1!="82a35087879c35449f336a37ab4b655e43992615140f4c37f1f0187ce4e6e6db" {exit(1)}' \
    && tar -xzf buf.tar.gz -C /usr/local --strip-components 1 \
    && rm buf.tar.gz

####
# YETUS CUT HERE
# Anthing after the above line is ignored by Yetus, so could
# include other requirements not needed by your development
# (but not build) environment
###
