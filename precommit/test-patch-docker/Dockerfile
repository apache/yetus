
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

FROM ubuntu:trusty

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
    openjdk-7-jdk \
    pinentry-curses \
    pkg-config \
    python \
    python2.7 \
    python-pip \
    rsync

# Fixing the Apache commons / Maven dependency problem under Ubuntu:
# See http://wiki.apache.org/commons/VfsProblems
RUN cd /usr/share/maven/lib && ln -s ../../java/commons-lang.jar .

####
# Pylint
####
RUN pip install pylint

#######
# Oracle Java
#######

RUN echo "dot_style = mega" > "/root/.wgetrc"
RUN echo "quiet = on" >> "/root/.wgetrc"

RUN apt-get -q install -y software-properties-common
RUN add-apt-repository -y ppa:webupd8team/java
RUN apt-get -q update

# Auto-accept the Oracle JDK license
RUN echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
RUN apt-get -q install -y oracle-java7-installer

# Auto-accept the Oracle JDK license
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
RUN apt-get -q install -y oracle-java8-installer

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
# Install shellcheck
####
RUN apt-get -q install -y cabal-install
RUN mkdir /root/.cabal
RUN echo "remote-repo: hackage.fpcomplete.com:http://hackage.fpcomplete.com/" >> /root/.cabal/config
#RUN echo "remote-repo: hackage.haskell.org:http://hackage.haskell.org/" > /root/.cabal/config
RUN echo "remote-repo-cache: /root/.cabal/packages" >> /root/.cabal/config
RUN cabal update
RUN cabal install shellcheck --global

####
# Install ruby
###
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc
RUN apt-get -q install -y ruby2.0
#
# on trusty, the above installs ruby2.0 and ruby (1.9.3) exes
# but update-alternatives is broken, so we need to do some work
# to make 2.0 actually the default without the system flipping out
#
# See https://bugs.launchpad.net/ubuntu/+source/ruby2.0/+bug/1310292
#
RUN dpkg-divert --add --rename --divert /usr/bin/ruby.divert /usr/bin/ruby
RUN dpkg-divert --add --rename --divert /usr/bin/gem.divert /usr/bin/gemrc
RUN update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby2.0 1
RUN update-alternatives --install /usr/bin/gem gem /usr/bin/gem2.0 1

####
# Install rubocop
###
RUN gem install rubocop

####
# Install ruby-lint
###
RUN gem install ruby-lint

####
# Install bats
####
RUN add-apt-repository -y ppa:duggan/bats
RUN apt-get -q update
RUN apt-get -q install -y bats

###
# Set the locale
###
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
