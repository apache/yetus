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

# Robots: Buildkite

TRIGGER: ${BUILDKITE}=true

The recommended configuration is to have Apache Yetus installed on the host running the build agent.

If `buildkite-agent` is available and working, then artifacts will be automatically uploaded and an
annotation added to the build console if `buildkiteannotate` bugsystem is enabled.
If `${ARTIFACTS_PATH}` is configured, then `--patch-dir` is set to the first listed directory path
with a `/yetus` suffix. However, links to the location logs must still be configured manually.

# Buildkite Annotations

If precommit is running in a mode such that `buildkite-agent` isn't available (e.g., using the Apache Yetus container image)
the `buildkite-annotation-recovery` tool may be used to send the annotations and artifacts to Buildkite:

The usage is simple:

```bash
$ buildkite-recovery --patch-dir=<pre-existing patch directory>
```

See also:

* Apache Yetus' source tree [.buildkite](https://github.com/apache/yetus/blob/main/.buildkite) for some tips and tricks.
