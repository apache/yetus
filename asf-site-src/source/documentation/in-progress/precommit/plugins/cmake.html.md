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

cmake

# Category

Build Tool

# Description

Enables using [cmake](https://cmake.org/) as the build tool.  This plug-in has a dependency on the `make` plug-in.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--cmake-build-dir=<path>` | Relative to each module, the location of the build directory to use for storing built output |
| `--cmake-cmd=<cmd>` | Location of `cmake`'s executable, if it is not on the path |
| `--cmake-root-build=<bool>` | Enable/Disable module support if multiple CMakeLists.txt's are found |

# Docker Notes

None

# Developer Notes

There are two variables that personalities should probably set that correspond to two of the options above:

| Variable | Option Equivalent |
|:---------|:------|
| CMAKE_BUILD_DIR | `--cmake-build-dir=<path>` |
| CMAKE_ROOT_BUILD | `--cmake-root-build=<bool>` |

See [build tools](../buildtools) for more information.
