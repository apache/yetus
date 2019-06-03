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

gitlab

# Category

Bug System

# Description

Enables support for reading and writing back to [Gitlab](https://gitlab.com/) and compatible systems such as Gitlab Enterprise.  See also the [Bugsystems](../bugsystems) documentation for more information.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--gitlab-disable-write` | Turn off writing to Gitlab merge requests |
| `--gitlab-repo=<repo>` | `username/repository` identifier |
| `--gitlab-token=<token>` |OAuth 2.0 token to use for authentication |
| `--gitlab-url=<url>` | REST API URL (for Gitlab Enterprise) |

# Docker Notes

None

# Developer Notes

All of the command line settings may also be set via internal environment variables.  However care must be taken to not step on [robots](../robots) that will also set some of these variables.
