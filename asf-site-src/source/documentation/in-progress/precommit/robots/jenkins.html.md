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

# Robots: Jenkins

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

Experience has shown that certain Jenkins + Java + OS combinations have problems sending signals to child processes.  In the case of Apache Yetus, this may result in aborted or workflows that timeout not being properly killed.  `test-patch` will write two files in the patch directory that may be helpful to combat this situation if it applies to your particular configuration.  `pidfile.txt` contains the main `test-patch` process id and `cidfile.txt` contains the docker container id.  These will not be present on a successful exit.  In Pipeline code, it should look something similar to this:

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

## GitHub Token Support

Using the Jenkins Credential system, one can provide a specific personal access token
to use with GitHub.  However, it is recommended that Jenkins be configured to act as
a GitHub application as per the
[Cloudbees documentation](https://docs.cloudbees.com/docs/cloudbees-jenkins-platform/latest/github-app-auth)
for the optimal `test-patch` experience.  Configure up to the "Configuring the GitHub Organization" and then, using the Jenkins credential system, pass the GitHub App's token to `test-patch`. For example:

```groovy
...
        withCredentials([usernamePassword(credentialsId: 'github-app',
                         passwordVariable: 'GITHUB_TOKEN',
                         usernameVariable: 'GITHUB_USER')]) {
...

        sh '''test-patch --github-token="${GITHUB_TOKEN}" (other options)'''
...
```

Doing so will enable in many circumstances a bit more functionality, such as
GitHub Statuses.

See also:

* Apache Yetus' source tree [Jenkinsfile](https://github.com/apache/yetus/blob/main/Jenkinsfile) for some tips and tricks.
* [precommit-admin](../../admin), for special utilities built for Jenkins.
* [GitHub Branch Source Plugin](https://wiki.jenkins.io/display/JENKINS/GitHub+Branch+Source+Plugin)
* [GitHub Pull Request Builder Plugin](https://wiki.jenkins.io/display/JENKINS/GitHub+pull+request+builder+plugin)
* `https://{your local server}/env-vars.html/`
* [From Jenkins – GitHub App authentication support released](https://cd.foundation/blog/2020/04/22/from-jenkins-github-app-authentication-support-released/)
* [Jenkins - Using GitHub App authentication](https://docs.cloudbees.com/docs/cloudbees-jenkins-platform/latest/github-app-auth)
