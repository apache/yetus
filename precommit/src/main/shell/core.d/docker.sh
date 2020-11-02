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
DOCKERCMD=$(command -v docker 2>/dev/null)
DOCKER_BUILDKIT_SETTING=${DOCKER_BUILDKIT_SETTING:-true}
unset DOCKER_BUILDKIT
DOCKER_ID=${RANDOM}
DOCKER_DESTRUCTIVE=true
DOCKERFILE_DEFAULT="${BINDIR}/test-patch-docker/Dockerfile"
DOCKERSUPPORT=false
DOCKER_ENABLE_PRIVILEGED=false
DOCKER_CLEANUP_CMD=false
DOCKER_MEMORY="4g"
DOCKER_PLATFORM=""
DOCKER_TAG=""
DOCKER_IN_DOCKER=false
DOCKER_SOCKET="/var/run/docker.sock"
DOCKER_SOCKET_GID=-1
DOCKER_WORK_DIR="/precommit"

declare -a DOCKER_EXTRAARGS
declare -a DOCKER_EXTRABUILDARGS
declare -a DOCKER_VERSION

DOCKER_EXTRAENVS+=("JAVA_HOME")
DOCKER_EXTRAENVS+=("PATCH_SYSTEM")
DOCKER_EXTRAENVS+=("PROJECT_NAME")

YETUS_DOCKER_BASH_DEBUG=false

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
  if [[ "${DOCKER_CLEANUP_CMD}" == false ]]; then
    yetus_add_option "--docker" "Spawn a docker container"
  fi
  yetus_add_option "--dockercmd=<file>" "Command to use as docker executable (default: '${DOCKERCMD}')"
  yetus_add_option "--docker-buildkit=<bool>" "Set the Docker BuildKit availability (default: ${DOCKER_BUILDKIT_SETTING})'"
  if [[ "${DOCKER_CLEANUP_CMD}" == false ]]; then
    yetus_add_option "--docker-bash-debug=<bool>" "Enable bash -x mode running in a container (default: ${YETUS_DOCKER_BASH_DEBUG})"
    yetus_add_option "--docker-cache-from=<image>" "Comma delimited images to use as a cache when building"
    yetus_add_option "--dockerfile=<file>" "Dockerfile fragment to use as the base (default: '${DOCKERFILE_DEFAULT}')"
    yetus_add_option "--dockerind=<bool>" "Enable Docker-in-Docker by mounting the Docker socket in the container (default: '${DOCKER_IN_DOCKER}')"
    yetus_add_option "--docker-platform=<plat>" "Use a platform string for building and pulling (default: ${DOCKER_PLATFORM})"
    yetus_add_option "--dockerprivd=<bool>" "Run docker in privileged mode (default: '${DOCKER_ENABLE_PRIVILEGED}')"
    yetus_add_option "--docker-socket=<socket>" "Mount given socket as /var/run/docker.sock into the container when Docker-in-Docker mode is enabled (default: '${DOCKER_SOCKET}')"
    yetus_add_option "--docker-tag=<tag>" "Use the given Docker tag as the base"
    yetus_add_option "--docker-work-dir=<directory>" "Disposable, safe dir for precommit work (default: ${DOCKER_WORK_DIR}"
  fi
  yetus_add_option "--dockerdelrep" "In Docker mode, only report image/container deletions, not act on them"
  if [[ "${DOCKER_CLEANUP_CMD}" == false ]]; then
    yetus_add_option "--dockermemlimit=<num>" "Limit a Docker container's memory usage (default: ${DOCKER_MEMORY})"
  fi
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
        delete_parameter "${i}"
        DOCKERSUPPORT=true
      ;;
      --docker-bash-debug=*)
        delete_parameter "${i}"
        YETUS_DOCKER_BASH_DEBUG=${i#*=}
        add_docker_env YETUS_DOCKER_BASH_DEBUG
      ;;
      --docker-buildkit=*)
        delete_parameter "${i}"
        DOCKER_BUILDKIT_SETTING=${i#*=}
      ;;
      --docker-cache-from=*)
        delete_parameter "${i}"
        DOCKER_CACHE_FROM=${i#*=}
      ;;
      --dockercmd=*)
        delete_parameter "${i}"
        #shellcheck disable=SC2034
        DOCKERCMD=${i#*=}
      ;;
      --dockerdelrep)
        delete_parameter "${i}"
        DOCKER_DESTRUCTIVE=false
      ;;
      --dockerfile=*)
        delete_parameter "${i}"
        DOCKERFILE=${i#*=}
      ;;
      --dockerind=*)
        delete_parameter "${i}"
        DOCKER_IN_DOCKER=${i#*=}
      ;;
      --dockermemlimit=*)
        delete_parameter "${i}"
        DOCKER_MEMORY=${i#*=}
      ;;
      --dockermode)
        delete_parameter "${i}"
        DOCKERMODE=true
      ;;
      --docker-platform=*)
        delete_parameter "${i}"
        DOCKER_PLATFORM=${i#*=}
      ;;
      --dockerprivd=*)
        delete_parameter "${i}"
        DOCKER_ENABLE_PRIVILEGED=${i#*=}
      ;;
      --docker-socket=*)
        delete_parameter "${i}"
        DOCKER_SOCKET=${i#*=}
      ;;
      --docker-tag=*)
        delete_parameter "${i}"
        DOCKER_TAG=${i#*=}
      ;;
      --docker-work-dir=*)
        delete_parameter "${i}"
        DOCKER_WORK_DIR=${i#*=}
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
  declare -a footer

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
    # DOCKER_VERSION_STR is set by our creator.
    footer=("${DOCKER_VERSION_STR}")

    if [[ -n "${DOCKERFROM}" ]]; then
      footer+=("base:" "${DOCKERFROM}")
    elif [[ -f "${PATCH_DIR}/Dockerfile" ]]; then
      footer+=("base:" "@@BASE@@/Dockerfile")
    fi
    if [[ -n "${DOCKER_PLATFORM}" ]]; then
      footer+=("platform:" "${DOCKER_PLATFORM}")
    fi
    add_footer_table "Docker" "${footer[*]}"
    return
  fi

  # docker mode hasn't been requested
  if [[ "${DOCKERSUPPORT}" != true ]]; then
    return
  fi

  dockvers=$(docker_version Client)
  IFS='.' read -r -a DOCKER_VERSION <<< "${dockvers}"
  if [[ "${DOCKER_VERSION[0]}" -lt 1 ]] || \
     [[ "${DOCKER_VERSION[0]}" -lt 2 && "${DOCKER_VERSION[1]}" -lt 27 ]]; then
    add_vote_table_v2 -1 docker "" "Docker command '${DOCKERCMD}' is too old (${dockvers} <  API v 1.27.0)."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  # stat is non-POSIX but one of two forms is generally
  # present on a machine.  See also precommit-docker.md docs.
  if [[ "${OSTYPE}" == "Darwin" ]]; then
    # At the user level, OS X lies about the permissions on the
    # socket due to the VM-layer that is present.
    DOCKER_SOCKET_GID=0
  elif "${STAT}" -c '%g' "${DOCKER_SOCKET}" >/dev/null 2>&1; then
    DOCKER_SOCKET_GID=$("${STAT}" -c '%g' "${DOCKER_SOCKET}")
  elif "${STAT}" -f '%g' "${DOCKER_SOCKET}" >/dev/null 2>&1; then
    DOCKER_SOCKET_GID=$("${STAT}" -f '%g' "${DOCKER_SOCKET}")
  elif [[ ${DOCKER_IN_DOCKER} == true ]]; then
    add_vote_table_v2 -1 docker "" "Docker-in-Docker mode (--dockerind) requires a working stat command."
    bugsystem_finalreport 1
    cleanup_and_exit 1
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
      pushd "${STARTINGDIR}" >/dev/null || return 1
      if [[ -f ${DOCKERFILE} ]]; then
        DOCKERFILE=$(yetus_abs "${DOCKERFILE}")
      else
        yetus_error "ERROR: Dockerfile '${DOCKERFILE}' not found."
        add_vote_table_v2 -1 docker "" "Dockerfile '${DOCKERFILE}' not found."
        bugsystem_finalreport 1
        cleanup_and_exit 1
      fi
      popd >/dev/null || return 1
    elif [[ -n "${DOCKER_TAG}" ]]; then
      # do this later as part of the docker handler
      :
    else
      if [[ -n "${DOCKER_PLATFORM}" ]]; then
        dockplat=('--platform' "${DOCKER_PLATFORM}")
      fi

      echo "No --dockerfile or --docker-tag provided. Attempting to pull apache/yetus:${VERSION}."

      if dockercmd pull "${dockplat[@]}" "apache/yetus:${VERSION}"; then
        echo "Pull succeeded; will build with pulled image."
        DOCKER_TAG="apache/yetus:${VERSION}"
      else
        echo "Pull failed; will build with built-in Dockerfile."
        DOCKERFILE=${DOCKERFILE_DEFAULT}
      fi
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

  if ! ${DOCKERCMD} info >/dev/null 2>&1; then
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

## @description  Convert docker's time format to ctime
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        time
function dockerdate_to_ctime
{
  declare mytime=$1

  if [[ "${mytime}" = "0001-01-01T00:00:00Z" ]]; then
    mytime="1970-01-01T00:00:00"
  fi

  # believe it or not, date is not even close to standardized...
  if [[ $(uname -s) == Linux ]]; then
    # GNU date
    date -d "${mytime}" "+%s"
  else
    # BSD date; go/docker gives us two different format because fun
    if ! date -j -f "%FT%T%z" "${mytime}" "+%s" 2>/dev/null; then
      date -j -f "%FT%T" "${mytime}" "+%s"
    fi
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
    curtime=$(yetus_get_ctime)
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
      exited | dead)
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
     dockercmd container inspect \
        --format '{{.Id}},{{.State.Status}},{{.Created}},{{.State.StartedAt}},{{.State.FinishedAt}},{{.Name}}' \
       ${data})
}

## @description  Untag docker images for a given id
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        imageid
function docker_untag_images
{
  declare id=$1
  declare i
  declare imagestr
  declare -a images

  # ["image1","image2","image3"]
  imagestr=$(dockercmd inspect -f '{{json .RepoTags}}' "${id}")
  imagestr=${imagestr#"["}
  imagestr=${imagestr%"]"}
  imagestr=${imagestr//\"}

  yetus_comma_to_array images "${imagestr}"

  for i in "${images[@]}"; do
    if dockercmd inspect -f '{{json .Size}}' "${i}" >/dev/null 2>&1;then
      dockercmd rmi "${i}"
    fi
  done
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
    tmptime=$(dockercmd image inspect --format '{{.Created}}' "${id}" | cut -f1 -d. )
    createtime=$(dockerdate_to_ctime "${tmptime}")
    curtime=$(yetus_get_ctime)

    ((difftime = curtime - createtime))
    if [[ ${difftime} -gt ${DOCKER_IMAGE_PURGE} ]]; then
      echo "Attempting to remove docker image ${id}"
      docker_untag_images "${id}"
      if dockercmd inspect -f '{{json .Size}}' "${id}" >/dev/null 2>&1;then
        dockercmd rmi "${id}"
      fi
    fi
  done
}


## @description  get sentinel-level docker images
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_get_sentinel_images
{
  #shellcheck disable=SC2016
  dockercmd images \
    | tail -n +2 \
    | "${GREP}" -v hours \
    | "${AWK}" '{print $3}'
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

  #shellcheck disable=SC2046
  docker_image_maintenance_helper $(dockercmd images --filter "label=org.apache.yetus" -q --no-trunc)

  if [[ "${SENTINEL}" = false ]]; then
    return
  fi

  echo "Other images:"
  #shellcheck disable=SC2046
  docker_image_maintenance_helper $(docker_get_sentinel_images)
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

## @description  determine the docker version
## @stability    stable
## @audience     private
## @replaceable  no
function docker_version
{
  declare vertype=$1
  declare val
  declare ret

  # new version command
  val=$(dockercmd version --format "{{.${vertype}.APIVersion}}" 2>/dev/null)
  ret=$?

  if [[ ${ret} != 0 ]];then
    # old version command
    val=$(dockercmd version | ${GREP} "${vertype} version" | cut -f2 -d: | tr -d ' ')
  fi

  echo "${val}"
}

## @description  Queue Docker build-args to add to the docker build
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        envname
## @param        [value]
function add_docker_build_arg
{
  declare key="$1"
  declare value="$2"
  if [[ -z "${value}" ]]; then
    DOCKER_EXTRABUILDARGS+=("--build-arg" "${key}")
  else
    DOCKER_EXTRABUILDARGS+=("--build-arg" "${key}=${value}")
  fi
}

## @description  Queue env vars to add to the docker env
## @audience     public
## @stability    stable
## @replaceable  yes
## @param        envname
## @param        ...
function add_docker_env
{
  for k in "$@"; do
    DOCKER_EXTRAENVS+=("${k}")
  done
}

## @description  Do the work to add the env vars onto the Docker cmd
## @audience     private
## @stability    stable
## @replaceable  yes
function docker_do_env_adds
{
  declare k

  for k in "${DOCKER_EXTRAENVS[@]}"; do
    DOCKER_EXTRAARGS+=("--env=${k}=${!k}")
  done
}

## @description  Start a test patch docker container
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_run_image
{
  declare gitfilerev
  declare baseimagename
  declare patchimagename="yetus/${PROJECT_NAME}:tp-${DOCKER_ID}"
  declare containername="yetus_tp-${DOCKER_ID}"
  declare client
  declare server
  declare retval
  declare elapsed
  declare dockerdir
  declare lines
  declare dockerversion
  declare -a dockplat
  declare -a cachefrom
  declare -a images

  big_console_header "Docker Image Creation"
  start_clock

  if [[ "${DOCKER_BUILDKIT_SETTING}" == true ]]; then
    export DOCKER_BUILDKIT=1
  fi

  if [[ -n "${DOCKER_PLATFORM}" ]]; then
    dockplat=('--platform' "${DOCKER_PLATFORM}")
  fi

  if [[ -n "${DOCKER_TAG}" ]]; then
    # pull the base image from the provided docker tag

    if ! dockercmd pull "${dockplat[@]}" "${DOCKER_TAG}"; then
      yetus_error "ERROR: Docker failed to pull ${DOCKER_TAG}."
      add_vote_table_v2 -1 docker "" "Docker failed to pull ${DOCKER_TAG}."
      bugsystem_finalreport 1
      cleanup_and_exit 1
    fi
    baseimagename=${DOCKER_TAG}

  elif [[ -n ${DOCKERFILE} && -f ${DOCKERFILE} ]]; then

    # make a base image. if it is available/cached, this will go quick
    dockerdir=$(dirname "${DOCKERFILE}")

    pushd "${dockerdir}" >/dev/null || return 1
    # grab the git commit sha if this is part of a git repo, even if
    # it is part of another git repo other than the one being tested!
    gitfilerev=$("${GIT}" log -n 1 --pretty=format:%h -- "${DOCKERFILE}" 2>/dev/null)
    if [[ -z ${gitfilerev} ]]; then
      gitfilerev=$(date "+%F")
      gitfilerev="date${gitfilerev}"
    fi

    # we will need this for reporting later
    baseimagename="yetus/${PROJECT_NAME}:${gitfilerev}"

    # create a new Dockerfile in the patchdir to actually use to
    # build with, stripping everything after the cut here line
    # (if it exists)
    lines=$("${AWK}" '/YETUS CUT HERE/ {print FNR; exit}' "${DOCKERFILE}")

    buildfile="${PATCH_DIR}/Dockerfile"
    if [[ ${lines} -gt 0 ]]; then
      if [[ "${DOCKER_VERSION[0]}" -lt 1 ]] || \
       [[ "${DOCKER_VERSION[0]}" -lt 2 && "${DOCKER_VERSION[1]}" -lt 38 ]]; then

        # versions less than 18 don't support having the
        # Dockerfile outside of the build context. Let's fall back to
        # pre-YETUS-723 behavior and put the re-written Dockerfile
        # outside of the source tree rather than go through a lot of
        # machinations.  This means COPY, ADD, etc do not work, but
        # whatever

        popd >/dev/null || return 1
        buildfile="${PATCH_DIR}/test-patch-docker/Dockerfile"
        dockerdir="${PATCH_DIR}/test-patch-docker"
        mkdir -p "${dockerdir}"
        pushd "${PATCH_DIR}/test-patch-docker" >/dev/null || return 1
      fi
    fi

    (
      if [[ -z "${lines}" ]]; then
        cat "${DOCKERFILE}"
      else
        head -n "${lines}" "${DOCKERFILE}"
      fi
    ) > "${buildfile}"

    if [[ ${lines} -gt 0 ]]; then
      if [[ "${DOCKER_VERSION[0]}" -lt 1 ]] || \
       [[ "${DOCKER_VERSION[0]}" -lt 2 && "${DOCKER_VERSION[1]}" -lt 38 ]]; then
        # Need to put our re-constructed Dockerfile in a place
        # where it can be referenced in the output post-run
        cp -p "${buildfile}" "${PATCH_DIR}/Dockerfile"
      fi
    fi

    if [[ -n "${DOCKER_CACHE_FROM}" ]]; then
      yetus_comma_to_array images "${DOCKER_CACHE_FROM}"
      for i in "${images[@]}"; do
        docker pull "${i}" || true
      done
      cachefrom=("--cache-from=yetus/${PROJECT_NAME}:${gitfilerev},${DOCKER_CACHE_FROM}")
    fi

    if ! dockercmd build \
          "${dockplat[@]}" \
          "${cachefrom[@]}" \
          --label org.apache.yetus=\"\" \
          --label org.apache.yetus.testpatch.project="${PROJECT_NAME}" \
          --tag "${baseimagename}" \
          "${DOCKER_EXTRABUILDARGS[@]}" \
          -f "${buildfile}" \
          "${dockerdir}"; then
      popd >/dev/null || return 1
      yetus_error "ERROR: Docker failed to build ${baseimagename}."
      add_vote_table_v2 -1 docker "" "Docker failed to build ${baseimagename}."
      bugsystem_finalreport 1
      cleanup_and_exit 1
    fi
    popd >/dev/null || return 1
  fi

  echo "Building run-specific image ${patchimagename}"

  # create a directory from scratch so that our
  # build context is tightly controlled
  randir=${PATCH_DIR}/${RANDOM}
  mkdir -p "${randir}"
  pushd "${randir}" >/dev/null || return 1
  cp -p "${BINDIR}"/test-patch-docker/Dockerfile.patchspecific \
     "${randir}"/Dockerfile
  cp -p "${BINDIR}"/test-patch-docker/launch-test-patch.sh \
     "${randir}"


  for lines in "${USER_PARAMS[@]}"; do
    if [[ ${lines} != '--docker' ]]; then
      echo "${lines}" >> "${randir}/user_params.txt"
    fi
  done

  add_docker_env DOCKER_WORK_DIR

  # using the base image, make one that is patch specific
  dockercmd build \
    "${dockplat[@]}" \
    --no-cache \
    --build-arg baseimagename="${baseimagename}" \
    --build-arg GROUP_ID="${GROUP_ID}" \
    --build-arg USER_ID="${USER_ID}" \
    --build-arg USER_NAME="${USER_NAME}" \
    --build-arg DOCKER_SOCKET_GID="${DOCKER_SOCKET_GID}" \
    --build-arg DOCKER_WORK_DIR="${DOCKER_WORK_DIR}" \
    "${DOCKER_EXTRABUILDARGS[@]}" \
    --label org.apache.yetus=\"\" \
    --label org.apache.yetus.testpatch.patch="tp-${DOCKER_ID}" \
    --label org.apache.yetus.testpatch.project="${PROJECT_NAME}" \
    --tag "${patchimagename}" \
    "${randir}" >/dev/null
  retval=$?
  popd >/dev/null || return 1

  rm -rf "${randir}"

  if [[ ${retval} != 0 ]]; then
    yetus_error "ERROR: Docker failed to build run-specific ${patchimagename}."
    add_vote_table_v2 -1 docker "" "Docker failed to build run-specific ${patchimagename}}."
    bugsystem_finalreport 1
    cleanup_and_exit 1
  fi

  #shellcheck disable=SC2046
  elapsed=$(clock_display $(stop_clock))

  echo ""
  echo "Total elapsed build time: ${elapsed}"
  echo ""

  if [[ "${DOCKER_ENABLE_PRIVILEGED}" = true ]]; then
    DOCKER_EXTRAARGS+=("--privileged")
  fi

  if [[ -n "${DOCKER_MEMORY}" ]]; then
    DOCKER_EXTRAARGS+=("-m" "${DOCKER_MEMORY}")
  fi

  client=$(docker_version Client)
  server=$(docker_version Server)

  dockerversion="ClientAPI=${client} ServerAPI=${server}"

  # make the kernel prefer to kill us if we run out of RAM
  DOCKER_EXTRAARGS+=("--oom-score-adj" "500")

  DOCKER_EXTRAARGS+=("--cidfile=${PATCH_DIR}/cidfile.txt")

  if [[ "${DOCKER_IN_DOCKER}" == true ]]; then
    if [[ -e "${DOCKER_SOCKET}" ]]; then
      DOCKER_EXTRAARGS+=(-v "${DOCKER_SOCKET}:/var/run/docker.sock")
    fi
  fi

  DOCKER_EXTRAARGS+=(-v "${BASEDIR}:${BASEDIR}")
  DOCKER_EXTRAARGS+=(-u "${USER_NAME}")
  DOCKER_EXTRAARGS+=(-w "${BASEDIR}")
  DOCKER_EXTRAARGS+=("--env=BASEDIR=${BASEDIR}")
  DOCKER_EXTRAARGS+=("--env=DOCKER_VERSION_STR=${dockerversion}")

  docker_do_env_adds

  DOCKER_EXTRAARGS+=(--name "${containername}")

  trap 'docker_signal_handler' SIGTERM SIGINT SIGHUP

  if [[ ${PATCH_DIR} =~ ^/ ]]; then
    dockercmd run --rm=true -i \
      "${dockplat[@]}" \
      "${DOCKER_EXTRAARGS[@]}" \
      -v "${PATCH_DIR}:${PATCH_DIR}" \
      --env=PATCH_DIR="${PATCH_DIR}" \
      "${patchimagename}" &
  else
    dockercmd run --rm=true -i \
      "${dockplat[@]}" \
      "${DOCKER_EXTRAARGS[@]}" \
      --env=PATCH_DIR="${PATCH_DIR}" \
      "${patchimagename}" &
  fi
  wait ${!}
  retval=$?

  printf '\n\n'
  echo "Cleaning up docker image used for testing."
  dockercmd rmi "${patchimagename}" > /dev/null
  rm "${PATCH_DIR}/cidfile.txt"
  cleanup_and_exit ${retval}
}

## @description  docker kill the container on SIGTERM
## @audience     private
## @stability    evolving
## @replaceable  no
function docker_signal_handler
{
  declare cid

  cid=$(cat "${PATCH_DIR}/cidfile.txt")

  yetus_error "ERROR: Caught signal. Killing docker container:"
  echo "ERROR: Caught signal. Killing docker container: ${cid}" > "${PATCH_DIR}/signal.log"
  dockercmd kill "${cid}" | tee -a "${PATCH_DIR}/signal.log"
  rm "${PATCH_DIR}/cidfile.txt"
  yetus_error "ERROR: Exiting."
  cleanup_and_exit 143 # 128 + 15 -- SIGTERM
}

## @description  Switch over to a Docker container
## @audience     private
## @stability    evolving
## @replaceable  no
## @param        args
function docker_handler
{
  declare plugin
  declare person

  ## @description  strip paths for display
  ## @audience     private
  ## @stability    evolving
  function strippaths {
    declare p=$1
    declare d
    for d in "${BASEDIR}" "${PATCH_DIR}" "${BINDIR}"; do
      p=$(yetus_relative_dir "${d}" "${p}")
    done
    echo "${p}"
  }


  determine_user

  # need to call this explicitly
  console_docker_support

  for plugin in ${PROJECT_NAME} ${BUILDTOOL} "${BUGSYSTEMS[@]}" "${TESTTYPES[@]}" "${TESTFORMATS[@]}"; do
    if declare -f "${plugin}_docker_support" >/dev/null; then
      "${plugin}_docker_support"
    fi
  done

  if [[ -n "${BUILD_URL}" ]]; then
    USER_PARAMS+=("--build-url=${BUILD_URL}")
  fi

  if [[ -f "${PERSONALITY}" ]]; then
    person=$(strippaths "${PERSONALITY}")
    USER_PARAMS+=("--tpperson=${person}")
  fi

  USER_PARAMS+=("--tpglobaltimer=${GLOBALTIMER}")
  USER_PARAMS+=("--tpreexectimer=${TIMER}")
  USER_PARAMS+=("--tpinstance=${INSTANCE}")
  USER_PARAMS+=("--plugins=${ENABLED_PLUGINS// /,}")

  #shellcheck disable=SC2164
  cd "${BASEDIR}"

  PATCH_DIR=$(yetus_relative_dir "${BASEDIR}" "${PATCH_DIR}")

  docker_cleanup
  docker_run_image
}
