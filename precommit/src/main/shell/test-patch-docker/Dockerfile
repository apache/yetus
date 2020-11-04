
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
# Install GNU C/C++ (everything generally needs this)
####
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        g++ \
        gcc \
        libc-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

###
# Install golang as part of base so we can do each
# helper utility in parallel. go bins are typically
# statically linked, so this is perfectly safe.
###
# hadolint ignore=DL3008
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
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /opt/apache-rat \
    && curl -f -s -L -o /tmp/rat.tgz \
        'https://www.apache.org/dyn/closer.cgi?action=download&filename=/creadur/apache-rat-0.13/apache-rat-0.13-bin.tar.gz' \
    && shasum -a 512 /tmp/rat.tgz \
        | awk '$1!="2c1e12eace7b80a9b6373c2f5080fbf63d3fa8d9248f3a17bd05de961cd3ca3c4549817b8b7320a84f0c323194edad0abdb86bdfec3976227a228e2143e14a54" {exit(1)}' \
    && tar --strip-components 1 -C /opt/apache-rat -xpzf /tmp/rat.tgz \
    && rm /tmp/rat.tgz \
    && mv /opt/apache-rat/apache-rat-0.13.jar /opt/apache-rat/apache-rat.jar

#####
# Install SpotBugs
#####
FROM yetusbase AS spotbugs
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/4.2.2/spotbugs-4.2.2.tgz -o spotbugs.tgz \
    && curl -sSL https://repo.maven.apache.org/maven2/com/github/spotbugs/spotbugs/4.2.2/spotbugs-4.2.2.tgz.sha1 -o spotbugs.tgz.sha1 \
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
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
    https://github.com/koalaman/shellcheck/releases/download/v0.7.1/shellcheck-v0.7.1.linux.x86_64.tar.xz \
        | tar --strip-components 1 --wildcards -xJf - '*/shellcheck' \
    && chmod a+rx shellcheck \
    && mv shellcheck /bin/shellcheck \
    && shasum -a 512 /bin/shellcheck \
    | awk '$1!="aae813283d49f18f95a205dca1c5184267d07534a08abc952ebea1958fee06f8a0207373b6770a083079ba875458ea9da443f2b9910a50dcd93b935048bc14f5" {exit(1)}'

####
# Install hadolint (dockerfile lint)
####
FROM yetusbase AS hadolint
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
        https://github.com/hadolint/hadolint/releases/download/v1.18.0/hadolint-Linux-x86_64 \
        -o /bin/hadolint \
    && chmod a+rx /bin/hadolint \
    && shasum -a 512 /bin/hadolint \
    | awk '$1!="df27253d374c143a606483b07a26234ac7b4bca40b4eba53e79609c81aa70146e7d5c145f90dcec71d6d1aad1048b7d9d2de68d92284f48a735d04d19c5c5559" {exit(1)}'

####
# Install buf (protobuf lint)
####
FROM yetusbase AS buf
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL \
      https://github.com/bufbuild/buf/releases/download/v0.21.0/buf-Linux-x86_64.tar.gz \
      -o buf.tar.gz \
    && shasum -a 256 buf.tar.gz \
    | awk '$1!="95aba62ac0ecc5a9120cc58c65cdcc85038633a816bddfe8398c5ae3b32803f1" {exit(1)}' \
    && tar -xzf buf.tar.gz -C /usr/local --strip-components 1 \
    && rm buf.tar.gz

####
# Install bats (TAP-capable unit testing for shell scripts)
####
FROM yetusbase AS bats
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN git clone --branch v1.2.1 \
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
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get -q update \
    && apt-get -q install --no-install-recommends -y golang-1.15 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && /usr/lib/go-1.15/bin/go get -u github.com/mrtazz/checkmake

####
# golangci-lint (Multi-tool golang linter)
####
FROM yetusbase as golangci
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN (GO111MODULE=on go get github.com/golangci/golangci-lint/cmd/golangci-lint@v1.31.0)

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
RUN apt-get -q update && apt-get -q install --no-install-recommends -y \
        python3 \
        python3-bcrypt \
        python3-cffi \
        python3-cryptography \
        python3-dateutil \
        python3-dev \
        python3-dev \
        python3-isort \
        python3-dockerpty \
        python3-nacl \
        python3-pyrsistent \
        python3-setuptools \
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
    && pip3 install -v \
        astroid==2.4.2 \
        git+https://github.com/codespell-project/codespell.git@8d8d4ae2bbd24a91d1a9bd8aec25c9f86724c280 \
        docker-compose==1.26.2 \
        pylint==2.5.3 \
        yamllint==1.24.2 \
    && rm -rf /root/.cache \
    && mv /usr/local/bin/pylint /usr/local/bin/pylint3
RUN ln -s /usr/local/bin/pylint3 /usr/local/bin/pylint
RUN ln -s /usr/local/bin/pip3 /usr/local/bin/pip

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
COPY --from=checkmake /root/go/bin/* /usr/local/bin
COPY --from=golangci /root/go/bin/* /usr/local/bin

####
# YETUS CUT HERE
# Magic text above! Everything from here on is ignored
# by Yetus, so could include anything not needed
# by your testing environment
###
