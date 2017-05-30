
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

FROM ubuntu:xenial

WORKDIR /root

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_TERSE true

######
# Install common dependencies from packages
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
    ant \
    autoconf \
    automake \
    build-essential \
    bzip2 \
    cmake \
    curl \
    g++ \
    gcc \
    git \
    gnupg-agent \
    make \
    maven \
    libperl-critic-perl \
    libtool \
    locales \
    openjdk-8-jdk-headless \
    pinentry-curses \
    pkg-config \
    python \
    python2.7 \
    python-pip \
    python-pkg-resources \
    python-setuptools \
    python-wheel \
    rsync \
    ruby \
    ruby-dev \
    software-properties-common

###
# Set the locale
###
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

####
# Install bats
####
RUN add-apt-repository -y ppa:duggan/bats
RUN apt-get -q update
RUN apt-get -q install -y bats

######
# Install findbugs
######
RUN mkdir -p /opt/findbugs && \
    curl -L -s -S \
         https://sourceforge.net/projects/findbugs/files/findbugs/3.0.1/findbugs-noUpdateChecks-3.0.1.tar.gz/download \
         -o /opt/findbugs.tar.gz && \
    tar xzf /opt/findbugs.tar.gz --strip-components 1 -C /opt/findbugs
ENV FINDBUGS_HOME /opt/findbugs

####
# Pylint
####
RUN pip2 install pylint

####
# Disable misc ruby bits
###
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc

####
# Install rubocop
###
RUN gem install rake
RUN gem install rubocop

####
# Install ruby-lint
###
RUN gem install ruby-lint


####
# Install shellcheck
####
RUN apt-get -q install -y cabal-install
RUN mkdir /root/.cabal
RUN echo "remote-repo: hackage.fpcomplete.com:http://hackage.fpcomplete.com/" >> /root/.cabal/config
#RUN echo "remote-repo: hackage.haskell.org:http://hackage.haskell.org/" > /root/.cabal/config
RUN echo "remote-repo-cache: /root/.cabal/packages" >> /root/.cabal/config
RUN cabal update
RUN cabal install shellcheck --global
