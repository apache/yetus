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

golang

# Category

Test (Compile)

# Description

NOTE: Go support is experimental.

Provides support for [Go](https://golang.com) v1.12 and higher.  This support includes the ability to read compiler errors as well as supplemental routines for other precommit tests that support Go directly such as [revive](revive).

Amongst other missing features, it does not support using Go as a [build tool](../buildtools) or `go test` formatted output.   Additionally, if Go source is detected, `precommit` will use `git checkout` in addition to `git clean` to maintain the source tree as part of the compile cycle.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--golang-go=<cmd>` | Location of the `go` binary if it is not on the path |

# Docker Notes

The following standard Go compiler variables are passed onto the container environment:

* CGO_LDFLAGS
* CGO_ENABLED
* GO111MODULE
* GOPATH

# Developer Notes

None
