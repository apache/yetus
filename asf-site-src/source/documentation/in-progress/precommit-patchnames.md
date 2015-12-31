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

We use Apache Yetus to process your patch. It supports the following patterns and
procedures for patch file names:

## JIRA

If JIRA support is configured, attach the patch to the given ISSUE and
click 'Submit Patch'.  The patch file should be named one of:

  * ISSUE.patch
  * ISSUE.###.patch
  * ISSUE.branch.###.patch
  * ISSUE-branch-###.patch
  * ISSUE.###.branch.patch
  * ISSUE-branch.###.patch

The meaning of the subpart are the following:

  * ISSUE: JIRA key (e.g. YETUS-1)
  * branch: either the name of a branch or a git hash prefixed with **git** (e.g. branch-2.8 or git8e55427b35)
  * ###: revision of the patch (e.g. 00 or 01)

## Github

If Github support is also configured, a comment that contains a link to a Pull Request's
patch file (e.g., https://github.com/user/repo/pull/1.patch) will pull the patch from
the given Github PR.
