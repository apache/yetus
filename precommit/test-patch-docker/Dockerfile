
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

######
# Install common dependencies from packages
######
RUN apt-get update && apt-get install --no-install-recommends -y \
    git curl ant make maven \
    cmake gcc g++ pkg-config \
    build-essential libtool \
    autoconf automake \
    python python2.7 pylint \
    openjdk-7-jdk \
    libperl-critic-perl

# Fixing the Apache commons / Maven dependency problem under Ubuntu:
# See http://wiki.apache.org/commons/VfsProblems
RUN cd /usr/share/maven/lib && ln -s ../../java/commons-lang.jar .

#######
# Oracle Java
#######

RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:webupd8team/java
RUN apt-get update


# Auto-accept the Oracle JDK license
RUN echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
RUN apt-get install -y oracle-java7-installer

# Auto-accept the Oracle JDK license
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
RUN apt-get install -y oracle-java8-installer

######
# Install findbugs
######
RUN mkdir -p /opt/findbugs && \
    curl -L https://sourceforge.net/projects/findbugs/files/findbugs/3.0.1/findbugs-noUpdateChecks-3.0.1.tar.gz/download \
         -o /opt/findbugs.tar.gz && \
    tar xzf /opt/findbugs.tar.gz --strip-components 1 -C /opt/findbugs
ENV FINDBUGS_HOME /opt/findbugs

####
# Install shellcheck
####
RUN apt-get install -y cabal-install
RUN cabal update && cabal install shellcheck --global

####
# Install ruby
###
RUN echo 'gem: --no-rdoc --no-ri' >> /root/.gemrc
RUN apt-get install -y ruby2.0
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
RUN apt-get update
RUN apt-get install -y bats

###
# Set the locale
###
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8