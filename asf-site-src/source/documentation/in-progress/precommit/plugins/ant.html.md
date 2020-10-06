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

ant

# Category

Build Tool

# Description

Provides support for the [Apache Ant](https://ant.apache.org) build tool.

# Environment Variables

| Variable | Passed to Docker | Notes |
|:---------|:-----------------|:------|
| `ANT_ARGS` | YES | Additional arguments to `ant` |
| `ANT_HOME` | YES | Used to determine the location of the `ant` binary if it is not on the path or provided via the `--ant-cmd` flag |
| `ANT_OPTS` | YES | Additional options to the JVM that runs `ant` |

# Options

| Option | Notes |
|:---------|:------|
| `--ant-cmd` | Specifically set the location of the `ant` binary |

# Docker Notes

* `${HOME}/.ivy2` is mounted to `/home/${USER_NAME}/.ivy2` in the container.
* `ANT_OPTS` and `ANT_ARGS` are populated into the container environment.

# Developer Notes

See [build tools](../../buildtools) for more information.
