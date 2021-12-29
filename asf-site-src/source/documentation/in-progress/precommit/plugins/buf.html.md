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

buf
buflint
bufcompat

# Category

Test

# Description

[buf](https://github.com/bufbuild/buf) is a protobuf linter (`buflint`) and backward compatibility checker (`bufcompat`), version 0.34.0 or higher.
In order to use either `buflint` or `bufcompat`, `buf` must also be enabled.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--buf=<file>` | path to `buf` executable if it is not on the path |
| `--buf-basedir=<dir>` | set the starting dir to run buf |
| `--buf-timeout=###u` | Set the buf timeout |

# Docker Notes

None

# Developer Notes

None
