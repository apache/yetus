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

# Robots: Cirrus CI

TRIGGER: ${CIRRUS_CI}=true

`--patch-dir` will be configured to be `/tmp/yetus-out` and will be moved to the `yetus-out` directory in the source tree after completion. Adding this stanza to your `.cirrus.yml` file will upload and store those components for a week in Gitlab CI's artifact retrieval system:

```yaml
---
  always:
    junit_artifacts:
      path: "yetus-out/junit.xml"
      format: junit
    other_artifacts:
      path: "yetus-out/**"
```

To use the `--patch-dir` for additional output, use the `/tmp/yetus-out` path. For example: `--html-report-file=/tmp/yetus-out/report.html`.

To use the pre-built Apache Yetus Docker image from docker hub as the build environment, use the following snippet in the `.cirrus.yml` file, substituting the tag for the version of Apache Yetus that should be used and replacing the `JAVA_HOME` with the appropriate version as bundled mentioned in the Dockerfile:

```yaml
---
yetus_task:
  container:
    image: apache/yetus:0.10.0

  ...
```

See also:

* Apache Yetus' source tree [.cirrus.yml](https://github.com/apache/yetus/blob/main/.cirrus.yml) for some tips and tricks.
