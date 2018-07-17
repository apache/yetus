
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

WORKDIR /root

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_TERSE true

######
# Install some basic Apache Yetus requirements
######
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
    curl \
    git \
    gnupg-agent \
    locales \
    pinentry-curses \
    pkg-config \
    rsync \
    software-properties-common

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
RUN apt-get -q install --no-install-recommends -y openjdk-8-jdk-headless

#######
# OpenJDK 9
# w/workaround for
# https://bugs.launchpad.net/ubuntu/+source/openjdk-9/+bug/1593191
#######
RUN apt-get -o Dpkg::Options::="--force-overwrite" \
    -q install --no-install-recommends -y \
    openjdk-9-jdk-headless

#######
# Set default Java
#######
#
# By default, OpenJDK sets the default Java to the highest version.
# We want the opposite, soooooo....
#
RUN update-java-alternatives --set java-1.8.0-openjdk-amd64
RUN update-alternatives --get-selections | grep -i jdk | \
    while read line; do \
      alternative=$(echo $line | awk '{print $1}'); \
      path=$(echo $line | awk '{print $3}'); \
      newpath=$(echo $path | sed -e 's/java-9/java-8/'); \
      update-alternatives --set $alternative $newpath; \
    done


####
# Install ant
####
RUN apt-get -q install --no-install-recommends -y ant

####
# Install GNU automake, GNU make, and related
####
RUN apt-get -q install --no-install-recommends -y autoconf automake libtool make

####
# Install bats (TAP-capable unit testing for shell scripts)
####
RUN apt-get -q install --no-install-recommends -y bats

####
# Install cmake
####
RUN apt-get -q install --no-install-recommends -y cmake

######
# Install findbugs
######
RUN apt-get -q install --no-install-recommends -y findbugs
ENV FINDBUGS_HOME /usr

####
# Install GNU C/C++
####
RUN apt-get -q install --no-install-recommends -y g++ gcc libc-dev

######
# Install maven
######
RUN apt-get -q install --no-install-recommends -y maven

######
# Install perl
######
RUN apt-get -q install --no-install-recommends -y perl libperl-critic-perl

######
# Install python and pylint
######
RUN apt-get -q install --no-install-recommends -y python \
    python2.7 \
    python-pip \
    python-pkg-resources \
    python-setuptools \
    python-wheel
RUN pip2 install --upgrade pip==9.0.3
RUN pip install -v pylint==1.9.2

####
# Install ruby, rubocop, and ruby-lint
###
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc
RUN apt-get -q install --no-install-recommends -y ruby ruby-dev
RUN gem install rake
RUN gem install rubocop
RUN gem install ruby-lint

####
# Install shellcheck (shell script lint)
####
RUN add-apt-repository -y ppa:jonathonf/ghc-8.0.2
RUN apt-get -q update && apt-get -q install --no-install-recommends -y shellcheck


####
# YETUS CUT HERE
# Anthing after the above line is ignored by Yetus, so could
# include other requirements not needed by your development
# (but not build) environment
###
RUN apt-get -q install --no-install-recommends -y sudo vim
