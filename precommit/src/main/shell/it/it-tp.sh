#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# where to get Apache Yetus
YETUSDIR=${YETUSDIR:-$(pwd)/yetus}

# project to work with
PROJECT=${PROJECT:-hadoop}

# temp directory to play in
WORKDIR=${WORKDIR:-/tmp/yetus.${PROJECT}}

# where to store artifacts: logs, etc. RELATIVE PATH!
PATCHDIR=out

# set the real dir where our source is.  this is a relative path!
BASEDIR=srcdir

# dockerfile to use
DOCKERFILE=${DOCKERFILE:-${BASEDIR}/dev-support/docker/Dockerfile}

# make the directory if it doesn't exist
mkdir -p "${WORKDIR}"

# build out workdir
pushd "${WORKDIR}" || exit 1

# checkout the project's source
if [[ ! -d "${BASEDIR}" ]]; then
  git clone "https://github.com/apache/${PROJECT}" "${BASEDIR}"
fi

# clean out the out dir
rm -rf "${PATCHDIR}" || true

# make sure they exist
mkdir -p "${PATCHDIR}"

# if we abort the run in the middle of git, it will leave a present we
# don't want
if [[ -f "${BASEDIR}/.git/index.lock" ]]; then
  rm "${BASEDIR}/.git/index.lock"
fi

# our 'default' args, in (mostly) alphabetical order

# rsync these files back into the archive dir
YETUS_ARGS+=("--archive-list=checkstyle-errors.xml,spotbugsXml.xml")

# where the source is located
YETUS_ARGS+=("--basedir=${BASEDIR}")

# want to make sure the output is sane for these
YETUS_ARGS+=("--brief-report-file=${PATCHDIR}/brief.txt")
YETUS_ARGS+=("--console-report-file=${PATCHDIR}/console.txt")
YETUS_ARGS+=("--html-report-file=${PATCHDIR}/report.html")

# run in docker mode
YETUS_ARGS+=("--docker")

# which Dockerfile to use
YETUS_ARGS+=("--dockerfile=${DOCKERFILE}")

# force JDK to be OpenJDK 8
YETUS_ARGS+=("--java-home=/usr/lib/jvm/java-8-openjdk-amd64")

# temp storage, etc
YETUS_ARGS+=("--patch-dir=${PATCHDIR}")

# plugins to enable. modify as necessary based upon what is being tested
YETUS_ARGS+=("--plugins=jira,maven,briefreport,htmlout")

# Many projects need a high process limit
YETUS_ARGS+=("--proclimit=5000")

# project name. this will auto trigger personality for built-ins
YETUS_ARGS+=("--project=${PROJECT}")

# nuke the src repo before working
YETUS_ARGS+=("--resetrepo")

# run test-patch from the source tree specified up above
TESTPATCHBIN=${YETUSDIR}/precommit/test-patch.sh

# now run test-patch with any optional arguments:
# --empty-patch for a full run aka 'qbt'
# URL for a remote patch file
# file name for local patch file
# JIRA Issue, etc, etc.
#
# also, can add parameters or override the above as necessary

cat <<EOF

*******************
Starting test-patch
*******************

EOF

/bin/bash "${TESTPATCHBIN}" "${YETUS_ARGS[@]}" "${@}"

cat <<EOF

*******************
Stopping test-patch
*******************

EOF

popd || exit 1
