// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
pipeline {
  agent {
    // Hadoop and ubuntu for ASF, rest are private
    label 'Hadoop||ubuntu||azaka||small&&!H19'
  }
  triggers {
    cron('@daily')
  }
  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
    timeout (time: 9, unit: 'HOURS')
    timestamps()
    checkoutToSubdirectory('src')
  }
  environment {
    //YETUS_RELEASE = '0.8.0'
    YETUS_BASEDIR = 'src'
    // will also need to change email section below
    YETUS_RELATIVE_PATCHDIR = 'out'
    YETUS_DOCKERFILE = "${YETUS_BASEDIR}/precommit/src/main/shell/test-patch-docker/Dockerfile"
  }
  stages {
    stage ('precommit-run') {
      steps {
        sh '''#!/usr/bin/env bash
            if [[ -d "${WORKSPACE}/${YETUS_RELATIVE_PATCHDIR}" ]]; then
              rm -rf "${WORKSPACE}/${YETUS_RELATIVE_PATCHDIR}"
            fi
            mkdir -p "${WORKSPACE}/${YETUS_RELATIVE_PATCHDIR}"

            # where the source is located
            YETUS_ARGS+=("--basedir=${WORKSPACE}/${YETUS_BASEDIR}")

            # nuke the src repo before working
            YETUS_ARGS+=("--resetrepo")

            # Enable maven custom repos in order to avoid multiple executor clashes
            YETUS_ARGS+=("--mvn-custom-repos")

            # run in docker mode
            YETUS_ARGS+=("--docker")

            # temp storage, etc
            YETUS_ARGS+=("--patch-dir=${WORKSPACE}/${YETUS_RELATIVE_PATCHDIR}")

            # lots of different output formats
            YETUS_ARGS+=("--brief-report-file=${WORKSPACE}/${YETUS_RELATIVE_PATCHDIR}/brief.txt")
            YETUS_ARGS+=("--console-report-file=${WORKSPACE}/${YETUS_RELATIVE_PATCHDIR}/console.txt")
            YETUS_ARGS+=("--html-report-file=${WORKSPACE}/${YETUS_RELATIVE_PATCHDIR}/report.html")

            # rsync these files back into the archive dir
            YETUS_ARGS+=("--archive-list=checkstyle-errors.xml,findbugsXml.xml")

            # URL for user-side presentation
            YETUS_ARGS+=("--build-url-artifacts=artifact/out")

            # plugins to enable
            YETUS_ARGS+=("--plugins=all")

            YETUS_ARGS+=("--tests-filter=checkstyle,javadoc,rubocop,ruby-lint,test4tests")

            # run test-patch from the source tree specified up above
            TESTPATCHBIN=${WORKSPACE}/src/precommit/src/main/shell/test-patch.sh

            /usr/bin/env bash "${TESTPATCHBIN}" "${YETUS_ARGS[@]}"

            '''
      }
    }
  }
  post {
    always {
      // Has to be relative to WORKSPACE.
      archiveArtifacts "${env.YETUS_RELATIVE_PATCHDIR}/**"
      publishHTML target: [
        allowMissing: true,
        keepAll: true,
        alwaysLinkToLastBuild: true,
        // Has to be relative to WORKSPACE
        reportDir: "${env.YETUS_RELATIVE_PATCHDIR}",
        reportFiles: 'report.html',
        reportName: 'Yetus QBT Report'
      ]
    }
    failure {
      emailext subject: '$DEFAULT_SUBJECT',
      body: '''For more details, see ${BUILD_URL}

${CHANGES, format="[%d] (%a) %m"}

${FILE,path="out/brief.txt"}''',
      recipientProviders: [
          [$class: 'DevelopersRecipientProvider'],
          [$class: 'RequesterRecipientProvider']
      ],
      replyTo: '$DEFAULT_REPLYTO',
      to: '$DEFAULT_RECIPIENTS'
    }
    cleanup() {
      deleteDir()
    }
  }
}
