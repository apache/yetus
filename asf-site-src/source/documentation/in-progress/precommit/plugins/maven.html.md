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

maven

# Category

Build Tool

# Description

Enables [Apache Maven](https://maven.apache.org) as the controlling build tool.

# Environment Variables

`MAVEN_HOME` may be used to find the `mvn` executable.

# Options

| Option | Notes |
|:---------|:------|
| `--mvn-cmd=<cmd>` | Executable location |
| `--mvn-custom-repos` | Use custom Apache Maven repositories (generally `$WORKSPACE/yetus-m2`) instead of the default. |
| `--mvn-custom-repos-dir=<dir>` | Override the default location that test-patch will use when `--mvn-custom-repos` is enabled |
| `--mvn-deps-order=<bool>` | Disable the plug-ins auto-dependency module ordering detection |
| `--mvn-settings=<file>` | Configuration the location of Maven\'s settings file |

# Docker Notes

None

# Developer Notes

The `maven` plug-in adds several API calls that other plug-ins may use to configure specific Apache Maven behavior, generally around Maven cache management.

See [build tools](../buildtools) for more information.
