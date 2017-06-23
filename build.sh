#!/bin/bash -e
#
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
#
# Temporary script for building tarballs. See YETUS-125 to help
# create a more sustainable build system.
#
# Pass --release to get release checks
#
# Presumes you have
#   * maven 3.2.0+
#   * jdk 1.7+ (1.7 in --release)
#   * ruby + gems needed to run middleman
#   * python + python-dateutil

## @description  Verify that all required dependencies exist
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        true iff this is a release build
## @return       1 - Some dependencies are missing
## @return       0 - All dependencies exist
function detect_dependencies
{
  declare is_release=$1
  local exit_code=0
  if ! [ -x "$(command -v java)" ]; then
    echo "Java not found! Must install JDK version >= 1.7" >&2
    exit_code=1
  fi
  if ! [ -x "$(command -v mvn)" ]; then
    echo "Apache Maven not found! Must install version >= 3.2.0" >&2
    echo "Download it at https://maven.apache.org/download.cgi" >&2
    exit_code=1
  fi
  if ! [ -x "$(command -v bundle)" ]; then
    echo "building docs requires a Ruby executable bundle." >&2
    echo "Install it by executing 'gem install bundler && bundle install'" >&2
    exit_code=1
  fi

  ! python -c 'import dateutil.parser' 2>/dev/null
  if [ "$?" -eq "0" ]; then
    echo "Building release docs requires the python-dateutil module" >&2
    echo "Install it by executing 'pip install python-dateutil'" >&2
    exit_code=1
  fi

  if ! [ -x "$(command -v tar)" ]; then
    echo "Building archives requires the 'tar' command." >&2
    exit_code=1
  fi

  if [ "${is_release}" = "true" ] && ! [ -x "$(command -v pax)" ]; then
    echo "building the release source archive requires the 'pax' command." >&2
    exit_code=1
  fi

  if [[ "${exit_code}" -ne "0" ]]; then
    echo "Some dependencies are missing. Exit now." >&2
  fi
  return ${exit_code}
}

YETUS_VERSION=$(cat VERSION)
RAT_DOWNLOAD_URL=https://repo1.maven.org/maven2/org/apache/rat/apache-rat/0.11/apache-rat-0.11.jar

release=false
offline=false
for arg in "$@"; do
  if [ "--release" = "${arg}" ]; then
    release=true
  elif [ "--offline" = "${arg}" ]; then
    offline=true
  fi
done

echo "working on version '${YETUS_VERSION}'"

detect_dependencies "${release}"
mkdir -p target

if [ "${offline}" != "true" ]; then
  JIRA_VERSION="${YETUS_VERSION%%-SNAPSHOT}"
  echo "generating release docs."
  # Note that we use the bare python here instead of the wrapper script, since we
  # create said script.
  release-doc-maker/releasedocmaker.py --lint=all --license --outputdir target \
                                                   --project YETUS "--version=${JIRA_VERSION}" \
                                                   --projecttitle="Apache Yetus" --usetoday
  mv "target/${JIRA_VERSION}/RELEASENOTES.${JIRA_VERSION}.md" target/RELEASENOTES.md
  mv "target/${JIRA_VERSION}/CHANGES.${JIRA_VERSION}.md" target/CHANGES.md
else
  echo "in offline mode, skipping release notes."
fi

MAVEN_ARGS=()
if [ "${offline}" = "true" ]; then
  MAVEN_ARGS=("${MAVEN_ARGS[@]}" --offline)
fi

if [ "${release}" = "true" ]; then
  MAVEN_ARGS=("${MAVEN_ARGS[@]}" -Papache-release)
  echo "hard reseting working directory."
  git reset --hard HEAD

  if [ ! -f target/rat.jar ]; then
    if [ "${offline}" != "true" ]; then
      echo "downloading rat jar file to '$(pwd)/target/'"
      curl -o target/rat.jar "${RAT_DOWNLOAD_URL}"
    else
      echo "in offline mode, can't retrieve rat jar. will skip license check."
    fi
  fi
  echo "creating source tarball at '$(pwd)/target/'"
  rm "target/yetus-${YETUS_VERSION}-src".tar* 2>/dev/null || true
  pax -w -f "target/yetus-${YETUS_VERSION}-src.tar" -s "/target/yetus-${YETUS_VERSION}/" target/RELEASENOTES.md target/CHANGES.md
  current=$(basename "$(pwd)")
  #shellcheck disable=SC2038
  (cd ..; find "${current}" \( -name target -o -name publish -o -name .git \) -prune -o ! -type d -print | xargs pax -w -a -f "${current}/target/yetus-${YETUS_VERSION}-src.tar" -s "/${current}/yetus-${YETUS_VERSION}/")
  gzip "target/yetus-${YETUS_VERSION}-src.tar"
fi

echo "running maven builds for java components"
# build java components
mvn "${MAVEN_ARGS[@]}" install --file yetus-project/pom.xml
mvn "${MAVEN_ARGS[@]}" -Pinclude-jdiff-module install javadoc:aggregate --file audience-annotations-component/pom.xml

echo "building documentation"
# build docs after javadocs
docs_out=$(cd asf-site-src && bundle exec middleman build)
echo "${docs_out}"

bin_tarball="target/bin-dir/yetus-${YETUS_VERSION}"
echo "creating staging area for convenience binary at '$(pwd)/${bin_tarball}'"
rm -rf "${bin_tarball}" 2>/dev/null || true
mkdir -p "${bin_tarball}"

for i in LICENSE NOTICE; do
  lines=$(grep -n 'Apache Yetus Source' "${i}" | cut -f1 -d:)
  if [[ -z "${lines}" ]]; then
    cp -p "${i}" "${bin_tarball}"
  else
    ((lines=lines-2))
    head -n "${lines}" "${i}" > "${bin_tarball}/${i}"
  fi
done

cp target/RELEASENOTES.md target/CHANGES.md "${bin_tarball}"
cp -r asf-site-src/publish/documentation/in-progress "${bin_tarball}/docs"

mkdir -p "${bin_tarball}/lib"
cp VERSION "${bin_tarball}/lib/"

mkdir -p "${bin_tarball}/lib/yetus-project"
cp yetus-project/pom.xml "${bin_tarball}/lib/yetus-project/yetus-project-${YETUS_VERSION}.pom"

mkdir -p "${bin_tarball}/lib/audience-annotations"
cp audience-annotations-component/audience-annotations/target/audience-annotations-*.jar \
   audience-annotations-component/audience-annotations-jdiff/target/audience-annotations-jdiff-*.jar \
   "${bin_tarball}/lib/audience-annotations/"

cp -r shelldocs "${bin_tarball}/lib/"

cp -r release-doc-maker "${bin_tarball}/lib/"

cp -r precommit "${bin_tarball}/lib/"
ln -s test-patch.sh "${bin_tarball}/lib/precommit/qbt.sh"

mkdir -p "${bin_tarball}/bin"

# Make a special version of the shell wrapper for releasedocmaker
# that maintains the ability to have '--lint' mean '--lint=all'
cat >"${bin_tarball}/bin/releasedocmaker" <<EOF
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

args=()
for arg in "\${@}"; do
  if [ "\${arg}" = "-n" ] || [ "\${arg}" = "--lint" ]; then
    args=("\${args[@]}" "--lint=all")
  else
    args=("\${args[@]}" "\${arg}")
  fi
done

exec "\$(dirname -- "\${BASH_SOURCE-0}")/../lib/release-doc-maker/releasedocmaker.py" "\${args[@]}"
EOF
chmod +x "${bin_tarball}/bin/releasedocmaker"

for utility in shelldocs/shelldocs.py \
               precommit/docker-cleanup.sh \
               precommit/qbt.sh \
               precommit/smart-apply-patch.sh \
               precommit/test-patch.sh
do
  wrapper=${utility##*/}
  wrapper=${wrapper%.*}
  cat >"${bin_tarball}/bin/${wrapper}" <<EOF
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

exec "\$(dirname -- "\${BASH_SOURCE-0}")/../lib/${utility}" "\${@}"
EOF
  chmod +x "${bin_tarball}/bin/${wrapper}"
done

bin_file="target/yetus-${YETUS_VERSION}-bin.tar.gz"
echo "creating convenience binary in '$(pwd)/target'"
rm "${bin_file}" 2>/dev/null || true
tar -C "$(dirname "${bin_tarball}")" -czf "${bin_file}" "$(basename "${bin_tarball}")"

if [ "${release}" = "true" ] && [ -f target/rat.jar ]; then
  echo "checking asf licensing requirements for source tarball '$(pwd)/target/yetus-${YETUS_VERSION}-src.tar.gz'."
  rm -rf target/source-unpack 2>/dev/null || true
  mkdir target/source-unpack
  tar -C target/source-unpack -xzf "target/yetus-${YETUS_VERSION}-src.tar.gz"
  java -jar target/rat.jar -E .rat-excludes -d target/source-unpack

  echo "checking asf licensing requirements for convenience binary '$(pwd)/${bin_file}'."
  rm -rf target/bin-unpack 2>/dev/null || true
  mkdir target/bin-unpack
  tar -C target/bin-unpack -xzf "${bin_file}"
  java -jar target/rat.jar -E .rat-excludes -d target/bin-unpack
fi
echo "All Done!"
echo "Find your output at:"
if [ "${release}" = "true" ] && [ -f "target/yetus-${YETUS_VERSION}-src.tar.gz" ]; then
  echo "    $(pwd)/target/yetus-${YETUS_VERSION}-src.tar.gz"
fi
if [ -f "${bin_file}" ]; then
  echo "    $(pwd)/${bin_file}"
fi
