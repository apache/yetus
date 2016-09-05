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

smart-apply-patch
=================

`smart-apply-patch` is a command to help apply patches easily.  It uses the same plug-ins and many of the same options as test-patch.  This means that it can, for example, fetch patches from JIRA and apply them to a local source tree.

# Usage

Its simplest form is used when a patch is stored in a local file:

```bash
$ smart-apply-patch patch
```

This will cause the command to run through various ways to verify and then apply the patch to the current repo, including deducing a patch level.

Perhaps you just want to see if the patch even applies without changing your local repo.  The `--dry-run` option will just test for applicability:

```bash
$ smart-apply-patch --dry-run patch
```

For committers of projects, there is a special mode:

```bash
$ smart-apply-patch --committer patch
```

that in addition to applying the patch will also attempt to:

* use `--whitespace=fix` mode
* add all newly created files in the repo
* use `--signoff` and commit the change via git-am
