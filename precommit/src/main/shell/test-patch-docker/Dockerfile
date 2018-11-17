
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
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
    curl \
    git \
    locales \
    pkg-config \
    rsync \
    software-properties-common \
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

######
# Install findbugs
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y findbugs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
ENV FINDBUGS_HOME /usr

####
# Install GNU C/C++
####
RUN apt-get -q update && apt-get -q install --no-install-recommends -y g++ gcc libc-dev \
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
RUN apt-get -q update && apt-get -q install --no-install-recommends -y perl libperl-critic-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

######
# Install python and pylint
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y python \
    python2.7 \
    python-pip \
    python-pkg-resources \
    python-setuptools \
    python-wheel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN pip2 install -v pylint==1.9.2 python-dateutil==2.7.3

####
# Install ruby, rubocop, and ruby-lint
###
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc
RUN apt-get -q update && apt-get -q install --no-install-recommends -y ruby ruby-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN gem install rake
RUN gem install rubocop
RUN gem install ruby-lint

####
# Install shellcheck (shell script lint)
####
RUN add-apt-repository -y ppa:jonathonf/ghc-8.0.2
RUN apt-get -q update && apt-get -q install --no-install-recommends -y shellcheck \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

###
# Install hadolint
####
RUN curl -L -s -S \
   https://github.com/hadolint/hadolint/releases/download/v1.15.0/hadolint-Linux-x86_64 \
   -o /bin/hadolint && \
   chmod a+rx /bin/hadolint && \
   shasum -a 512 /bin/hadolint | \
   awk '$1!="f42e69dddfd2e4ce69848cc67b0800be9ae7ac729360fb9aa7250ee84499e635dc524a470766570d7fa2bd57c58529c4dbbefea80f583e5640b651d4a3b10f63" {exit(1)}'

####
# YETUS CUT HERE
# Anthing after the above line is ignored by Yetus, so could
# include other requirements not needed by your development
# (but not build) environment
###
