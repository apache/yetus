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

# Robots: Gitlab CI

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

* Apache Yetus' source tree [.gitlab-ci.yml](https://github.com/apache/yetus/blob/main/.gitlab-ci.yml) for some tips and tricks.
