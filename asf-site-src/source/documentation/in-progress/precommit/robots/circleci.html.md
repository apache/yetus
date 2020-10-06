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

# Robots: Circle CI

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

* Apache Yetus' source tree [.circleci/config.yaml](https://github.com/apache/yetus/blob/main/.circleci/config.yml) for some tips and tricks.
