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

# smart-apply-patch

<!-- MarkdownTOC levels="1,2,3" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Local File](#local-file)
* [Remote Files and Bug Systems](#remote-files-and-bug-systems)
* [Dry-run](#dry-run)
* [Committer Mode](#committer-mode)
* [Patch Reporting](#patch-reporting)

<!-- /MarkdownTOC -->

`smart-apply-patch` is a command to help apply patches easily.  It uses the same plug-ins and many of the same options as test-patch.  This means that it can, for example, fetch patches from JIRA and apply them to a local source tree.

# Local File

Its simplest form is used when a patch is stored in a local file:

```bash
$ smart-apply-patch patch
```

This will cause the command to run through various ways to verify and then apply the patch to the current repo, including deducing a patch level.

# Remote Files and Bug Systems

`smart-apply-patch` supports many of the same switches and configurations
that `test-patch` does.  Using those switches means that, for example, it is possible to pull and apply a GitHub PR very easily:

```bash
$ smart-apply-patch --plugins=github --github-repo apache/yetus GH:3000
```

`smart-apply-patch` will do all the work of downloading, verifying, and applying just as `test-patch` would.

# Dry-run

Perhaps you just want to see if the patch even applies without changing your local repo.  The `--dry-run` option will just test for applicability:

```bash
$ smart-apply-patch --dry-run patch
```

# Committer Mode

For committers of projects, there is a special mode:

```bash
$ smart-apply-patch --committer patch
```

that in addition to applying the patch will also attempt to:

* use `--whitespace=fix` mode
* add all newly created files in the repo
* use `--signoff` and commit the change via git-am

# Patch Reporting

For speciality CI needs, it may be useful to just have access to Apache Yetus'
ability to interpret changes and then do your own actions based upon that
content.  `smart-apply-patch` has two options that expose that functionality
for highly customized CI needs:

```bash
$ smart-apply-patch --plugins=gitlab --changedfilesreport=/tmp/myfile.txt GL:100
```

This command will download GitLab merge request #100, process it, and write a
file called `/tmp/myfile.txt` that lists the files that were changed.

```bash
$ smart-apply-patch --build-tool=maven --plugins=maven --changedmodulesreport=/tmp/mymodules.txt /tmp/file.patch
```

Similarly, this option will return the module list from `/tmp/file.patch`.
Or, perhaps you simply want to know the deepest directory with a change?

```bash
$ smart-apply-patch --build-tool=maven --plugins=maven --changedunionreport=/tmp/base.txt http://example.com/patch
```

If you want to generate these reports without actually applying it (where
possible), then the `--reports-only` option is available:

```bash
$ smart-apply-patch --reports-only --changedfilesreport=/tmp/myfile.txt /tmp/file.patch
```
