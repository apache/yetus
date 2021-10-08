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

# SHELLDOC-IGNORE

this="${BASH_SOURCE-$0}"
thisdir=$(cd -P -- "$(dirname -- "${this}")" >/dev/null && pwd -P)

pushd "${thisdir}/.." >/dev/null || exit 1

if [[ ! -d precommit ]]; then
  echo "ERROR: Unsure about directory structure."
  exit 1
fi

#shellcheck source=SCRIPTDIR/../precommit/src/main/shell/core.d/00-yetuslib.sh
. precommit/src/main/shell/core.d/00-yetuslib.sh

BINDIR=$(yetus_abs "${thisdir}")
BASEDIR=$(yetus_abs "${BINDIR}/..")


usage()
{
  yetus_add_option "--version=<version>" "Version to process"
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage
}

option_parse()
{
  declare i

  for i in "$@"; do
    case ${i} in
      --help)
        usage
        exit
      ;;
      --version=*)
        VERSION=${i#*=}
      ;;
    esac
  done

  if [[ -z "${VERSION}" ]]; then
    usage
    exit 1
  fi

  MAJORVERSION=$(echo "${VERSION}" | cut -d. -f1)
  MINORVERSION=$(echo "${VERSION}" | cut -d. -f2)
  #MICROVERSION=$(echo "${VERSION}" | cut -d. -f3)
}

update_versions()
{
  declare newfile=/tmp/versionsedit.$$
  declare found=false
  declare ver
  declare vermajor
  declare verminor
  declare -a versions
  declare produced=false

  ## NOTE: $REPLY, the default for read, is used
  ## here because it will maintain any leading spaces!
  ## if read is given a variable, then IFS manipulation
  ## will be required!

  while read -r; do
    if [[ ${found} == false && "${REPLY}" != releases: ]]; then
      echo "${REPLY}" >> "${newfile}"
    elif [[ "${REPLY}" == releases: ]]; then
      echo "${REPLY}" >> "${newfile}"
      found=true
    else
      ver=${REPLY##* }
      ver=${ver//\'/}
      vermajor=$(echo "${ver}" | cut -d. -f1)
      verminor=$(echo "${ver}" | cut -d. -f2)

      # Don't keep matching major.minor:
      if [[ "${vermajor}" == "${MAJORVERSION}" && "${verminor}" == "${MINORVERSION}" ]]; then
        continue
      fi
      versions+=("${ver}")
    fi
  done < "${BASEDIR}"/asf-site-src/data/versions.yml

  versions+=("${VERSION}")

  while [[ ${#versions[@]} -gt 3 ]]; do
    # array slice off the first element
    versions=("${versions[@]:1}")
  done

  for ver in "${versions[@]}"; do
    echo "  - '${ver}'" >> "${newfile}"
  done

  mv "${newfile}" "${BASEDIR}"/asf-site-src/data/versions.yml


  ## NOTE: $REPLY, the default for read, is used
  ## here because it will maintain any leading spaces!
  ## if read is given a variable, then IFS manipulation
  ## will be required!

  found=false
  produced=false
  while read -r; do
    if [[ "${REPLY}" =~ AUTOMATED_EDIT_BEGIN ]]; then
      echo "${REPLY}" >> "${newfile}"
      found=true
    elif [[ "${REPLY}" =~ AUTOMATED_EDIT_END ]]; then
      echo "${REPLY}" >> "${newfile}"
      found=false
    elif [[ ${found} == false ]]; then
      echo "${REPLY}" >> "${newfile}"
    elif [[ "${produced}" == true ]]; then
      continue
    elif [[ "${found}" == true ]]; then
      for ver in "${versions[@]}"; do
        cat << EOF >> "${newfile}"
          <execution>
            <id>${ver}</id>
            <phase>pre-site</phase>
            <goals>
              <goal>symlink</goal>
            </goals>
            <configuration>
              <target>../../target/${ver}</target>
              <newLink>\${basedir}/source/documentation/${ver}</newLink>
            </configuration>
          </execution>
          <execution>
            <id>${ver}.html.md</id>
            <phase>pre-site</phase>
            <goals>
              <goal>symlink</goal>
            </goals>
            <configuration>
              <target>../../target/${ver}.html.md</target>
              <newLink>\${basedir}/source/documentation/${ver}.html.md</newLink>
            </configuration>
          </execution>
EOF
      done
      produced=true
    fi
  done < "${BASEDIR}"/asf-site-src/pom.xml

  mv "${newfile}" "${BASEDIR}"/asf-site-src/pom.xml

}

update_htaccess()
{
  sed -E -i "s,[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+,${VERSION},g" "${BASEDIR}"/asf-site-src/data/htaccess.yml
}

option_parse "$@"

update_versions
update_htaccess
