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

# GitHub Status Recovery

<!-- MarkdownTOC levels="1,2,3" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Problem Statement](#problem-statement)
* [Usage](#usage)
* [Disabling Annotations](#disabling-annotations)

<!-- /MarkdownTOC -->

# Problem Statement

For CI systems that use GitHub outside of GitHub Actions, they may make available a GitHub Checks token.
Unfortunately, as of this writing (2020-10-30), GitHub sets the expiry of such a token to 1 hour.
For some users of Apache Yetus, their precommit job may take longer than one hour.  In order to workaround
this limitation, the `github-status-recovery` program may be used.

# Usage

The usage is relatively simple:

```bash
$ github-status-recovery --patch-dir=<pre-existing patch directory> --github-token=<token>
```

If the previous run of `test-patch` failed to write the status, `github-status-recovery` will
re-process the saved JSON files as well as write GitHub Checks Annotations if they exist.

# Disabling Annotations

If for some reason you do not wish annotations to be written, they may be disabled with `--github-annotations=false`.
