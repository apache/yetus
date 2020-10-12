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

# Name

jira

# Category

Bug System

# Description

Enables support for reading and writing back to [JIRA](https://www.atlassian.com/software/jira), both on-premise and in-cloud.  See also the [Bugsystems](../../bugsystems) documentation for more information.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--jira-base-url=<url>` | URL for the JIRA installation |
| `--jira-issue-re=<expr>` | regular expression to use when trying to find a JIRA ref in the patch name |
| `--jira-password=<pw>` | Password to use for authentication |
| `--jira-status-re=<expr>` | Grep regular expression representing the issue status whose patch is applicable to the codebase |
| `--jira-user=<user>` | Username to use for authentication |

# Docker Notes

None

# Developer Notes

None
