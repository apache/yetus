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

function personality_globals
{
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

  HADOOP_MODULES=""
}

function hadoop_module_manipulation
{
  local startingmodules=${1:-normal}
  local full_ordered_hadoop_modules;
  local module
  local ordered_modules
  local passed_modules
  local flags

  yetus_debug "hmm in: ${startingmodules}"

  if [[ ${startingmodules} = normal ]]; then
    startingmodules=${CHANGED_MODULES}
  elif  [[ ${startingmodules} = union ]]; then
    startingmodules=${CHANGED_UNION_MODULES}
  fi

  yetus_debug "hmm expanded to: ${startingmodules}"

  # If "." is present along with other changed modules,
  # then just choose "."
  for module in ${startingmodules}; do
    if [[ "${module}" = "." ]]; then
      yetus_debug "hmm shortcut since ."
      HADOOP_MODULES=.
      return
    fi
  done

  passed_modules=${startingmodules}

  yetus_debug "hmm pre-ordering: ${startingmodules}"

  # Build a full ordered list of modules
  # based in maven dependency and re-arrange changed modules
  # in dependency order.
  # NOTE: module names with spaces not expected in hadoop
  full_ordered_hadoop_modules=(
    hadoop-build-tools
    hadoop-project
    hadoop-common-project/hadoop-annotations
    hadoop-project-dist
    hadoop-assemblies
    hadoop-maven-plugins
    hadoop-common-project/hadoop-minikdc
    hadoop-common-project/hadoop-auth
    hadoop-common-project/hadoop-auth-examples
    hadoop-common-project/hadoop-common
    hadoop-common-project/hadoop-nfs
    hadoop-common-project/hadoop-kms
    hadoop-common-project
    hadoop-hdfs-project/hadoop-hdfs-client
    hadoop-hdfs-project/hadoop-hdfs
    hadoop-hdfs-project/hadoop-hdfs-native-client
    hadoop-hdfs-project/hadoop-hdfs-httfs
    hadoop-hdfs-project/hadoop-hdfs/src/contrib/bkjournal
    hadoop-hdfs-project/hadoop-hdfs-nfs
    hadoop-hdfs-project
    hadoop-yarn-project/hadoop-yarn
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-api
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-common
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-common
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-nodemanager
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-web-proxy
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-applicationhistoryservice
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-resourcemanager
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-tests
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-client
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-sharedcachemanager
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-applications
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-applications/hadoop-yarn-applications-distributedshell
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-applications/hadoop-yarn-applications-unmanaged-am-launcher
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-site
    hadoop-yarn-project/hadoop-yarn/hadoop-yarn-registry
    hadoop-yarn-project
    hadoop-mapreduce-project/hadoop-mapreduce-client
    hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-core
    hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-common
    hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-shuffle
    hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-app
    hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-hs
    hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient
    hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-hs-plugins
    hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-nativetask
    hadoop-mapreduce-project/hadoop-mapreduce-examples
    hadoop-mapreduce-project
    hadoop-tools/hadoop-streaming
    hadoop-tools/hadoop-distcp
    hadoop-tools/hadoop-archives
    hadoop-tools/hadoop-archive-logs
    hadoop-tools/hadoop-rumen
    hadoop-tools/hadoop-gridmix
    hadoop-tools/hadoop-datajoin
    hadoop-tools/hadoop-ant
    hadoop-tools/hadoop-extras
    hadoop-tools/hadoop-pipes
    hadoop-tools/hadoop-openstack
    hadoop-tools/hadoop-aws
    hadoop-tools/hadoop-azure
    hadoop-client
    hadoop-minicluster
    hadoop-tools/hadoop-sls
    hadoop-tools/hadoop-tools-dist
    hadoop-tools/hadoop-kafka
    hadoop-tools
    hadoop-dist)

  # For each expected ordered module,
  # if it's in changed modules, add to HADOOP_MODULES
  for module in "${full_ordered_hadoop_modules[@]}"; do
    # shellcheck disable=SC2086
    if hadoop_check_module_present "${module}" ${passed_modules}; then
      yetus_debug "Personality ordering ${module}"
      ordered_modules="${ordered_modules} ${module}"
    fi
  done

  # For modules which are not in ordered list,
  # add them at last
  for module in $( echo "${passed_modules}" | tr ' ' '\n'); do
    # shellcheck disable=SC2086
    if ! hadoop_check_module_present "${module}" ${ordered_modules}; then
      yetus_debug "Personality ordering ${module}"
      ordered_modules="${ordered_modules} ${module}"
    fi
  done

  HADOOP_MODULES="${ordered_modules}"

  yetus_debug "hmm out: ${HADOOP_MODULES}"
}

function hadoop_check_module_present
{
  local module_to_check=${1}
  shift
  for module in "${@}"; do
    if [[ ${module_to_check} = "${module}" ]]; then
      return 0
    fi
  done
  return 1
}

function hadoop_unittest_prereqs
{
  local need_common=0
  local building_common=0
  local module
  local flags
  local fn

  for module in ${HADOOP_MODULES}; do
    if [[ ${module} = hadoop-hdfs-project* ]]; then
      need_common=1
    elif [[ ${module} = hadoop-common-project/hadoop-common
      || ${module} = hadoop-common-project ]]; then
      building_common=1
    fi
  done

  if [[ ${need_common} -eq 1
      && ${building_common} -eq 0 ]]; then
    echo "unit test pre-reqs:"
    module="hadoop-common-project/hadoop-common"
    fn=$(module_file_fragment "${module}")
    flags=$(hadoop_native_flags)
    pushd "${BASEDIR}/${module}" >/dev/null
    # shellcheck disable=SC2086
    echo_and_redirect "${PATCH_DIR}/maven-unit-prereq-${fn}-install.txt" \
      "${MAVEN}" "${MAVEN_ARGS[@]}" install -DskipTests ${flags}
    popd >/dev/null
  fi
}

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
      JANSSON_INCLUDE_DIR=/usr/local/opt/jansson/include
      JANSSON_LIBRARY=/usr/local/opt/jansson/lib
      export JANSSON_LIBRARY JANSSON_INCLUDE_DIR
      # shellcheck disable=SC2086
      echo \
      -Pnative -Drequire.snappy  \
      -Drequire.openssl \
        -Dopenssl.prefix=/usr/local/opt/openssl/ \
        -Dopenssl.include=/usr/local/opt/openssl/include \
        -Dopenssl.lib=/usr/local/opt/openssl/lib \
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

function personality_modules
{
  local repostatus=$1
  local testtype=$2
  local extra=""
  local ordering="normal"
  local needflags=false
  local flags
  local fn
  local i

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
      if [[ ${CHANGED_MODULES} =~ hadoop-common ]]; then
        yetus_debug "hadoop personality: javac + hadoop-common = ordering set to . "
        ordering="."
      fi
      ;;
    distclean)
      ordering="."
      extra="-DskipTests"
    ;;
    javadoc)
      if [[ ${repostatus} = patch ]]; then
        echo "javadoc pre-reqs:"
        for i in  hadoop-project \
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
    mvninstall)
      extra="-DskipTests"
      if [[ ${repostatus} = branch ]]; then
        ordering=.
      fi
      ;;
    unit)
      if [[ ${TEST_PARALLEL} = "true" ]] ; then
        extra="-Pparallel-tests"
        if [[ -n ${TEST_THREADS:-} ]]; then
          extra="${extra} -DtestsThreadCount=${TEST_THREADS}"
        fi
      fi
      needflags=true
      hadoop_unittest_prereqs

      verify_needed_test javac
      if [[ $? == 0 ]]; then
        yetus_debug "hadoop: javac not requested"
        verify_needed_test native
        if [[ $? == 0 ]]; then
          yetus_debug "hadoop: native not requested"
          yetus_debug "hadoop: adding -DskipTests to unit test"
          extra="-DskipTests"
        fi
      fi

      verify_needed_test shellcheck
      if [[ $? == 0
          && ! ${CHANGED_FILES} =~ \.bats ]]; then
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
    flags=$(hadoop_native_flags)
    extra="${extra} ${flags}"
  fi

  extra="-Ptest-patch ${extra}"

  hadoop_module_manipulation ${ordering}

  for module in ${HADOOP_MODULES}; do
    # shellcheck disable=SC2086
    personality_enqueue_module ${module} ${extra}
  done
}

function personality_file_tests
{
  local filename=$1

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

function hadoop_console_success
{
  printf "IF9fX19fX19fX18gCjwgU3VjY2VzcyEgPgogLS0tLS0tLS0tLSAKIFwgICAg";
  printf "IC9cICBfX18gIC9cCiAgXCAgIC8vIFwvICAgXC8gXFwKICAgICAoKCAgICBP";
  printf "IE8gICAgKSkKICAgICAgXFwgLyAgICAgXCAvLwogICAgICAgXC8gIHwgfCAg";
  printf "XC8gCiAgICAgICAgfCAgfCB8ICB8ICAKICAgICAgICB8ICB8IHwgIHwgIAog";
  printf "ICAgICAgIHwgICBvICAgfCAgCiAgICAgICAgfCB8ICAgfCB8ICAKICAgICAg";
  printf "ICB8bXwgICB8bXwgIAo"
}
