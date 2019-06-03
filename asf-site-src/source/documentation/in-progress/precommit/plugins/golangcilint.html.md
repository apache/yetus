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

golangcilint

# Category

Test

# Description

NOTE: Go support is experimental.  Additionally, this plug-in only supports Go using Go modules.

Provides support for
[golangci-lint](https://github.com/golangci/golangci-lint).  This
plug-in requires the [golang](golang) plug-in to also be enabled.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--golangcilint=<file>` | Location of the `golangci-lint` binary if it is not on the path |
| `--golangcilint-config=<file>` | Override the default location of the configuration file |

# Docker Notes

None

# Developer Notes

None
