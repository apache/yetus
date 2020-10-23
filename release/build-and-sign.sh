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

#shellcheck source=precommit/src/main/shell/core.d/00-yetuslib.sh
. precommit/src/main/shell/core.d/00-yetuslib.sh

BINDIR=$(yetus_abs "${thisdir}")
BASEDIR=$(yetus_abs "${BINDIR}/..")

PARAMS=("$@")

echo_and_redirect()
{
  declare logfile=$1
  shift

  # to the screen
  echo "cd $(pwd)"
  echo "${*} > ${logfile} 2>&1"

  yetus_run_and_redirect "${logfile}" "${@}"
}

set_defaults()
{
  # Where our artifacts are located
  ARTIFACTS_DIR=${BASEDIR}/yetus-dist/target/artifacts

  # deploy to maven staging repo
  DEPLOY=false

  GPG=$(command -v gpg)
  GPGAGENT=$(command -v gpg-agent)

  LOGDIR="/tmp/build-log"

  PUBKEYFILE="https://downloads.apache.org/yetus/KEYS"

  SIGN=false
}


big_console_header()
{
  declare text="$*"
  declare spacing=$(( (75+${#text}) /2 ))

  printf '\n\n'
  echo "============================================================================"
  echo "============================================================================"
  printf '%*s\n'  ${spacing} "${text}"
  echo "============================================================================"
  echo "============================================================================"
  printf '\n\n'
}

startgpgagent()
{
  if [[ "${SIGN}" = true ]]; then
    if [[ -n "${GPGAGENT}" && -z "${GPG_AGENT_INFO}" ]]; then
      echo "starting gpg agent"
      echo "default-cache-ttl 36000" > "${LOGDIR}/gpgagent.conf"
      echo "max-cache-ttl 36000" >> "${LOGDIR}/gpgagent.conf"
      # shellcheck disable=2046
      eval $("${GPGAGENT}" --daemon \
        --options "${LOGDIR}/gpgagent.conf" \
        --log-file="${LOGDIR}/create-release-gpgagent.log")
      GPGAGENTPID=$(pgrep "${GPGAGENT}")
      GPG_AGENT_INFO="$HOME/.gnupg/S.gpg-agent:$GPGAGENTPID:1"
      export GPG_AGENT_INFO
    fi

    if [[ -n "${GPG_AGENT_INFO}" ]]; then
      echo "Warming the gpg-agent cache prior to calling maven"
      # warm the agent's cache:
      touch "${LOGDIR}/warm"
      "${GPG}" --use-agent --armor --output "${LOGDIR}/warm.asc" --detach-sig "${LOGDIR}/warm"
      rm "${LOGDIR}/warm.asc" "${LOGDIR}/warm"
    else
      SIGN=false
      yetus_error "ERROR: Unable to launch or acquire gpg-agent. Disable signing."
    fi
  fi
}

stopgpgagent()
{
  if [[ -n "${GPGAGENTPID}" ]]; then
    kill "${GPGAGENTPID}"
  fi
}

usage()
{
  yetus_add_option "--asfrelease" "Make an ASF release"
  yetus_add_option "--deploy" "Deploy Maven artifacts using ~/.m2/settings.xml"
  yetus_add_option "--logdir=[path]" "Path to store logs"
  yetus_add_option "--sign" "Use .gnupg dir to sign the artifacts and jars"
  yetus_generic_columnprinter "${YETUS_OPTION_USAGE[@]}"
  yetus_reset_usage
}

option_parse()
{
  declare i

  for i in "$@"; do
    case ${i} in
      --asfrelease)
        ASFRELEASE=true
        SIGN=true
        DEPLOY=true
      ;;
      --deploy)
        DEPLOY=true
      ;;
      --help)
        usage
        exit
      ;;
      --logdir=*)
        LOGDIR=${i#*=}
      ;;
      --sign)
        SIGN=true
      ;;
    esac
  done

  if [[ ! -d "${HOME}/.gnupg" ]]; then
    yetus_error "ERROR: No .gnupg dir. Disabling signing capability."
    SIGN=false
  fi

  if [[ "${SIGN}" = true ]]; then
    if [[ -n "${GPG_AGENT_INFO}" ]]; then
      echo "NOTE: Using existing gpg-agent. If the default-cache-ttl"
      echo "is set to less than ~20 mins, maven commands will fail."
    elif [[ -z "${GPGAGENT}" ]]; then
      yetus_error "ERROR: No gpg-agent. Disabling signing capability."
      SIGN=false
    fi
  fi

  if [[ "${DEPLOY}" = true && ! -f "${HOME}/.m2/settings.xml" ]]; then
    yetus_error "ERROR: No ~/.m2/settings.xml file, cannot deploy Maven artifacts."
    exit 1
  fi

  if [[ "${ASFRELEASE}" = true ]]; then
    if [[ "${SIGN}" = false ]]; then
      yetus_error "ERROR: --asfrelease requires --sign. Exiting."
      exit 1
    fi
  fi

  mkdir -p "${LOGDIR}"

}

makearelease()
{
  declare target="install"

  if [[ "${DEPLOY}" = true ]]; then
    target="deploy"
  fi

  if [[ "${SIGN}" = true ]]; then
    signflags=("-Psign" "-Dgpg.useagent=true")
  fi

  # let's start at the root
  pushd "${BASEDIR}" >/dev/null || exit 1

  big_console_header "Cleaning the Source Tree"

  # git clean to clear any remnants from previous build
  echo_and_redirect "${LOGDIR}/git_clean.log" git clean -xdf

  echo_and_redirect "${LOGDIR}/mvn_clean.log" mvn --batch-mode clean

  big_console_header "Apache RAT Check"

  # Create RAT report
  echo_and_redirect "${LOGDIR}/mvn_apache_rat.log" mvn --batch-mode apache-rat:check

  big_console_header "Maven Build and Install"

  echo_and_redirect "${LOGDIR}/mvn_${target}.log" \
    mvn --batch-mode "${target}" \
      "${signflags[@]}" \
      -DskipTests

  big_console_header "Maven Site"

  echo_and_redirect "${LOGDIR}/mvn_site.log" \
    mvn --batch-mode site site:stage </dev/null
}

signartifacts()
{
  declare i
  declare ret

  if [[ "${SIGN}" = false ]]; then
    echo ""
    echo "Remember to sign the artifacts before staging them on the open"
    echo ""
    return
  fi

  big_console_header "Signing the release"

  pushd "${ARTIFACTS_DIR}" > /dev/null || exit 1
  for i in *; do
    gpg --use-agent --armor --output "${i}.asc" --detach-sig "${i}"
    gpg --print-mds "${i}" >"${i}".mds
    sha512sum --tag "${i}" > "${i}.sha512"
  done

  popd > /dev/null || exit 1

  if [[ "${ASFRELEASE}" = true ]]; then
    echo "Fetching the Apache Yetus KEYS file..."
    curl -L "${PUBKEYFILE}" -o "${BASEDIR}/target/KEYS"
    gpg --import --trustdb "${BASEDIR}/target/testkeysdb" "${BASEDIR}/target/KEYS"
    for i in "${ARTIFACTS_DIR}"/*gz; do
      gpg --verify --trustdb "${BASEDIR}/target/testkeysdb" \
        "${i}.asc" "${i}"
      ret=$?
      if [[ ${ret} != 0 ]]; then
        yetus_error "ERROR: GPG key is not present in ${PUBKEYFILE}."
        yetus_error "ERROR: This MUST be fixed. Exiting."
        exit 1
      fi
    done
  fi
}

set_defaults

option_parse "${PARAMS[@]}"

startgpgagent

makearelease
releaseret=$?

signartifacts

stopgpgagent

if [[ ${releaseret} == 0 ]]; then
  echo
  echo "Congratulations, you have successfully built the release"
  echo "artifacts for Apache Yetus ${YETUS_VERSION}"
  echo
  echo "The artifacts for this run are available at ${ARTIFACTS_DIR}:"
  ls -1 "yetus-dist/target/artifacts"

  echo
fi
