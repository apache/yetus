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

DOCKER_ID=${RANDOM}
DOCKER_DESTRUCTIVE=true

## @description  Verify docker exists
## @audience     private
## @stability    evolving
## @replaceable  no
## @returns      1 if docker not found
## @returns      0 if docker is found
function dockerverify
{
  declare pathdocker

  if [[ -z "${DOCKERCMD}" ]]; then
    pathdocker=$(which docker 2>/dev/null)

    if [[ ! -f "${pathdocker}" ]]; then
      yetus_error "Docker cannot be found."
      return 1
    fi
    DOCKERCMD="${pathdocker}"
  fi

  if [[ ! -x "${DOCKERCMD}" ]];then
    yetus_error "Docker command ${DOCKERCMD} is not executable."
    return 1
  fi
  return 0
}

## @description  Run docker with some arguments, and
## @description  optionally send to debug
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function dockercmd
{
  yetus_debug "${DOCKERCMD} $*"
  "${DOCKERCMD}" "$@"
}

## @description  Stop and delete all defunct containers
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_stop_exited_containers
{
  declare line
  declare id
  declare value
  declare size
  declare exitfn="${PATCH_DIR}/dsec.$$"

  big_console_header "Removing stopped/exited containers"

  echo "Docker containers in exit state:"

  dockercmd ps -a | ${GREP} Exited > "${exitfn}"
  if [[ ! -s "${exitfn}" ]]; then
    return
  fi

  # stop *all* containers that are in exit state for
  # more than > 8 hours
  while read -r line; do
     id=$(echo "${line}" | cut -f1 -d' ')
     value=$(echo "${line}" | cut -f2 -d' ')
     size=$(echo "${line}" | cut -f3 -d' ')

     if [[ ${size} =~ day
        || ${size} =~ week
        || ${size} =~ month
        || ${size} =~ year ]]; then
          echo "Removing docker ${id}"
          if [[ "${DOCKER_DESTRUCTIVE}" = true ]]; then
            dockercmd rm "${id}"
          else
            echo docker rm "${id}"
          fi
     fi

     if [[ ${size} =~ hours
        && ${value} -gt 8 ]]; then
        echo "Removing docker ${id}"
        if [[ "${DOCKER_DESTRUCTIVE}" = true ]]; then
          dockercmd rm "${id}"
        else
          echo docker rm "${id}"
        fi
     fi
  done < <(
    ${SED} -e 's,ago,,g' "${exitfn}"\
    | ${AWK} '{print $1" "$(NF - 2)" "$(NF - 1)}')
  rm "${exitfn}"
}

## @description  Remove all containers that are not
## @description  are not running + older than 1 day
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_rm_old_containers
{
  declare line
  declare id
  declare value
  declare size
  declare running

  big_console_header "Removing old containers"

  while read -r line; do
    id=$(echo "${line}" | cut -f1 -d, )
    running=$(echo "${line}" | cut -f2 -d, )
    stoptime=$(echo "${line}" | cut -f3 -d, | cut -f1 -d. )

    if [[ ${running} = true ]]; then
      yetus_debug "${id} is still running, skipping."
      continue
    fi

    # believe it or not, date is not even close to standardized...
    if [[ $(uname -s) == Linux ]]; then

      # GNU date
      stoptime=$(date -d "${stoptime}" "+%s")
    else

      # BSD date
      stoptime=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${stoptime}" "+%s")
    fi

    curtime=$(date "+%s")
    ((difftime = curtime - stoptime))
    if [[ ${difftime} -gt 86400 ]]; then
      echo "Removing docker ${id}"
      if [[ "${DOCKER_DESTRUCTIVE}" = true ]]; then
        dockercmd rm "${id}"
      else
        echo docker rm "${id}"
      fi
    fi
  done < <(
   # see https://github.com/koalaman/shellcheck/issues/375
   # shellcheck disable=SC2046
    dockercmd inspect \
      -f '{{.Id}},{{.State.Running}},{{.State.FinishedAt}}' \
       $(dockercmd ps -qa) 2>/dev/null)
}

## @description  Remove untagged/unu${SED} images
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_remove_untagged_images
{

  big_console_header "Removing untagged images"

  # this way is a bit more compatible with older docker versions
  # shellcheck disable=SC2016
  dockercmd images | tail -n +2 | ${AWK} '$1 == "<none>" {print $3}' | \
    xargs --no-run-if-empty docker rmi
}

## @description  Remove defunct tagged images
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_remove_old_tagged_images
{
  declare line
  declare id
  declare created

  big_console_header "Removing old tagged images"

  while read -r line; do
    # shellcheck disable=SC2016
    id=$(echo "${line}" | ${AWK} '{print $1":"$2}')
    # shellcheck disable=SC2016
    created=$(echo "${line}" | ${AWK} '{print $5}')

    if [[ ${created} =~ week
       || ${created} =~ month
       || ${created} =~ year ]]; then
         echo "Removing docker image ${id}"
         if [[ "${DOCKER_DESTRUCTIVE}" = true ]]; then
           dockercmd rmi "${id}"
         else
           echo docker rmi "${id}"
         fi
    fi

    if [[ ${id} =~ yetus/${PROJECT_NAME}:date
       || ${id} =~ test-patch- ]]; then
      if [[ ${created} =~ day
        || ${created} =~ hours ]]; then
        echo "Removing docker image ${id}"
        if [[ "${DOCKER_DESTRUCTIVE}" = true ]]; then
          dockercmd rmi "${id}"
        else
          echo docker rmi "${id}"
        fi
      fi
    fi
  done < <(dockercmd images)
}

## @description  Performance docker maintenance on Jenkins
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_cleanup_apache_jenkins
{
  echo "=========================="
  echo "Docker Images:"
  dockercmd images
  echo "=========================="
  echo "Docker Containers:"
  dockercmd ps -a
  echo "=========================="

  docker_stop_exited_containers

  docker_rm_old_containers

  docker_remove_untagged_images

  docker_remove_old_tagged_images
}

## @description  Clean up our old images u${SED} for patch testing
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_cleanup_yetus_images
{
  declare images
  declare imagecount
  declare rmimage
  declare rmi

  # we always want to leave at least one of our images
  # so that the whole thing doesn't have to be rebuilt.
  # This also let's us purge any old images so that
  # we can get fresh stuff sometimes
  # shellcheck disable=SC2016
  images=$(dockercmd images | ${GREP} "yetus/${PROJECT_NAME}" | ${GREP} tp | ${AWK} '{print $1":"$2}') 2>&1

  # shellcheck disable=SC2086
  imagecount=$(echo ${images} | tr ' ' '\n' | wc -l)
  ((imagecount = imagecount - 1 ))

  # shellcheck disable=SC2086
  rmimage=$(echo ${images} | tr ' ' '\n' | tail -${imagecount})
  for rmi in ${rmimage}
  do
    echo "Removing image ${rmi}"
    if [[ "${DOCKER_DESTRUCTIVE}" = true ]]; then
      dockercmd rmi "${rmi}"
    else
      echo docker rmi "${rmi}"
    fi
  done
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
  if [[ ${TESTPATCHMODE} =~ jenkins ]]; then
    docker_cleanup_apache_jenkins
  fi

  docker_cleanup_yetus_images
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
  declare client
  declare server

  dockerfilerev=$(docker_getfilerev)

  baseimagename="yetus/${PROJECT_NAME}:${dockerfilerev}"

  # make a base image, if it isn't available
  big_console_header "Building base image: ${baseimagename}"
  dockercmd build -t "${baseimagename}" "${PATCH_DIR}/precommit/test-patch-docker"

  if [[ $? != 0 ]]; then
    yetus_error "ERROR: Docker failed to build image."
    add_vote_table -1 docker "Docker failed to build ${baseimagename}."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  big_console_header "Building patch image: ${patchimagename}"
  # using the base image, make one that is patch specific
  dockercmd build -t "${patchimagename}" - <<PatchSpecificDocker
FROM ${baseimagename}
RUN groupadd --non-unique -g ${GROUP_ID} ${USER_NAME}
RUN useradd -g ${GROUP_ID} -u ${USER_ID} -m ${USER_NAME}
RUN chown -R ${USER_NAME} /home/${USER_NAME}
ENV HOME /home/${USER_NAME}
USER ${USER_NAME}
PatchSpecificDocker

  if [[ $? != 0 ]]; then
    yetus_error "ERROR: Docker failed to build image."
    add_vote_table -1 docker "Docker failed to build ${patchimagename}."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  if [[ -f "${PATCH_DIR}/buildtool-docker-params.txt" ]]; then
    extraargs=$(cat "${PATCH_DIR}/buildtool-docker-params.txt")
  else
    extraargs=""
  fi

  client=$(dockermcd version | ${GREP} 'Client version' | cut -f2 -d: | tr -d ' ')
  server=$(dockercmd version | ${GREP} 'Server version' | cut -f2 -d: | tr -d ' ')

  dockerversion="Client=${client} Server=${server}"

  if [[ ${PATCH_DIR} =~ ^/ ]]; then
    exec "${DOCKERCMD}" run --rm=true -i \
      ${extraargs} \
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
      "${patchimagename}"
 else
   exec "${DOCKERCMD}" run --rm=true -i \
      ${extraargs} \
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
      "${patchimagename}"
 fi
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