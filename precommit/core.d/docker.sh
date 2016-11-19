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

DOCKERMODE=false
DOCKERCMD=$(command -v docker)
DOCKER_ID=${RANDOM}
DOCKER_DESTRUCTIVE=true
DOCKERFILE_DEFAULT="${BINDIR}/test-patch-docker/Dockerfile"
DOCKERFAIL="fallback,continue,fail"
DOCKERSUPPORT=false
DOCKER_ENABLE_PRIVILEGED=true

declare -a DOCKER_EXTRAARGS

####
#### IMPORTANT
####
#### If these times are updated, the documentation needs to
#### be changed too!

# created, stopped, exited, running, for 24 hours
DOCKER_CONTAINER_PURGE=("86400" "86400" "86400" "86400" )

# keep images for 1 week
DOCKER_IMAGE_PURGE=604800

## @description  Docker-specific usage
## @stability    stable
## @audience     private
## @replaceable  no
function docker_usage
{
  yetus_add_option "--docker" "Spawn a docker container"
  yetus_add_option "--dockercmd=<file>" "Command to use as docker executable (default: '${DOCKERCMD}')"
  yetus_add_option "--dockerfile=<file>" "Dockerfile fragment to use as the base (default: '${DOCKERFILE_DEFAULT}')"
  yetus_add_option "--dockeronfail=<list>" "If Docker fails, determine fallback method order (default: ${DOCKERFAIL})"
  yetus_add_option "--dockerprivd=<bool>" "Run docker in privileged mode (default: '${DOCKER_ENABLE_PRIVILEGED}')"
  yetus_add_option "--dockerdelrep" "In Docker mode, only report image/container deletions, not act on them"
}

## @description  Docker-specific argument parsing
## @stability    stable
## @audience     private
## @replaceable  no
## @params       arguments
function docker_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --docker)
        DOCKERSUPPORT=true
      ;;
      --dockercmd=*)
        #shellcheck disable=SC2034
        DOCKERCMD=${i#*=}
      ;;
      --dockerdelrep)
        DOCKER_DESTRUCTIVE=false
      ;;
      --dockerfile=*)
        DOCKERFILE=${i#*=}
      ;;
      --dockermode)
        DOCKERMODE=true
      ;;
      --dockeronfail=*)
        DOCKERFAIL=${i#*=}
      ;;
      --dockerprivd=*)
        DOCKER_ENABLE_PRIVILEGED=${i#*=}
      ;;
    esac
  done
}

## @description  Docker initialization pre- and post- re-exec
## @stability    stable
## @audience     private
## @replaceable  no
function docker_initialize
{
  declare dockvers

  # --docker and --dockermode are mutually
  # exclusive.  --docker is used by the user to
  # re-exec test-patch in Docker mode.
  # --dockermode is used by launch-test-patch (which is
  # run as the Docker EXEC in the Dockerfile,
  # see elsewhere for more info) to tell test-patch that
  # it has been restarted already. launch-test-patch
  # also strips --docker from the command line so that we
  # don't end up in a loop if the docker image
  # also has the docker command in it

  # we are already in docker mode
  if [[ "${DOCKERMODE}" == true ]]; then
    # DOCKER_VERSION is set by our creator.
    add_footer_table "Docker" "${DOCKER_VERSION}"
    return
  fi

  # docker mode hasn't been requested
  if [[ "${DOCKERSUPPORT}" != true ]]; then
    return
  fi

  # turn DOCKERFAIL into a string composed of numbers
  # to ease interpretation:  123, 213, 321, ... whatever
  # some of these combos are non-sensical but that's ok.
  # we'll treat non-sense as effectively errors.
  DOCKERFAIL=${DOCKERFAIL//,/ }
  DOCKERFAIL=${DOCKERFAIL//fallback/1}
  DOCKERFAIL=${DOCKERFAIL//continue/2}
  DOCKERFAIL=${DOCKERFAIL//fail/3}
  DOCKERFAIL=${DOCKERFAIL//[[:blank:]]/}

  docker_exeverify
  if [[ $? != 0 ]]; then
    if [[ "${DOCKERFAIL}" =~ ^12
       || "${DOCKERFAIL}" =~ ^2 ]]; then
      add_vote_table 0 docker "Docker command '${DOCKERCMD}' not found/broken. Disabling docker."
      DOCKERSUPPORT=false
    else
      add_vote_table -1 docker "Docker command '${DOCKERCMD}' not found/broken."
      bugsystem_finalreport 1
      cleanup_and_exit 1
    fi
  fi

  dockvers=$(docker_version Client)
  if [[ "${dockvers}" =~ ^0
     || "${dockvers}" =~ ^1\.[0-5]$ || "${dockvers}" =~ ^1\.[0-5]\. ]]; then
    if [[ "${DOCKERFAIL}" =~ ^12
       || "${DOCKERFAIL}" =~ ^2 ]]; then
      add_vote_table 0 docker "Docker command '${DOCKERCMD}' is too old (${dockvers} < 1.6.0). Disabling docker."
      DOCKERSUPPORT=false
    else
      add_vote_table -1 docker "Docker command '${DOCKERCMD}' is too old (${dockvers} < 1.6.0). Disabling docker."
      bugsystem_finalreport 1
      cleanup_and_exit 1
    fi
  fi
}

## @description  Verify dockerfile exists
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       exits on failure if configured
function docker_fileverify
{
  if [[ ${DOCKERMODE} = false &&
        ${DOCKERSUPPORT} = true ]]; then
    if [[ -n "${DOCKERFILE}" ]]; then
      pushd "${STARTINGDIR}" >/dev/null
      if [[ -f ${DOCKERFILE} ]]; then
        DOCKERFILE=$(yetus_abs "${DOCKERFILE}")
      else
        if [[ "${DOCKERFAIL}" =~ ^1 ]]; then
          yetus_error "ERROR: Dockerfile '${DOCKERFILE}' not found, falling back to built-in."
          add_vote_table 0 docker "Dockerfile '${DOCKERFILE}' not found, falling back to built-in."
          DOCKERFILE=${DOCKERFILE_DEFAULT}
        elif [[ "${DOCKERFAIL}" =~ ^2 ]]; then
          yetus_error "ERROR: Dockerfile '${DOCKERFILE}' not found, disabling docker."
          add_vote_table 0 docker "Dockerfile '${DOCKERFILE}' not found, disabling docker."
          DOCKERSUPPORT=false
        else
          yetus_error "ERROR: Dockerfile '${DOCKERFILE}' not found."
          add_vote_table -1 docker "Dockerfile '${DOCKERFILE}' not found."
          bugsystem_finalreport 1
          cleanup_and_exit 1
        fi
      fi
      popd >/dev/null
    else
      DOCKERFILE=${DOCKERFILE_DEFAULT}
    fi
  fi
}

## @description  Verify docker exists
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       1 if docker is broken
## @return       0 if docker is working
function docker_exeverify
{
  if ! verify_command "Docker" "${DOCKERCMD}"; then
    return 1
  fi

  ${DOCKERCMD} info >/dev/null 2>&1

  if [[ $? != 0 ]]; then
    yetus_error "Docker is not functioning properly. Daemon down/unreachable?"
    return 1
  fi
  return 0
}

## @description  Run docker with some arguments, and
## @description  optionally send to debug.
## @description  some destructive commands require
## @description  DOCKER_DESTRUCTIVE to be set to true
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function dockercmd
{
  declare subcmd=$1
  shift

  yetus_debug "dockercmd: ${DOCKERCMD} ${subcmd} $*"
  if [[ ${subcmd} == rm
      || ${subcmd} == rmi
      || ${subcmd} == stop
      || ${subcmd} == kill ]]; then
    if [[ "${DOCKER_DESTRUCTIVE}" == false ]]; then
      yetus_error "Safemode: not running ${DOCKERCMD} ${subcmd} $*"
      return
    fi
  fi
  "${DOCKERCMD}" "${subcmd}" "$@"
}

## @description  Convet docker's time format to ctime
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        time
function dockerdate_to_ctime
{
  declare mytime=$1

  # believe it or not, date is not even close to standardized...
  if [[ $(uname -s) == Linux ]]; then

    # GNU date
    date -d "${mytime}" "+%s"
  else

    # BSD date
    date -j -f "%FT%T%z" "${mytime}" "+%s"
  fi
}

## @description  Stop and delete all defunct containers
## @audience     private
## @stability    evolving
## @replaceable  no
function docker_container_maintenance
{
  declare line
  declare id
  declare name
  declare status
  declare tmptime
  declare createtime
  declare starttime
  declare stoptime
  declare remove
  declare difftime
  declare data

  if [[ "${ROBOT}" = false ]]; then
    return
  fi

  big_console_header "Docker Container Maintenance"

  dockercmd ps -a

  data=$(dockercmd ps -qa)

  if [[ -z "${data}" ]]; then
    return
  fi

  while read -r line; do
    id=$(echo "${line}" | cut -f1 -d, )
    status=$(echo "${line}" | cut -f2 -d, )
    tmptime=$(echo "${line}" | cut -f3 -d, | cut -f1 -d. )
    createtime=$(dockerdate_to_ctime "${tmptime}")
    tmptime=$(echo "${line}" | cut -f4 -d, | cut -f1 -d. )
    starttime=$(dockerdate_to_ctime "${tmptime}")
    tmptime=$(echo "${line}" | cut -f5 -d, | cut -f1 -d. )
    stoptime=$(dockerdate_to_ctime "${tmptime}")
    name=$(echo "${line}" | cut -f6 -d, )
    curtime=$(TZ=UTC date "+%s")
    remove=false

    case ${status} in
      created)
        ((difftime = curtime - createtime))
        if [[ ${difftime} -gt ${DOCKER_CONTAINER_PURGE[0]} ]]; then
          remove=true
        fi
      ;;
      stopped)
        ((difftime = curtime - stoptime))
        if [[ ${difftime} -gt ${DOCKER_CONTAINER_PURGE[1]} ]]; then
          remove=true
        fi
      ;;
      exited)
        ((difftime = curtime - stoptime))
        if [[ ${difftime} -gt ${DOCKER_CONTAINER_PURGE[2]} ]]; then
          remove=true
        fi
      ;;
      running)
        ((difftime = curtime - starttime))
        if [[ ${difftime} -gt ${DOCKER_CONTAINER_PURGE[3]}
             && "${SENTINEL}" = true ]]; then
          remove=true
          echo "Attempting to kill docker container ${name} [${id}]"
          dockercmd kill "${id}"
        fi
      ;;
      *)
      ;;
    esac

    if [[ "${remove}" == true ]]; then
      echo "Attempting to remove docker container ${name} [${id}]"
      dockercmd rm "${id}"
    fi

  done < <(
     # shellcheck disable=SC2086
     dockercmd inspect \
        --format '{{.Id}},{{.State.Status}},{{.Created}},{{.State.StartedAt}},{{.State.FinishedAt}},{{.Name}}' \
       ${data})
}

## @description  Delete images after ${DOCKER_IMAGE_PURGE}
## @audience     private
## @stability    evolving
## @replaceable  no
function docker_image_maintenance_helper
{
  declare id
  declare tmptime
  declare createtime
  declare difftime
  declare name

  if [[ "${ROBOT}" = false ]]; then
    return
  fi

  if [[ -z "$*" ]]; then
    return
  fi

  for id in "$@"; do
    tmptime=$(dockercmd inspect --format '{{.Created}}' "${id}" | cut -f1 -d. )
    createtime=$(dockerdate_to_ctime "${tmptime}")
    curtime=$(date "+%s")

    ((difftime = curtime - createtime))
    if [[ ${difftime} -gt ${DOCKER_IMAGE_PURGE} ]]; then
      echo "Attempting to remove docker image ${id}"
      dockercmd rmi "${id}"
    fi
  done
}

## @description  Remove untagged/unused images
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_image_maintenance
{
  declare id

  if [[ "${ROBOT}" = false ]]; then
    return
  fi

  big_console_header "Removing old images"

  dockercmd images

  echo "Untagged images:"

  #shellcheck disable=SC2046
  docker_image_maintenance_helper $(dockercmd images --filter "dangling=true" -q --no-trunc)

  echo "Apache Yetus images:"

  # removing this by image id doesn't always work without a force
  # in the situations that, for whatever reason, docker decided
  # to use the same image. this was a rare problem with older
  # releases of yetus. at some point, we should revisit this
  # in the mean time, we're going to reconstruct the
  # repostory:tag and send that to get removed.

  #shellcheck disable=SC2046,SC2016
  docker_image_maintenance_helper $(dockercmd images | ${GREP} -e ^yetus | grep tp- | ${AWK} '{print $1":"$2}')
  #shellcheck disable=SC2046,SC2016
  docker_image_maintenance_helper $(dockercmd images | ${GREP} -e ^yetus | ${GREP} -v hours | ${AWK} '{print $1":"$2}')

  if [[ "${SENTINTAL}" = false ]]; then
    return
  fi

  echo "Other images:"
  #shellcheck disable=SC2046,SC2016
  docker_image_maintenance_helper $(dockercmd images | tail -n +2 | ${GREP} -v hours  | ${AWK} '{print $1":"$2}')
}


## @description  Perform pre-run maintenance to free up
## @description  resources. With --jenkins, it is a lot
## @description  more destructive.
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_cleanup
{

  docker_image_maintenance

  docker_container_maintenance
}

## @description  Deterine the user name and user id of the user
## @description  that the docker container should use
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_determine_user
{
  # On the Apache Jenkins hosts, $USER is pretty much untrustable beacuse some
  # ... person ... sets it to an account that doesn't actually exist.
  # so instead, we need to try and override it with something that's
  # probably close to reality.
  if [[ ${TESTPATCHMODE} =~ jenkins ]]; then
    USER=$(id | cut -f2 -d\( | cut -f1 -d\))
  fi

  if [[ "$(uname -s)" == "Linux" ]]; then
    USER_NAME=${SUDO_USER:=$USER}
    USER_ID=$(id -u "${USER_NAME}")
    GROUP_ID=$(id -g "${USER_NAME}")
  else # boot2docker uid and gid
    USER_NAME=${USER}
    USER_ID=1000
    GROUP_ID=50
  fi
}

## @description  Determine the revision of a dockerfile
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_getfilerev
{
  ${GREP} 'YETUS_PRIVATE: gitrev=' \
        "${PATCH_DIR}/precommit/test-patch-docker/Dockerfile" \
          | cut -f2 -d=
}

function docker_version
{
  declare vertype=$1
  declare val


  # new version command
  val=$(dockercmd version --format "{{.${vertype}.Version}}" 2>/dev/null)

  if [[ $? != 0 ]];then
    # old version command
    val=$(dockercmd version | ${GREP} "${vertype} version" | cut -f2 -d: | tr -d ' ')
  fi

  echo "${val}"
}

## @description  Start a test patch docker container
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_run_image
{
  declare dockerfilerev
  declare baseimagename
  declare patchimagename="yetus/${PROJECT_NAME}:tp-${DOCKER_ID}"
  declare containername="yetus_tp-${DOCKER_ID}"
  declare client
  declare server
  declare retval
  declare elapsed

  dockerfilerev=$(docker_getfilerev)

  baseimagename="yetus/${PROJECT_NAME}:${dockerfilerev}"

  # make a base image, if it isn't available
  big_console_header "Building base image: ${baseimagename}"
  start_clock
  dockercmd build \
    -t "${baseimagename}" \
    "${PATCH_DIR}/precommit/test-patch-docker"
  retval=$?

  #shellcheck disable=SC2046
  elapsed=$(clock_display $(stop_clock))

  echo ""
  echo "Total Elapsed time: ${elapsed}"
  echo ""

  if [[ ${retval} != 0 ]]; then
    yetus_error "ERROR: Docker failed to build image."
    add_vote_table -1 docker "Docker failed to build ${baseimagename}."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  big_console_header "Building ${BUILDMODE} image: ${patchimagename}"
  start_clock
  # using the base image, make one that is patch specific
  dockercmd build \
    -t "${patchimagename}" \
    - <<PatchSpecificDocker
FROM ${baseimagename}
LABEL org.apache.yetus=""
LABEL org.apache.yetus.testpatch.patch="tp-${DOCKER_ID}"
LABEL org.apache.yetus.testpatch.project=${PROJECT_NAME}
RUN groupadd --non-unique -g ${GROUP_ID} ${USER_NAME} || true
RUN useradd -g ${GROUP_ID} -u ${USER_ID} -m ${USER_NAME} || true
RUN chown -R ${USER_NAME} /home/${USER_NAME} || true
ENV HOME /home/${USER_NAME}
USER ${USER_NAME}
PatchSpecificDocker

  retval=$?

  #shellcheck disable=SC2046
  elapsed=$(clock_display $(stop_clock))

  echo ""
  echo "Total Elapsed time: ${elapsed}"
  echo ""

  if [[ ${retval} != 0 ]]; then
    yetus_error "ERROR: Docker failed to build image."
    add_vote_table -1 docker "Docker failed to build ${patchimagename}."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  if [[ "${DOCKER_ENABLE_PRIVILEGED}" = true ]]; then
    DOCKER_EXTRAARGS=("--privileged" "${DOCKER_EXTRAARGS[@]}")
  fi

  if [[ -n "${CONSOLE_REPORT_FILE}" ]]; then
    touch "${CONSOLE_REPORT_FILE}"
    DOCKER_EXTRAARGS=("${DOCKER_EXTRAARGS[@]}" "-v" "${CONSOLE_REPORT_FILE}:/testptch/console.txt")
  fi

  client=$(docker_version Client)
  server=$(docker_version Server)

  dockerversion="Client=${client} Server=${server}"
  if [[ ${PATCH_DIR} =~ ^/ ]]; then
    exec "${DOCKERCMD}" run --rm=true -i \
      "${DOCKER_EXTRAARGS[@]}" \
      -v "${PWD}:/testptch/${PROJECT_NAME}" \
      -v "${PATCH_DIR}:/testptch/patchprocess" \
      -u "${USER_NAME}" \
      -w "/testptch/${PROJECT_NAME}" \
      --env=BASEDIR="/testptch/${PROJECT_NAME}" \
      --env=DOCKER_VERSION="${dockerversion} Image:${baseimagename}" \
      --env=JAVA_HOME="${JAVA_HOME}" \
      --env=PATCH_DIR=/testptch/patchprocess \
      --env=PATCH_SYSTEM="${PATCH_SYSTEM}" \
      --env=PROJECT_NAME="${PROJECT_NAME}" \
      --env=TESTPATCHMODE="${TESTPATCHMODE}" \
      --name "${containername}" \
      "${patchimagename}"
  else
    exec "${DOCKERCMD}" run --rm=true -i \
      "${DOCKER_EXTRAARGS[@]}" \
      -v "${PWD}:/testptch/${PROJECT_NAME}" \
      -u "${USER_NAME}" \
      -w "/testptch/${PROJECT_NAME}" \
      --env=BASEDIR="/testptch/${PROJECT_NAME}" \
      --env=DOCKER_VERSION="${DOCKER_VERSION} Image:${baseimagename}" \
      --env=JAVA_HOME="${JAVA_HOME}" \
      --env=PATCH_DIR="${PATCH_DIR}" \
      --env=PATCH_SYSTEM="${PATCH_SYSTEM}" \
      --env=PROJECT_NAME="${PROJECT_NAME}" \
      --env=TESTPATCHMODE="${TESTPATCHMODE}" \
      --name "${containername}" \
      "${patchimagename}"
  fi

  # this should never get reached, but we put it here just in case
  cleanup_and_exit 1
}

## @description  Switch over to a Docker container
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_handler
{
  PATCH_DIR=$(relative_dir "${PATCH_DIR}")

  docker_cleanup
  docker_determine_user
  docker_run_image
}
