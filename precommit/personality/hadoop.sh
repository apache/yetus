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

# Override these to match Apache Hadoop's requirements

personality_plugins "all,-ant,-gradle,-scalac,-scaladoc"

## @description  Globals specific to this personality
## @audience     private
## @stability    evolving
function personality_globals
{
  # shellcheck disable=SC2034
  BUILDTOOL=maven
  #shellcheck disable=SC2034
  PATCH_BRANCH_DEFAULT=trunk
  #shellcheck disable=SC2034
  PATCH_NAMING_RULE="https://wiki.apache.org/hadoop/HowToContribute"
  #shellcheck disable=SC2034
  JIRA_ISSUE_RE='^(HADOOP|YARN|MAPREDUCE|HDFS)-[0-9]+$'
  #shellcheck disable=SC2034
  GITHUB_REPO="apache/hadoop"
  #shellcheck disable=SC2034
  PYLINT_OPTIONS="--indent-string='  '"

  HADOOP_HOMEBREW_DIR=${HADOOP_HOMEBREW_DIR:-$(brew --prefix 2>/dev/null)}
  if [[ -z "${HADOOP_HOMEBREW_DIR}" ]]; then
    HADOOP_HOMEBREW_DIR=/usr/local
  fi
}

## @description  Calculate the actual module ordering
## @audience     private
## @stability    evolving
## @param        ordering
function hadoop_order
{
  declare ordering=$1
  declare hadoopm

  if [[ ${ordering} = normal ]]; then
    hadoopm="${CHANGED_MODULES[*]}"
  elif [[ ${ordering} = union ]]; then
    hadoopm="${CHANGED_UNION_MODULES}"
  elif [[ ${ordering} = mvnsrc ]]; then
    hadoopm="${MAVEN_SRC_MODULES[*]}"
  elif [[ ${ordering} = mvnsrctest ]]; then
    hadoopm="${MAVEN_SRCTEST_MODULES[*]}"
  else
    hadoopm="${ordering}"
  fi
  echo "${hadoopm}"
}

## @description  Install extra modules for unit tests
## @audience     private
## @stability    evolving
## @param        ordering
function hadoop_unittest_prereqs
{
  declare input=$1
  declare mods
  declare need_common=0
  declare building_common=0
  declare module
  declare flags
  declare fn

  # prior to running unit tests, hdfs needs libhadoop.so built
  # if we're building root, then this extra work is moot

  #shellcheck disable=SC2086
  mods=$(hadoop_order ${input})

  for module in ${mods}; do
    if [[ ${module} = hadoop-hdfs-project* ]]; then
      need_common=1
    elif [[ ${module} = hadoop-common-project/hadoop-common
      || ${module} = hadoop-common-project ]]; then
      building_common=1
    elif [[ ${module} = . ]]; then
      return
    fi
  done

  if [[ ${need_common} -eq 1
      && ${building_common} -eq 0 ]]; then
    echo "unit test pre-reqs:"
    module="hadoop-common-project/hadoop-common"
    fn=$(module_file_fragment "${module}")
    flags="$(hadoop_native_flags) $(yarn_ui2_flag)"
    pushd "${BASEDIR}/${module}" >/dev/null
    # shellcheck disable=SC2086
    echo_and_redirect "${PATCH_DIR}/maven-unit-prereq-${fn}-install.txt" \
      "${MAVEN}" "${MAVEN_ARGS[@]}" install -DskipTests ${flags}
    popd >/dev/null
  fi
}

## @description  Calculate the flags/settings for yarn-ui v2 build
## @description  based upon the OS
## @audience     private
## @stability    evolving
function yarn_ui2_flag
{

  if [[ ${BUILD_NATIVE} != true ]]; then
    return
  fi

  # Now it only tested on Linux/OSX, don't enable the profile on
  # windows until it get verified
  case ${OSTYPE} in
    Linux)
      # shellcheck disable=SC2086
      echo -Pyarn-ui
    ;;
    Darwin)
      echo -Pyarn-ui
    ;;
    *)
      # Do nothing
    ;;
  esac
}

## @description  Calculate the flags/settings for native code
## @description  based upon the OS
## @audience     private
## @stability    evolving
function hadoop_native_flags
{

  if [[ ${BUILD_NATIVE} != true ]]; then
    return
  fi

  # Based upon HADOOP-11937
  #
  # Some notes:
  #
  # - getting fuse to compile on anything but Linux
  #   is always tricky.
  # - Darwin assumes homebrew is in use.
  # - HADOOP-12027 required for bzip2 on OS X.
  # - bzip2 is broken in lots of places.
  #   e.g, HADOOP-12027 for OS X. so no -Drequire.bzip2
  #

  case ${OSTYPE} in
    Linux)
      # shellcheck disable=SC2086
      echo -Pnative -Drequire.libwebhdfs \
        -Drequire.snappy -Drequire.openssl -Drequire.fuse \
        -Drequire.test.libhadoop
    ;;
    Darwin)
      JANSSON_INCLUDE_DIR="${HADOOP_HOMEBREW_DIR}/opt/jansson/include"
      JANSSON_LIBRARY="${HADOOP_HOMEBREW_DIR}/opt/jansson/lib"
      export JANSSON_LIBRARY JANSSON_INCLUDE_DIR
      # shellcheck disable=SC2086
      echo \
      -Pnative -Drequire.snappy  \
      -Drequire.openssl \
        -Dopenssl.prefix=${HADOOP_HOMEBREW_DIR}/opt/openssl/ \
        -Dopenssl.include=${HADOOP_HOMEBREW_DIR}/opt/openssl/include \
        -Dopenssl.lib=${HADOOP_HOMEBREW_DIR}/opt/openssl/lib \
      -Drequire.libwebhdfs -Drequire.test.libhadoop
    ;;
    *)
      # shellcheck disable=SC2086
      echo \
        -Pnative \
        -Drequire.snappy -Drequire.openssl \
        -Drequire.test.libhadoop
    ;;
  esac
}

## @description  Queue up modules for this personality
## @audience     private
## @stability    evolving
## @param        repostatus
## @param        testtype
function personality_modules
{
  declare repostatus=$1
  declare testtype=$2
  declare extra=""
  declare ordering="normal"
  declare needflags=false
  declare foundbats=false
  declare flags
  declare fn
  declare i
  declare hadoopm

  yetus_debug "Personality: ${repostatus} ${testtype}"

  clear_personality_queue

  case ${testtype} in
    asflicense)
      # this is very fast and provides the full path if we do it from
      # the root of the source
      personality_enqueue_module .
      return
    ;;
    checkstyle)
      ordering="union"
      extra="-DskipTests"
    ;;
    compile)
      ordering="union"
      extra="-DskipTests"
      needflags=true

      # if something in common changed, we build the whole world
      if [[ "${CHANGED_MODULES[*]}" =~ hadoop-common ]]; then
        yetus_debug "hadoop personality: javac + hadoop-common = ordering set to . "
        ordering="."
      fi
    ;;
    distclean)
      ordering="."
      extra="-DskipTests"
    ;;
    javadoc)
      if [[ "${CHANGED_MODULES[*]}" =~ \. ]]; then
        ordering=.
      fi

      if [[ "${repostatus}" = patch && "${BUILDMODE}" = patch ]]; then
        echo "javadoc pre-reqs:"
        for i in hadoop-project \
          hadoop-common-project/hadoop-annotations; do
            fn=$(module_file_fragment "${i}")
            pushd "${BASEDIR}/${i}" >/dev/null
            echo "cd ${i}"
            echo_and_redirect "${PATCH_DIR}/maven-${fn}-install.txt" \
              "${MAVEN}" "${MAVEN_ARGS[@]}" install
            popd >/dev/null
        done
      fi
      extra="-Pdocs -DskipTests"
    ;;
    mvneclipse)
      if [[ "${CHANGED_MODULES[*]}" =~ \. ]]; then
        ordering=.
      fi
    ;;
    mvninstall)
      extra="-DskipTests"
      if [[ "${repostatus}" = branch || "${BUILDMODE}" = full ]]; then
        ordering=.
      fi
    ;;
    mvnsite)
      if [[ "${CHANGED_MODULES[*]}" =~ \. ]]; then
        ordering=.
      fi
    ;;
    unit)
      if [[ "${BUILDMODE}" = full ]]; then
        ordering=mvnsrc
      elif [[ "${CHANGED_MODULES[*]}" =~ \. ]]; then
        ordering=.
      fi

      if [[ ${TEST_PARALLEL} = "true" ]] ; then
        extra="-Pparallel-tests"
        if [[ -n ${TEST_THREADS:-} ]]; then
          extra="${extra} -DtestsThreadCount=${TEST_THREADS}"
        fi
      fi
      needflags=true
      hadoop_unittest_prereqs "${ordering}"

      if ! verify_needed_test javac; then
        yetus_debug "hadoop: javac not requested"
        if ! verify_needed_test native; then
          yetus_debug "hadoop: native not requested"
          yetus_debug "hadoop: adding -DskipTests to unit test"
          extra="-DskipTests"
        fi
      fi

      for i in "${CHANGED_FILES[@]}"; do
        if [[ "${i}" =~ \.bats ]]; then
          foundbats=true
        fi
      done

      if ! verify_needed_test shellcheck && [[ ${foundbats} = false ]]; then
        yetus_debug "hadoop: NO shell code change detected; disabling shelltest profile"
        extra="${extra} -P!shelltest"
      else
        extra="${extra} -Pshelltest"
      fi
    ;;
    *)
      extra="-DskipTests"
    ;;
  esac

  if [[ ${needflags} = true ]]; then
    flags="$(hadoop_native_flags) $(yarn_ui2_flag)"
    extra="${extra} ${flags}"
  fi

  extra="-Ptest-patch ${extra}"

  for module in $(hadoop_order ${ordering}); do
    # shellcheck disable=SC2086
    personality_enqueue_module ${module} ${extra}
  done
}

## @description  Add tests based upon personality needs
## @audience     private
## @stability    evolving
## @param        filename
function personality_file_tests
{
  declare filename=$1

  yetus_debug "Using Hadoop-specific personality_file_tests"

  if [[ ${filename} =~ src/main/webapp ]]; then
    yetus_debug "tests/webapp: ${filename}"
  elif [[ ${filename} =~ \.sh
       || ${filename} =~ \.cmd
       || ${filename} =~ src/scripts
       || ${filename} =~ src/test/scripts
       || ${filename} =~ src/main/bin
       || ${filename} =~ shellprofile\.d
       || ${filename} =~ src/main/conf
       ]]; then
    yetus_debug "tests/shell: ${filename}"
    add_test mvnsite
    add_test unit
  elif [[ ${filename} =~ \.md$
       || ${filename} =~ \.md\.vm$
       || ${filename} =~ src/site
       ]]; then
    yetus_debug "tests/site: ${filename}"
    add_test mvnsite
  elif [[ ${filename} =~ \.c$
       || ${filename} =~ \.cc$
       || ${filename} =~ \.h$
       || ${filename} =~ \.hh$
       || ${filename} =~ \.proto$
       || ${filename} =~ \.cmake$
       || ${filename} =~ CMakeLists.txt
       ]]; then
    yetus_debug "tests/units: ${filename}"
    add_test compile
    add_test cc
    add_test mvnsite
    add_test javac
    add_test unit
  elif [[ ${filename} =~ build.xml$
       || ${filename} =~ pom.xml$
       || ${filename} =~ \.java$
       || ${filename} =~ src/main
       ]]; then
      yetus_debug "tests/javadoc+units: ${filename}"
      add_test compile
      add_test javac
      add_test javadoc
      add_test mvninstall
      add_test mvnsite
      add_test unit
  fi

  if [[ ${filename} =~ src/test ]]; then
    yetus_debug "tests: src/test"
    add_test unit
  fi

  if [[ ${filename} =~ \.java$ ]]; then
    add_test findbugs
  fi
}

## @description  Image to print on success
## @audience     private
## @stability    evolving
function hadoop_console_success
{
  printf "IF9fX19fX19fX18gCjwgU3VjY2VzcyEgPgogLS0tLS0tLS0tLSAKIFwgICAg";
  printf "IC9cICBfX18gIC9cCiAgXCAgIC8vIFwvICAgXC8gXFwKICAgICAoKCAgICBP";
  printf "IE8gICAgKSkKICAgICAgXFwgLyAgICAgXCAvLwogICAgICAgXC8gIHwgfCAg";
  printf "XC8gCiAgICAgICAgfCAgfCB8ICB8ICAKICAgICAgICB8ICB8IHwgIHwgIAog";
  printf "ICAgICAgIHwgICBvICAgfCAgCiAgICAgICAgfCB8ICAgfCB8ICAKICAgICAg";
  printf "ICB8bXwgICB8bXwgIAo"
}
