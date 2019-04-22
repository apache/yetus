<!---
  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
-->

# Robots: Continuous Integration Support

<!-- MarkdownTOC levels="1,2" autolink="true" -->

* [Intro](#intro)
* [Azure Pipelines](#azure-pipelines)
* [Circle CI](#circle-ci)
* [Gitlab CI](#gitlab-ci)
* [Jenkins](#jenkins)
* [Semaphore CI](#semaphore-ci)
* [Travis CI](#travis-ci)
* [Manual Configuration](#manual-configuration)
* [Sentinel Mode](#sentinel-mode)

<!-- /MarkdownTOC -->

# Intro

`test-patch` works hand-in-hand with various CI and other automated build systems.  `test-patch` will attempt to auto-determine if it is running under such a system and change its defaults to match known configuration parameters automatically. When robots are activated, there is generally some additional/changed behavior:

* display extra information in the footer
* change log entries from file names to URLs
* activate `--resetrepo` to keep the directory structure clean
* enable the running of unit tests and run them in parallel
* if possible, write comments to bug systems
* attempt to determine the build tool in use
* activate Docker maintenance when `--docker` is passed
* attempt to determine whether this is a full build (`qbt`) or testing a patch/merge request/pull request.

# Azure Pipelines

    NOTE: Azure Pipelines support is not stable and should be viewed as experimental, at best.

TRIGGER: ${TF_BUILD}=True

Azure Pipelines support has only been tested on the Ubuntu VM with GitHub as the source repository. It automatically configures `--patch-dir` to be `${BUILD_ARTIFACTSTAGINGDIRECTORY}/yetus`.  While the URL to the console is provided in the report, links are not provided due to the URLs to artifacts not being available at runtime.

As of this writing, Azure Pipelines has moved to a custom moby build for the 'docker' executable.  As a result, `--docker` is not supported.

# Circle CI

TRIGGER: ${CIRCLECI}=true

Circle CI support in `test-patch` is limited to github.com.

To use the pre-built Apache Yetus Docker image from docker hub as the build environment, use the following snippet in the `.circleci/config.yaml` file, substituting the tag for the version of Apache Yetus that should be used and replacing the JAVA_HOME with the appropriate version as bundled mentioned in the Dockerfile:

```yaml
---
jobs:
  build:
    docker:
      - image: apache/yetus:0.10.0

    environment:
      JAVA_HOME: /usr/lib/jvm/java-8-openjdk-amd64

  ...
```

Artifacts need some special handling.  In order to get links, the storage of artifacts must be 'primed' prior to launching test-patch and then again to actually store the content. Additionally, the location needs to be handled set on the command line. In practice, this configuration looks similar to this:

```yaml
---
jobs:
  build:
    steps:
      ...
      - run: mkdir -p /tmp/yetus-out
      - run: echo "bootstrap" > /tmp/yetus-out/bootstrap
      - store_artifacts:
          path: /tmp/yetus-out
      - run: >
          test-patch.sh
             --patch-dir=/tmp/yetus-out
             ...
      - store_artifacts:
          path: /tmp/yetus-out
```

See also:

* Apache Yetus' source tree [.circleci/config.yaml](https://github.com/apache/yetus/blob/master/.circleci/config.yml) for some tips and tricks.

# Gitlab CI

TRIGGER: ${GITLAB_CI}=true

Artifacts, patch logs, etc are configured to go to a yetus-out directory in the source tree after completion. Adding this stanza to your `.gitlab-ci.yml` file will upload and store those components for a week in Gitlab CI's artifact retrieval system:

```yaml
---
  artifacts:
    expire_in: 1 week
    when: always
    paths:
      - yetus-out/
```

To use the pre-built Apache Yetus Docker image from docker hub as the build environment, use the following snippet in the `.gitlab-ci.yml` file, substituting the tag for the version of Apache Yetus that should be used and replacing the `JAVA_HOME` with the appropriate version as bundled mentioned in the Dockerfile:

```yaml
---
job:
  image: apache/yetus:0.9.0
  allow_failure: true
  variables:
    JAVA_HOME: /usr/lib/jvm/java-8-openjdk-amd64

  ...
```

See also:

* Apache Yetus' source tree [.gitlab-ci.yml](https://github.com/apache/yetus/blob/master/.gitlab-ci.yml) for some tips and tricks.

# Jenkins

TRIGGER: ${JENKINS_URL}=(anything)  ,  ${EXECUTOR_NUMBER}=(anything)

Jenkins is extremely open-ended and, given multiple executors, does not run workflows in isolation.  As a result, many more configuration options generally need to be configured as it is not safe or may be surprising to users for test-patch to auto-determine some settings.  By default, Jenkins will trigger a full build.

There is some support for a few well known environment variables:

* `${CHANGE_URL}` or `${ghprbPullLink}` will set the patch location as well as trigger some extra handling if 'github' or 'gitlab' appear in the string.
* `${GIT_URL}` will trigger the same extra handling if 'github' or 'gitlab' appear in the string.
* If `${ghprbPullId}` is set, then test-patch will configure itself for a Github-style PR.

To use the pre-built Apache Yetus Docker image from docker hub as the build environment, use the following snippet in the `Jenkinsfile`, substituting the tag for the version of Apache Yetus that should be used and replacing the JAVA_HOME with the appropriate version as bundled mentioned in the Dockerfile:

```groovy
pipeline {
  agent {
    docker {
      image 'apache/yetus:0.9.0'
      args '-v /var/run/docker.sock:/var/run/docker.sock'
    }
  }

  environment {
    JAVA_HOME = '/usr/lib/jvm/java-8-openjdk-amd64'
  }

}

```

Experience has shown that certain Jenkins + Java + OS combinations have problems sending signals to child processes.  In the case of Apache Yetus, this may result in aborted or workflows that timeout not being properly killed.  `test-patch` will write two files in the patch directory that may be helpful to combat this situation if it applies to your particular configuration.  `pidfile.txt` contains the master `test-patch` process id and `cidfile.txt` contains the docker container id.  These will not be present on a successful exit.  In Pipeline code, it should look something similar to this:

 ```groovy
    post {
      cleanup() {
        script {
          sh '''
            if [ -f "${env.PATCH_DIR}/pidfile.txt" ]; then
              kill `cat "${env.PATCH_DIR}/pidfile.txt"` || true
              sleep 5
            fi
            if [ -f "${env.PATCH_DIR}/cidfile.txt" ]; then
              docker kill `cat "${env.PATCH_DIR}/cidfile.txt"` || true
              sleep 5
            fi
            '''
            ...
            deletedir()
        }
      }
    }
 ```

See also:

* Apache Yetus' source tree [Jenkinsfile](https://github.com/apache/yetus/blob/master/Jenkinsfile) for some tips and tricks.
* [precommit-admin](precommit-admin), for special utilities built for Jenkins.
* [GitHub Branch Source Plugin](https://wiki.jenkins.io/display/JENKINS/GitHub+Branch+Source+Plugin)
* [GitHub Pull Request Builder Plugin](https://wiki.jenkins.io/display/JENKINS/GitHub+pull+request+builder+plugin)
* `https://{your local server}/env-vars.html/`

# Semaphore CI

    NOTE: Semaphore CI support is not stable and should be viewed as experimental, at best.

TRIGGER: ${CI}=true and ${SEMAPHORE}=true

Semaphore CI requires that `checkout --use-cache` has been used prior to trigging test-patch. It is HIGHLY recommended to use a helper script checked into the repository to control precommit options to avoid problems with Semaphore CI's parsing of long lines in the YAML file.

The GitHub repo and the Pull Request in use are automatically detected.  However, some personalities may override the auto-detected Github repository information.  It may be necessary to manually configure it in your `semaphore.yml` file.

See also:

* Apache Yetus' source tree [semaphore.yml](https://github.com/apache/yetus/blob/master/.semaphore/semaphore.yml) for some tips and tricks.
* Apache Yetus' helper script [semaphore-build.sh](https://github.com/apache/yetus/blob/master/.semaphore/semaphore-build.sh)

# Travis CI

TRIGGER: ${TRAVIS}=true

Travis CI support will update the local checked out source repository to include references to all branches and tags

If `${ARTIFACTS_PATH}` is configured, then `--patch-dir` is set to the first listed directory path.  However, links to the location logs must still be configured manually.

Personalities will override the auto-detected Github repository information.  It may be necessary to manually configure it in your `.travis.yml` file.

As of this writing, it is not possible to make the Travis CI build environment use the Apache Yetus pre-built docker images without using `docker run` in the before_install phase.  Therefore, using the image is the same as described in the [Apache Yetus Docker Hub Images](/yetus-docker-image) page.

See also:

* Apache Yetus' source tree [.travis.yml](https://github.com/apache/yetus/blob/master/.travis.yml) for some tips and tricks.

# Manual Configuration

For automated systems that are not directly supported, `--robot` tells `test-patch` that this is an automated system.  This will trigger many of the above settings.

The `--build-url` option is also useful when running in `--robot` mode so that emails and such
have a location to look at the output artifacts:

```bash
$ test-patch --robot --build-url=http://server.example.name:80/${buildnumber}/
```

Some plug-ins such as Maven have special handling if there are multiple executions of `test-patch` happening at once.  It is very common when using automation systems to have multiple runs on the same host. In order to assist these plug-ins, an instance identifier may be provided:

```bash
$ test-patch --robot --instance=1
```

If `--robot` is specified without an instance, a random number is generated and used.

# Sentinel Mode

If stuck Docker containers are a problem, a more aggressive robot may be enabled with the `--sentinel` option.  This option enables killing containers that have been running for over 24 hours as well.